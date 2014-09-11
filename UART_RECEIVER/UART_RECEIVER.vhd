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

entity UART_RECEIVER is
    generic (
        CLK_IN_PERIOD   : real;
        BAUD_RATE       : natural := 115_200;
        DATA_BITS       : natural range 5 to 8 := 8;
        STOP_BITS       : natural range 1 to 2 := 1;
        PARITY_BIT_TYPE : string := "NONE";
        BUFFER_SIZE     : natural := 128
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        WR_EN   : in std_ulogic;
        RXD     : in std_ulogic;
        RTS     : out std_ulogic := '1';
        
        DOUT    : out std_ulogic_vector(DATA_BITS-1 downto 0);
        FULL    : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0'
    );
end UART_RECEIVER;

architecture rtl of UART_RECEIVER is
    
    constant bit_period     : real := 1_000_000_000.0 / real(BAUD_RATE);
    constant cycle_ticks    : positive := integer(bit_period / CLK_IN_PERIOD);
    
    type state_type is (
        INIT
    );
    
    type reg_type is record
        state       : state_type;
        tick_cnt    : natural range 0 to cycle_ticks-1;
        sending     : boolean;
        bit_index   : unsigned(2 downto 0);
        txd         : std_ulogic;
        fifo_wr_en  : std_ulogic;
        parity      : std_ulogic;
    end record;
    
    constant reg_type_def : reg_type := (
        state       => INIT,
        tick_cnt    => 0,
        sending     => false,
        bit_index   => "000",
        txd         => '1',
        fifo_wr_en  => '0',
        parity      => '0'
    );
    
    signal fifo_rd_en   : std_ulogic := '0';
    signal fifo_dout    : std_ulogic_vector(DATA_BITS-1 downto 0) := (others => '0');
    signal fifo_empty   : std_ulogic := '0';
    
    signal cycle_end    : boolean := false; -- 'true' when cycle_ticks-1 ticks passed
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    


end rtl;

