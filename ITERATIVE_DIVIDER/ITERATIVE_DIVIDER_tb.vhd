--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   18:26:0 12/30/2014
-- Module Name:   ITERATIVE_DIVIDER_tb
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: ITERATIVE_DIVIDER
-- 
-- Additional Comments:
--
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;

ENTITY ITERATIVE_DIVIDER_tb IS
    generic (
        WIDTH   : natural := 16
    );
END ITERATIVE_DIVIDER_tb;

ARCHITECTURE rtl OF ITERATIVE_DIVIDER_tb IS
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal START    : std_ulogic := '0';
    
    signal DIVIDEND : std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
    signal DIVISOR  : std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
    
    -- Outputs
    signal VALID    : std_ulogic;
    signal ERROR    : std_ulogic;
    signal RESULT   : std_ulogic_vector(WIDTH-1 downto 0);
    
    constant CLK_PERIOD : time := 10 ns;
    
BEGIN
    
    ITERATIVE_DIVIDER_inst : entity work.ITERATIVE_DIVIDER
        generic map (
            WIDTH   => WIDTH
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            START   => START,
            
            DIVIDEND    => DIVIDEND,
            DIVISOR     => DIVISOR,
            
            VALID   => VALID,
            ERROR   => ERROR,
            
            RESULT  => RESULT
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
        
        procedure division_test(
            constant l, r   : in natural;
            constant expected_result : in natural;
            constant expect_error   : in boolean
        ) is
            variable timeout    : natural;
        begin
            wait until rising_edge(CLK);
            DIVIDEND    <= stdulv(l, WIDTH);
            DIVISOR     <= stdulv(r, WIDTH);
            START       <= '1';
            wait until rising_edge(CLK);
            START   <= '0';
            timeout := 2**WIDTH+10;
            
            while timeout > 0 loop
                if expect_error then
                    
                    assert VALID='0'
                        report "Expected error but got VALID high!"
                        severity FAILURE;
                    
                    if ERROR='1' then exit; end if;
                    
                else
                    
                    assert ERROR='0'
                        report "Expected valid result but got ERROR high!"
                        severity FAILURE;
                    
                    if VALID='1' then
                        assert RESULT=stdulv(expected_result, WIDTH)
                            report "Got wrong result!"
                            severity FAILURE;
                        exit;
                    end if;
                    
                end if;
                wait until rising_edge(CLK);
                timeout := timeout-1;
            end loop;
            
            assert timeout > 0
                report "Timeout!"
                severity FAILURE;
        end procedure;
        
    begin		
        -- hold reset state for 100 ns.
        RST <= '1';
        wait for 1 us;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK);
        
        -- insert stimulus here
        
        division_test(   1,    1,    1, false);
        division_test( 100,   10,   10, false);
        division_test(  10,  100,    0, false);
        division_test(2**WIDTH-1, 1, 2**WIDTH-1, false);
        division_test(1000,   33,   30, false);
        division_test(   1,    0,    0, true);
        
        wait for 10 us;
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;