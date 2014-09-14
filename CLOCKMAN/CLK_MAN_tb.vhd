--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   01:53:42 09/14/2014
-- Module Name:   CLK_MAN_tb.vhd
-- Project Name:  CLK_MAN
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: CLK_MAN
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY CLK_MAN_tb IS
END CLK_MAN_tb;
 
ARCHITECTURE behavior OF CLK_MAN_tb IS 
   
   --Inputs
   signal clk_in    : std_ulogic := '0';
   signal rst       : std_ulogic := '0';

 	--outputs
   signal clk_out           : std_ulogic;
   signal clk_out_180       : std_ulogic;
   signal clk_in_stopped    : std_ulogic;
   signal clk_out_stopped   : std_ulogic;

   -- Clock period definitions
   constant clk_in_period       : time := 10 ns;
   constant clk_in_period_real  : real := real(clk_in_period / 1 ps) / real(1 ns / 1 ps);
 
BEGIN
 
	CLK_MAN_inst : entity work.CLK_MAN
        generic map (
            CLK_IN_PERIOD   => clk_in_period_real,
            MULTIPLIER      => 2,
            DIVISOR         => 4
        )
        port map (
            CLK_IN  => clk_in,
            RST     => rst,

            CLK_OUT           => clk_out,
            CLK_OUT_180       => clk_out_180,
            CLK_IN_STOPPED    => clk_in_stopped,
            CLK_OUT_STOPPED   => clk_out_stopped
        );
    
    -- clock generation
    clk_in  <= not clk_in after clk_in_period/2;
    
        -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for CLK_IN_period*10;
        
        -- insert stimulus here 
        
        wait;
    end process;
    
END;
