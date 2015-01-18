--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   13:20:42 09/16/2014
-- Module Name:   FLAG_SYNC_tb.vhd
-- Project Name:  FLAG_SYNC
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: FLAG_SYNC
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY FLAG_SYNC_tb IS
END FLAG_SYNC_tb;

ARCHITECTURE behavior OF FLAG_SYNC_tb IS 

    -- Inputs
    signal clk_in   : std_logic := '0';
    signal clk_out  : std_logic := '0';

    signal d0, d1, d2   : std_logic := '0';

    -- Clock period definitions
    constant clk_in_period  : time := 50 ns; -- 20 MHz
    constant clk_out_period : time := 20 ns; -- 50 MHz
    
    signal flag_count   : natural := 0;

BEGIN

    FLAG_SYNC1_inst : entity work.FLAG_SYNC
        port map (
            CLK_IN  => clk_in,
            CLK_OUT => clk_out,
            
            DIN => d0,
            
            DOUT    => d1
        );

    FLAG_SYNC2_inst : entity work.FLAG_SYNC
        generic map (
            SHIFT_LEVELS    => 8
        )
        port map (
            CLK_IN  => clk_out,
            CLK_OUT => clk_in,
            
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
        
        for keep_high in 0 to 1 loop
            flag_count  <= 0;
            for i in 0 to 1023 loop
                
                d0  <= '1';
                wait for clk_in_period*((i*keep_high)+1);
                d0  <= '0';
                wait for clk_in_period*7*((i*keep_high)+1);
                
                flag_count  <= flag_count+1;
                
            end loop;
            wait for 10 us;
        end loop;
        
        report "NONE. All tests completed."
            severity FAILURE;
    end process;

END;
