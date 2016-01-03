----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    13:20:03 09/11/2014 
-- Module Name:    UART_RECEIVER - rtl 
-- Project Name:   UART_RECEIVER
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity UART_RECEIVER is
    generic (
        CLK_IN_PERIOD   : real := 50.0;
        BAUD_RATE       : natural := 115_200;
        DATA_BITS       : natural range 5 to 8 := 8;
        PARITY_BIT_TYPE : natural range 0 to 2 := 0
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        RXD     : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(DATA_BITS-1 downto 0);
        VALID   : out std_ulogic := '0';
        
        ERROR   : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0'
    );
end UART_RECEIVER;

architecture rtl of UART_RECEIVER is
    
    constant NONE   : natural := 0;
    constant EVEN   : natural := 1;
    constant ODD    : natural := 2;
    
    constant bit_period     : real := 1_000_000_000.0 / real(BAUD_RATE);
    constant cycle_ticks    : positive := integer(bit_period / CLK_IN_PERIOD);
    
    type state_type is (
        WAITING_FOR_SENDER,
        WAITING_FOR_START,
        WAITING_FOR_DATA,
        GETTING_DATA,
        APPLYING_DATA,
        INCREMENTING_BIT_INDEX,
        GETTING_PARITY,
        CHECKING_PARITY,
        WAITING_FOR_STOP,
        CHECKING_STOP
    );
    
    type reg_type is record
        state       : state_type;
        tick_cnt    : natural range 0 to cycle_ticks;
        receiving   : boolean;
        bit_index   : unsigned(2 downto 0);
        dout        : std_ulogic_vector(DATA_BITS-1 downto 0);
        valid       : std_ulogic;
        parity      : std_ulogic;
        error       : std_ulogic;
    end record;
    
    constant reg_type_def : reg_type := (
        state       => WAITING_FOR_SENDER,
        tick_cnt    => 0,
        receiving   => false,
        bit_index   => "000",
        dout        => (others => '0'),
        valid       => '0',
        parity      => '0',
        error       => '0'
    );
    
    signal rxd_sync             : std_ulogic := '0';
    signal cycle_half           : boolean := false;
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    DOUT    <= cur_reg.dout;
    VALID   <= cur_reg.valid;
    
    BUSY    <= '1' when cur_reg.receiving else '0';
    ERROR   <= cur_reg.error;
    
    cycle_half  <= cur_reg.tick_cnt=cycle_ticks/2-1;
    
    rxd_SIGNAL_SYNC_inst : entity work.SIGNAL_SYNC
        generic map (
            DEFAULT_VALUE   => '1'
        )
        port map (
            CLK     => CLK,
            DIN     => RXD,
            DOUT    => rxd_sync
        );
    
    stm_proc : process(cur_reg, RST, rxd_sync, cycle_half)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        
        r   := cr;
        
        r.valid     := '0';
        r.tick_cnt  := cr.tick_cnt+1;
        if
            not cr.receiving or
            cr.tick_cnt=cycle_ticks-1
        then
            r.tick_cnt  := 0;
        end if;
        
        case cr.state is
            
            when WAITING_FOR_SENDER =>
                r.receiving := false;
                r.bit_index := "000";
                r.state := WAITING_FOR_START;
            
            when WAITING_FOR_START =>
                if rxd_sync='0' then
                    r.state := WAITING_FOR_DATA;
                end if;
            
            when WAITING_FOR_DATA =>
                r.receiving := true;
                r.parity    := '1';
                if PARITY_BIT_TYPE=ODD then
                    r.parity    := '0';
                end if;
                if cycle_half then
                    r.state := GETTING_DATA;
                end if;
                if rxd_sync='1' then
                    -- invalid START bit
                    r.error := '1';
                    r.state := WAITING_FOR_SENDER;
                end if;
            
            when GETTING_DATA =>
                if cycle_half then
                    r.state := APPLYING_DATA;
                end if;
            
            when APPLYING_DATA =>
                r.dout(int(cr.bit_index))   := rxd_sync;
                if rxd_sync='1' then
                    r.parity    := not cr.parity;
                end if;
                r.state := INCREMENTING_BIT_INDEX;
            
            when INCREMENTING_BIT_INDEX =>
                r.bit_index := cr.bit_index+1;
                r.state     := GETTING_DATA;
                if cr.bit_index=DATA_BITS-1 then
                    r.state := WAITING_FOR_STOP;
                    if PARITY_BIT_TYPE/=NONE then
                        r.state := GETTING_PARITY;
                    end if;
                end if;
            
            when GETTING_PARITY =>
                if cycle_half then
                    r.state :=  CHECKING_PARITY;
                end if;
            
            when CHECKING_PARITY =>
                if (cr.parity xor rxd_sync)='0' then
                    r.error := '1';
                end if;
                r.state := WAITING_FOR_STOP;
            
            when WAITING_FOR_STOP =>
                if cycle_half then
                    r.state := CHECKING_STOP;
                end if;
            
            when CHECKING_STOP =>
                if rxd_sync='0' then
                    r.error := '1';
                end if;
                r.valid := '1';
                r.state := WAITING_FOR_SENDER;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        next_reg    <= r;
        
    end process;
    
    stm_sync_proc : process(RST, CLK)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(CLK) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

