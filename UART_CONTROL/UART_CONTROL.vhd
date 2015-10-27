----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    19:28:34 10/27/2015
-- Module Name:    UART_CONTROL - rtl 
-- Project Name:   UART_CONTROL
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  Controller component for UART communication
-- Additional Comments:
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity UART_CONTROL is
    generic (
        CLK_IN_PERIOD   : real;
        BAUD_RATE       : positive := 115_200;
        DATA_BITS       : positive range 5 to 8 := 8;
        STOP_BITS       : positive range 1 to 2 := 1;
        PARITY_BIT_TYPE : natural range 0 to 2 := 0;
        BUFFER_SIZE     : positive := 512
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        CTS : in std_ulogic;
        RTS : out std_ulogic := '0';
        RXD : in std_ulogic;
        TXD : out std_ulogic := '1';
        
        DIN         : in std_ulogic_vector(7 downto 0);
        DIN_WR_EN   : in std_ulogic;
        
        DOUT        : out std_ulogic_vector(7 downto 0) := x"00";
        DOUT_VALID  : out std_ulogic := '0';
        
        FULL    : out std_ulogic := '0';
        ERROR   : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0'
    );
end UART_CONTROL;

architecture rtl of UART_CONTROL is
    
    signal rx_busy, tx_busy : std_ulogic := '0';
    
begin
    
    RTS     <= '1';
    BUSY    <= rx_busy or tx_busy;
    
    UART_SENDER_inst : entity work.UART_SENDER
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            BAUD_RATE       => BAUD_RATE,
            DATA_BITS       => DATA_BITS,
            STOP_BITS       => STOP_BITS,
            PARITY_BIT_TYPE => PARITY_BIT_TYPE,
            BUFFER_SIZE     => BUFFER_SIZE
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            DIN     => DIN,
            WR_EN   => DIN_WR_EN,
            CTS     => CTS,
            
            TXD     => TXD,
            FULL    => FULL,
            BUSY    => tx_busy
        );
    
    UART_RECEIVER_inst : entity work.UART_RECEIVER
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            BAUD_RATE       => BAUD_RATE,
            DATA_BITS       => DATA_BITS,
            PARITY_BIT_TYPE => PARITY_BIT_TYPE
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            RXD     => RXD,
            
            DOUT    => DOUT,
            VALID   => DOUT_VALID,
            
            ERROR   => ERROR,
            BUSY    => rx_busy
        );
    
end rtl;
