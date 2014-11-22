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
    
    constant CYCLE_COUNT    : natural := 100;
    
    -- Inputs
    signal CLK  : std_logic := '0';
    signal I    : std_logic := '0';
    
    -- Outputs
    signal O    : std_logic;
    
    -- Clock period definitions
    constant CLK_period : time := 10 ns;
    
BEGIN
    
    DEBOUNCE_inst : entity work.DEBOUNCE
        generic map (
            CYCLE_COUNT => CYCLE_COUNT
        )
        port map (
            CLK => CLK,
            
            I   => I,
            O   => O
        );
    
    CLK <= not CLK after CLK_period/2;
    
    -- Stimulus process
    stim_proc: process
        procedure debounce_test(
            signal I                : out std_ulogic;
            signal O                : in std_ulogic;
            constant switching_time : in time;
            constant switch_count   : in natural;
            constant rest           : in boolean;
            constant resting_time   : in time
        ) is
        begin
            I   <= '1';
            wait for switching_time;
            for sw in 1 to switch_count loop
                I   <= '0';
                wait for switching_time;
                I   <= '1';
                wait for switching_time;
            end loop;
            
            if rest then
                wait for CYCLE_COUNT * CLK_period;
                assert O='0' report "resting, stage 1: O should be low but is high!" severity FAILURE;
                wait for CLK_period;
                -- I to O applying point
                assert O='1' report "resting, stage 2: O should be high but is low!" severity FAILURE;
                wait for resting_time;
            else
                assert O='0' report "not resting, stage 1: O should be low but is high!" severity FAILURE;
            end if;
            
            I   <= '0';
            wait for switching_time;
            for sw in 1 to switch_count loop
                I   <= '1';
                wait for switching_time;
                I   <= '0';
                wait for switching_time;
            end loop;
            
            wait for CYCLE_COUNT * CLK_period;
            if rest then
                assert O='1' report "resting, stage 3: O should be high but is low!" severity FAILURE;
                wait for CLK_period;
                -- I to O applying point
                assert O='0' report "resting, stage 4: O should be low but is high!" severity FAILURE;
            else
                wait for CLK_period;
                assert O='0' report "not resting, stage 2: O should be low but is high!" severity FAILURE;
            end if;
        end procedure;
    begin
        I   <= '0';
        assert O='0' report "The initial state of O is high" severity FAILURE;
        wait for 100 ns;
        wait until rising_edge(CLK);
        
        -- insert stimulus here 
        
        for rest in 0 to 1 loop
            for switch_count in 0 to 300 loop
                debounce_test(I, O, CLK_period, switch_count, rest=1, (CYCLE_COUNT / 2) * CLK_period);
            end loop;
        end loop;
        
        wait for 100 ns;
        report "NONE. All tests comleted successfully" severity FAILURE;
        
        wait;
    end process;

END;
