--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   15:27:10 12/11/2014
-- Module Name:   VIDEO_TIMING_GEN_tb.vhd
-- Project Name:  VIDEO_TIMING_GEN
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: VIDEO_TIMING_GEN
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.video_profiles.all;

ENTITY VIDEO_TIMING_GEN_tb IS
END VIDEO_TIMING_GEN_tb;

ARCHITECTURE rtl OF VIDEO_TIMING_GEN_tb IS

    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal PROFILE  : std_ulogic_vector(PROFILE_BITS-1 downto 0) := (others => '0');
    
    -- Outputs
    signal POS_VSYNC    : std_ulogic := '0';
    signal POS_HSYNC    : std_ulogic := '0';
    signal VSYNC        : std_ulogic := '0';
    signal HSYNC        : std_ulogic := '0';
    signal RGB_ENABLE   : std_ulogic := '0';
    signal X            : std_ulogic_vector(X_BITS-1 downto 0) := (others => '0');
    signal Y            : std_ulogic_vector(Y_BITS-1 downto 0) := (others => '0');
    
    constant FRAME_COUNT    : natural := 10;
    
BEGIN
    
    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(pix_clk);
        
        -- insert stimulus here 
        
        wait for 100 ns;
        report "NONE. All tests completed successfully"
            severity FAILURE;
    end process;

END;
