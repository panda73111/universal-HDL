--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   10:11:32 09/16/2014
-- Module Name:   SIGNAL_SYNC_tb.vhd
-- Project Name:  SIGNAL_SYNC
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: SIGNAL_SYNC
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY SIGNAL_SYNC_tb IS
END SIGNAL_SYNC_tb;

ARCHITECTURE behavior OF SIGNAL_SYNC_tb IS 

    -- Inputs
    signal clk_in   : std_logic := '0';
    signal clk_out  : std_logic := '0';

    signal d0, d1, d2   : std_logic := '0';

    -- Clock period definitions
    constant clk_in_period  : time := 10 ns;
    constant clk_out_period : time := 33 ns;

BEGIN

    SIGNAL_SYNC1_inst : entity work.SIGNAL_SYNC
        port map (
            CLK => clk_out,
            
            DIN => d0,
            
            DOUT    => d1
        );

    SIGNAL_SYNC2_inst : entity work.SIGNAL_SYNC
        generic map (
            SHIFT_LEVELS    => 8
        )
        port map (
            CLK => clk_in,
            
            DIN => d1,
            
            DOUT    => d2
        );

    -- Clock process definitions
    clk_in  <= not clk_in after clk_in_period/2;
    clk_out <= not clk_out after clk_out_period/2;

    -- Stimulus process
    stim_proc: process
    begin
        wait for CLK_IN_period*10;
        wait until rising_edge(clk_in);
        
        -- insert stimulus here 
        
        for i in 1 to 10 loop
            
            d0  <= '1';
            wait for clk_in_period*i;
            d0  <= '0';
            wait for clk_in_period*10*i;
        
        end loop;
        
        report "NONE. All tests completed."
            severity FAILURE;
    end process;

END;
