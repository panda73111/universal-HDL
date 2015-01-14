--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   12:54:00 01/14/2014
-- Module Name:   GRAY_CODE_COUNTER_tb.vhd
-- Project Name:  GRAY_CODE_COUNTER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.help_funcs.all;
 
entity GRAY_CODE_COUNTER_tb is
end GRAY_CODE_COUNTER_tb;

architecture behavior of GRAY_CODE_COUNTER_tb is
    
    -- inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal EN   : std_ulogic := '0';
    
    -- outputs
    signal COUNTER  : std_ulogic_vector(7 downto 0);
    
    -- clock period definitions
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    
begin
    
    GRAY_CODE_COUNTER_inst : entity work.GRAY_CODE_COUNTER
        generic map (
            WIDTH   => 8
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            EN  => EN,
            
            COUNTER => COUNTER
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    stim_proc : process
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK);
        
        EN  <= '1';
        wait for 1 us;
        EN  <= '0';
        wait for 1 us;
        EN  <= '1';
        wait for 10 us;
        
        report "NONE. All tests completed."
            severity FAILURE;
    end process;
    
end;