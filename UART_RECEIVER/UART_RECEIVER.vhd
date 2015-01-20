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
        PARITY_BIT_TYPE : natural range 0 to 2 := 0;
        BUFFER_SIZE     : natural := 512
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        RXD     : in std_ulogic;
        RD_EN   : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(DATA_BITS-1 downto 0);
        VALID   : out std_ulogic := '0';
        FULL    : out std_ulogic := '0';
        EMPTY   : out std_ulogic := '0';
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
        WAIT_FOR_SENDER,
        WAIT_FOR_START,
        WAIT_FOR_DATA,
        GET_DATA,
        APPLY_DATA,
        INCREMENT_BIT_INDEX,
        GET_PARITY,
        CHECK_PARITY,
        WAIT_FOR_STOP,
        CHECK_STOP,
        PUSH_DATA
    );
    
    type reg_type is record
        state       : state_type;
        tick_cnt    : natural range 0 to cycle_ticks-1;
        receiving   : boolean;
        bit_index   : unsigned(2 downto 0);
        fifo_din    : std_ulogic_vector(DATA_BITS-1 downto 0);
        fifo_wr_en  : std_ulogic;
        parity      : std_ulogic;
        error       : std_ulogic;
    end record;
    
    constant reg_type_def : reg_type := (
        state       => WAIT_FOR_SENDER,
        tick_cnt    => 0,
        receiving   => false,
        bit_index   => "000",
        fifo_din    => (others => '0'),
        fifo_wr_en  => '0',
        parity      => '0',
        error       => '0'
    );
    
    signal cycle_half           : boolean := false;
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    BUSY    <= '1' when cur_reg.receiving else '0';
    ERROR   <= cur_reg.error;
    
    cycle_half  <= cur_reg.tick_cnt=cycle_ticks/2-1;
    
    ASYNC_FIFO_inst : entity work.ASYNC_FIFO
        generic map (
            WIDTH   => DATA_BITS,
            DEPTH   => BUFFER_SIZE
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            DIN     => cur_reg.fifo_din,
            WR_EN   => cur_reg.fifo_wr_en,
            RD_EN   => RD_EN,
            
            DOUT    => DOUT,
            RD_ACK  => VALID,
            FULL    => FULL,
            EMPTY   => EMPTY
        );
    
    stm_proc : process(cur_reg, RST, RXD, cycle_half)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        
        r   := cr;
        
        r.fifo_wr_en    := '0';
        r.tick_cnt      := cr.tick_cnt+1;
        if
            not cr.receiving or
            cr.tick_cnt=cycle_ticks-1
        then
            r.tick_cnt  := 0;
        end if;
        
        case cr.state is
            
            when WAIT_FOR_SENDER =>
                r.receiving := false;
                r.bit_index := "000";
                r.state := WAIT_FOR_START;
            
            when WAIT_FOR_START =>
                if RXD='0' then
                    r.state := WAIT_FOR_DATA;
                end if;
            
            when WAIT_FOR_DATA =>
                r.receiving := true;
                r.parity    := '1';
                if PARITY_BIT_TYPE=ODD then
                    r.parity    := '0';
                end if;
                if cycle_half then
                    r.state := GET_DATA;
                end if;
                if RXD='1' then
                    -- invalid START bit
                    r.error := '1';
                    r.state := WAIT_FOR_SENDER;
                end if;
            
            when GET_DATA =>
                if cycle_half then
                    r.state := APPLY_DATA;
                end if;
            
            when APPLY_DATA =>
                r.fifo_din(int(cr.bit_index))   := RXD;
                if RXD='1' then
                    r.parity    := not cr.parity;
                end if;
                r.state := INCREMENT_BIT_INDEX;
            
            when INCREMENT_BIT_INDEX =>
                r.bit_index := cr.bit_index+1;
                r.state     := GET_DATA;
                if cr.bit_index=DATA_BITS-1 then
                    r.state := WAIT_FOR_STOP;
                    if PARITY_BIT_TYPE/=NONE then
                        r.state := GET_PARITY;
                    end if;
                end if;
            
            when GET_PARITY =>
                if cycle_half then
                    r.state :=  CHECK_PARITY;
                end if;
            
            when CHECK_PARITY =>
                if (cr.parity xor RXD)='0' then
                    r.error := '1';
                end if;
                r.state := WAIT_FOR_STOP;
            
            when WAIT_FOR_STOP =>
                if cycle_half then
                    r.state := CHECK_STOP;
                end if;
            
            when CHECK_STOP =>
                if RXD='0' then
                    r.error := '1';
                end if;
                r.state := PUSH_DATA;
            
            when PUSH_DATA =>
                r.fifo_wr_en    := '1';
                r.state         := WAIT_FOR_SENDER;
            
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

