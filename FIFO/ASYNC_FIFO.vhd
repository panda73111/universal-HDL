----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    10/26/2012 
-- Module Name:    ASYNC_FIFO - rtl 
-- Project Name:   ASYNC_FIFO
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

entity ASYNC_FIFO is
    generic (
        -- default: 1 Kilobyte in bytes
        WIDTH   : natural := 8;
        DEPTH   : natural := 1024
    );
    port (
        CLK     : in std_ulogic;
        RST     : in std_ulogic;
        
        DIN     : in std_ulogic_vector(WIDTH-1 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
        FULL    : out std_ulogic := '0';
        EMPTY   : out std_ulogic := '0';
        WR_ACK  : out std_ulogic := '0'; -- write was successful
        VALID   : out std_ulogic := '0'; -- read was successful
        COUNT   : out std_ulogic_vector(log2(DEPTH)-1 downto 0) := (others => '0')
    ); 
end ASYNC_FIFO;

architecture rtl of ASYNC_FIFO is
begin
    
    ASYNC_FIFO_2CLK_inst : entity work.ASYNC_FIFO_2CLK
        generic map (
            WIDTH   => WIDTH,
            DEPTH   => DEPTH
        )
        port map (
            RD_CLK  => CLK,
            WR_CLK  => CLK,
            RST     => RST,
            
            DIN     => DIN,
            RD_EN   => RD_EN,
            WR_EN   => WR_EN,
            
            DOUT    => DOUT,
            FULL    => FULL,
            EMPTY   => EMPTY,
            WR_ACK  => WR_ACK,
            VALID   => VALID,
            COUNT   => COUNT
        );
    
end rtl;

