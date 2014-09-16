--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   23:36:00 09/11/2014
-- Module Name:   UART_RECEIVER_tb.vhd
-- Project Name:  UART_RECEIVER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: UART_RECEIVER
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
 
ENTITY SPI_FLASH_CONTROL_tb IS
END SPI_FLASH_CONTROL_tb;

ARCHITECTURE behavior OF SPI_FLASH_CONTROL_tb IS
    
    -- Inputs
    signal clk      : std_ulogic := '0';
    signal rst      : std_ulogic := '0';
    signal addr     : std_ulogic_vector(23 downto 0) := x"000000";
    signal din      : std_ulogic_vector(7 downto 0) := x"00";
    signal rd_en    : std_ulogic := '0';
    signal wr_en    : std_ulogic := '0';
    signal bulk     : std_ulogic := '0';
    signal dq1      : std_ulogic := '0';
    
    -- Outputs
    signal dout    : std_ulogic_vector(7 downto 0);
    signal valid   : std_ulogic := '0';
    signal wr_ack  : std_ulogic;
    signal busy    : std_ulogic;
    signal dq0     : std_ulogic;
    signal c       : std_ulogic;
    signal sn      : std_ulogic;
    
    -- clock period definitions
    constant clk_period         : time := 10 ns;
    constant clk_period_real    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
BEGIN

    SPI_FLASH_CONTROL_inst : entity work.SPI_FLASH_CONTROL
        generic map (
            CLK_IN_PERIOD   => clk_period_real,
            CLK_OUT_MULT    => 2,
            CLK_OUT_DIV     => 4
        )
        port map (
            CLK => clk,
            RST => rst,
            
            ADDR    => addr,
            DIN     => din,
            RD_EN   => rd_en,
            WR_EN   => wr_en,
            DQ1     => dq1,
            
            DOUT    => dout,
            VALID   => valid,
            WR_ACK  => wr_ack,
            BUSY    => busy,
            DQ0     => dq0,
            C       => c,
            SN      => sn
        );
    
    -- clock generation
    clk <= not clk after clk_period / 2;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*10;
        wait until rising_edge(clk);
        
        -- insert stimulus here
        
        wait until busy='0';
        wait until rising_edge(clk);
        
        -- read one byte at address 0xABCDEF
        addr    <= x"ABCDEF";
        rd_en   <= '1';
        wait until rising_edge(clk);
        rd_en   <= '0';
        wait until rising_edge(clk);
        
        wait until busy='1';
        wait until busy='0';
        wait for 10 us;
        
        -- write one byte 0x77 at address 0xABCDEF
        addr    <= x"ABCDEF";
        din     <= x"77";
        wr_en   <= '1';
        wait until rising_edge(clk);
        wr_en   <= '0';
        wait until rising_edge(clk);
        
        wait until busy='1';
        wait until busy='0';
        wait for 10 us;
        report "NONE. All tests completed." severity failure;
    end process;
    
END;