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
use work.help_funcs.all;
 
ENTITY CLK_MAN_tb IS
END CLK_MAN_tb;
 
ARCHITECTURE behavior OF CLK_MAN_tb IS 
   
   -- Inputs
   signal clk_in    : std_ulogic := '0';
   signal rst       : std_ulogic := '0';
    
    signal reprog_mult  : std_ulogic_vector(7 downto 0) := x"00";
    signal reprog_div   : std_ulogic_vector(7 downto 0) := x"00";
    signal reprog_en    : std_ulogic := '0';
    
 	-- Outputs
   signal clk_out           : std_ulogic;
   signal clk_out_180       : std_ulogic;
   signal clk_in_stopped    : std_ulogic;
   signal clk_out_stopped   : std_ulogic;
   signal locked            : std_ulogic;

   -- Clock period definitions
   constant clk_in_period       : time := 50 ns; -- 20 Mhz
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
            
            REPROG_MULT => reprog_mult,
            REPROG_DIV  => reprog_div,
            REPROG_EN   => reprog_en,
            
            CLK_OUT     => clk_out,
            CLK_OUT_180 => clk_out_180,
            
            CLK_IN_STOPPED  => clk_in_stopped,
            CLK_OUT_STOPPED => clk_out_stopped,
            LOCKED          => locked
        );
    
    -- clock generation
    clk_in  <= not clk_in after clk_in_period/2;
    
        -- Stimulus process
    stim_proc: process
        procedure reprog(mult, div : in natural) is
        begin            
            wait until locked='1';
            wait for 100 ns;
            reprog_mult <= stdulv(mult-1, 8);
            reprog_div  <= stdulv(div-1, 8);
            reprog_en   <= '1';
            wait until rising_edge(clk_in);
            reprog_en   <= '0';
        end procedure;
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 500 ns;
        rst <= '0';
        wait for clk_in_period*10;
        
        -- insert stimulus here
        
        -- 100 MHz
        reprog(5, 1);
        
        -- 75 MHz
        reprog(15, 4);
        
        -- 42 MHz
        reprog(21, 10);
        
        wait until locked='1';
        wait for 100 ns;
        report "NONE. All tests finished successfully."
            severity FAILURE;
        
    end process;
    
END;
