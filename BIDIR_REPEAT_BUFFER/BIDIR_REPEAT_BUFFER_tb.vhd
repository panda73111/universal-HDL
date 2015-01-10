--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   13:50:20 1/9/2015
-- Module Name:   BIDIR_REPEAT_BUFFER_tb
-- Project Name:  BIDIR_REPEAT_BUFFER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: BIDIR_REPEAT_BUFFER
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
library UNISIM;
use UNISIM.VComponents.all;

ENTITY BIDIR_REPEAT_BUFFER_tb IS
END BIDIR_REPEAT_BUFFER_tb;

ARCHITECTURE behavior OF BIDIR_REPEAT_BUFFER_tb IS 
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    
    signal P0_IN    : std_ulogic := '0';
    signal P1_IN    : std_ulogic := '0';
    
    -- Outputs
    signal P0_OUT   : std_ulogic;
    signal P1_OUT   : std_ulogic;
    
    -- Clock period definitions
    constant CLK_PERIOD : time := 10 ns; -- 100 Mhz
    
BEGIN
    
    BIDIR_REPEAT_BUFFER_inst : entity work.BIDIR_REPEAT_BUFFER
        generic map (
            PULL            => "UP",
            DEBOUNCE_CYCLES => 20
        )
        port map (
            CLK => CLK,
            
            P0_IN   => P0_IN,
            P0_OUT  => P0_OUT,
            P1_IN   => P1_IN,
            P1_OUT  => P1_OUT
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
    begin
        P0_IN   <= '1';
        P1_IN   <= '1';
        wait for 100 ns;
        P0_IN   <= '0';
        P1_IN   <= '0';
        wait for 100 ns;
        P0_IN   <= '1';
        P1_IN   <= '0';
        wait for 100 ns;
        P0_IN   <= '0';
        P1_IN   <= '0';
        wait for 100 ns;
        P0_IN   <= '0';
        P1_IN   <= '1';
        wait for 100 ns;
        P0_IN   <= '0';
        P1_IN   <= '0';
        wait for 100 ns;
        P0_IN   <= '1';
        P1_IN   <= '1';
        wait for 100 ns;
        
        wait for 100 ns;
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;
