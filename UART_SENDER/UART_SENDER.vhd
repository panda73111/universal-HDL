----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    14:03:27 09/10/2014 
-- Module Name:    UART_SENDER - rtl 
-- Project Name:   UART_SENDER
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity UART_SENDER is
    generic (
        CLK_IN_PERIOD   : real;
        BAUD_RATE       : natural := 115200;
        DATA_BITS       : natural range 5 to 8 := 8;
        STOP_BITS       : natural range 1 to 2 := 1;
        PARITY_BIT_TYPE : string := "NONE";
        BUFFER_SIZE     : natural := 128
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        DIN     : in std_ulogic_vector(DATA_BITS-1 downto 0);
        WR_EN   : in std_ulogic;
        CTS     : in std_ulogic;
        
        TXD     : out std_ulogic := '1';
        FULL    : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0'
    );
end UART_SENDER;

architecture rtl of UART_SENDER is
    
    constant bit_period     : real := 1000000000.0 / real(BAUD_RATE);
    constant cycle_ticks    : positive := integer(bit_period / CLK_IN_PERIOD);
    
    type state_type is (
        INIT,
        WAIT_FOR_RECEIVER,
        SEND_START_BIT,
        WAIT_FOR_DATA,
        SEND_DATA_BIT,
        INCREMENT_BIT_INDEX,
        SEND_PARITY_BIT,
        SEND_STOP_BIT,
        SEND_SECOND_STOP_BIT
    );
    
    type reg_type is record
        state       : state_type;
        tick_cnt    : natural range 0 to cycle_ticks-1;
        sending     : boolean;
        bit_index   : unsigned(2 downto 0);
        txd         : std_ulogic;
        fifo_rd_en  : std_ulogic;
        parity      : std_ulogic;
    end record;
    
    constant reg_type_def : reg_type := (
        state       => INIT,
        tick_cnt    => 0,
        sending     => false,
        bit_index   => "000",
        txd         => '1',
        fifo_rd_en  => '0',
        parity      => '0'
    );
    
    signal fifo_rd_en   : std_ulogic := '0';
    signal fifo_dout    : std_ulogic_vector(DATA_BITS-1 downto 0) := (others => '0');
    signal fifo_empty   : std_ulogic := '0';
    
    signal cycle_end    : boolean := false; -- 'true' when cycle_ticks-1 ticks passed
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    TXD     <= cur_reg.txd;
    BUSY    <= '1' when fifo_empty='0' or cur_reg.sending else '0';
    
    cycle_end   <= cur_reg.tick_cnt=cycle_ticks-2;
    fifo_rd_en  <= cur_reg.fifo_rd_en;
    
    ASYNC_FIFO_inst : entity work.ASYNC_FIFO
        generic map (
            WIDTH   => DATA_BITS,
            DEPTH   => BUFFER_SIZE
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            DIN     => DIN,
            WR_EN   => WR_EN,
            RD_EN   => fifo_rd_en,
            
            DOUT    => fifo_dout,
            FULL    => FULL,
            EMPTY   => fifo_empty
        );
    
    stm_proc : process(cur_reg, RST, fifo_dout, fifo_empty, CTS)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        
        r   := cr;
        
        r.fifo_rd_en    := '0';
        r.tick_cnt      := 0;
        if cr.sending then
            r.tick_cnt  := (cr.tick_cnt+1) mod cycle_ticks;
        end if;
        
        case cr.state is
            
            when INIT =>
                r.txd       := '1';
                r.sending   := false;
                r.bit_index := "000";
                if fifo_empty='0' then
                    r.state     := WAIT_FOR_RECEIVER;
                end if;
            
            when WAIT_FOR_RECEIVER =>
                if CTS='1' then
                    r.state := SEND_START_BIT;
                end if;
            
            when SEND_START_BIT =>
                r.sending   := true;
                r.txd       := '0';
                r.parity    := '0';
                if PARITY_BIT_TYPE="ODD" then
                    r.parity    := '1';
                end if;
                if cycle_end then
                    r.fifo_rd_en    := '1';
                    r.state         := WAIT_FOR_DATA;
                end if;
            
            when WAIT_FOR_DATA =>
                r.state         := SEND_DATA_BIT;
            
            when SEND_DATA_BIT =>
                r.txd   := fifo_dout(int(cr.bit_index));
                if cycle_end then
                    r.state := INCREMENT_BIT_INDEX;
                end if;
            
            when INCREMENT_BIT_INDEX =>
                r.bit_index := cr.bit_index+1;
                if cr.txd='1' then
                    r.parity    := not cr.parity;
                end if;
                r.state     := SEND_DATA_BIT;
                if cr.bit_index=DATA_BITS-1 then
                    r.state := SEND_PARITY_BIT;
                    if PARITY_BIT_TYPE="NONE" then
                        r.state := SEND_STOP_BIT;
                    end if;
                end if;
            
            when SEND_PARITY_BIT =>
                r.txd   := cr.parity;
                if cycle_end then
                    r.state := SEND_STOP_BIT;
                end if;
            
            when SEND_STOP_BIT =>
                r.txd   := '1';
                if cycle_end then
                    r.state := WAIT_FOR_RECEIVER;
                    if STOP_BITS=2 then
                        r.state := SEND_SECOND_STOP_BIT;
                    elsif fifo_empty='1' then
                        r.state := INIT;
                    end if;
                end if;
            
            when SEND_SECOND_STOP_BIT =>
                if cycle_end then
                    r.state := WAIT_FOR_RECEIVER;
                    if fifo_empty='1' then
                        r.state := INIT;
                    end if;
                end if;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        next_reg    <= r;
        
    end process;
    
    stm_sync_proc : process(CLK, RST)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(CLK) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

