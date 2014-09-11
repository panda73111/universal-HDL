--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   16:29:24 09/10/2014
-- Module Name:   UART_SENDER_tb.vhd
-- Project Name:  UART_SENDER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: UART_SENDER
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.txt_util.all;
 
ENTITY UART_SENDER_tb IS
END UART_SENDER_tb;
 
ARCHITECTURE behavior OF UART_SENDER_tb IS 
    
    -- Inputs
    signal clk      : std_ulogic := '0';
    signal rst      : std_ulogic := '0';
    signal din      : std_ulogic_vector(7 downto 0) := (others => '0');
    signal wr_en    : std_ulogic := '0';
    signal cts      : std_ulogic := '0';
    
    -- Outputs1
    signal txd1     : std_ulogic;
    signal full1    : std_ulogic;
    signal busy1    : std_ulogic;
    
    -- Outputs2
    signal txd2     : std_ulogic;
    signal full2    : std_ulogic;
    signal busy2    : std_ulogic;
    
    -- clock period definitions
    constant clk_period         : time := 10 ns;
    constant clk_period_real    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
    constant NONE   : natural := 0;
    constant EVEN   : natural := 1;
    constant ODD    : natural := 2;
    
BEGIN

    UART_SENDER_inst1 : entity work.UART_SENDER
    generic map (
        CLK_IN_PERIOD   => clk_period_real,
        BAUD_RATE       => 9600,
        PARITY_BIT_TYPE => EVEN
    )
    port map (
        CLK => clk,
        RST => rst,
        
        DIN     => din,
        WR_EN   => wr_en,
        CTS     => cts,
        
        TXD     => txd1,
        FULL    => full1,
        BUSY    => busy1
    );

    UART_SENDER_inst2 : entity work.UART_SENDER
    generic map (
        CLK_IN_PERIOD   => clk_period_real,
        BAUD_RATE       => 115200,
        PARITY_BIT_TYPE => ODD
    )
    port map (
        CLK => clk,
        RST => rst,
        
        DIN     => din,
        WR_EN   => wr_en,
        CTS     => cts,
        
        TXD     => txd2,
        FULL    => full2,
        BUSY    => busy2
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
        cts <= '1';
        wait until rising_edge(clk);
        
        -- insert stimulus here 
        
        for i in character'pos('a') to character'pos('z') loop
            wr_en   <= '1';
            din     <= stdulv(i, 8);
            wait until rising_edge(clk);
        end loop;
        wr_en   <= '0';
        
        wait until (busy1 or busy2)='0';
        wait for 10 us;
        report "NONE. All tests completed." severity failure;
    end process;

END;
