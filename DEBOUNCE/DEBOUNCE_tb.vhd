--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   19:52:23 11/19/2014
-- Design Name:   
-- Module Name:   D:/GitHub/VHDL/universal-HDL/DEBOUNCE/DEBOUNCE_tb.vhd
-- Project Name:  DEBOUNCE
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: DEBOUNCE
-- 
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY DEBOUNCE_tb IS
END DEBOUNCE_tb;
 
ARCHITECTURE behavior OF DEBOUNCE_tb IS 
    
    -- Inputs
    signal CLK  : std_logic := '0';
    signal I    : std_logic := '0';
    
    -- Outputs
    signal O    : std_logic;
    
    -- Clock period definitions
    constant CLK_period : time := 10 ns;
    
BEGIN
    
    DEBOUNCE_inst : entity work.DEBOUNCE
        PORT MAP (
            CLK => CLK,
            
            I   => I,
            O   => O
        );
    
    CLK <= not CLK after CLK_period/2;
    
    -- Stimulus process
    stim_proc: process
    begin
        I   <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK);
        -- insert stimulus here 
        
        I   <= '1';
        wait for CLK_period * 2;
        I   <= '0';
        wait for CLK_period * 4;
        I   <= '1';
        wait for CLK_period * 2;
        I   <= '0';
        wait for CLK_period * 4;
        I   <= '1';
        
        wait for CLK_period * 20;
        
        I   <= '1';
        wait for CLK_period * 4;
        I   <= '0';
        wait for CLK_period * 2;
        I   <= '1';
        wait for CLK_period * 4;
        I   <= '0';
        
        wait for CLK_period * 20;
        
        report "NONE. All tests comleted successfully"
            severity FAILURE;
        
        wait;
    end process;

END;
