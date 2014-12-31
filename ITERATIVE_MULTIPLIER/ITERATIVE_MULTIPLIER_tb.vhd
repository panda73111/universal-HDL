--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   14:43:50 12/31/2014
-- Module Name:   ITERATIVE_MULTIPLIER_tb
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: ITERATIVE_MULTIPLIER
-- 
-- Additional Comments:
--
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;

ENTITY ITERATIVE_MULTIPLIER_tb IS
    generic (
        WIDTH   : natural := 8
    );
END ITERATIVE_MULTIPLIER_tb;

ARCHITECTURE rtl OF ITERATIVE_MULTIPLIER_tb IS
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal START    : std_ulogic := '0';
    
    signal MULTIPLICAND : std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
    signal MULTIPLIER   : std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
    
    -- Outputs
    signal VALID    : std_ulogic;
    signal RESULT   : std_ulogic_vector(2*WIDTH-1 downto 0);
    
    constant CLK_PERIOD : time := 10 ns;
    
BEGIN
    
    ITERATIVE_MULTIPLIER_inst : entity work.ITERATIVE_MULTIPLIER
        generic map (
            WIDTH   => WIDTH
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            START   => START,
            
            MULTIPLICAND    => MULTIPLICAND,
            MULTIPLIER      => MULTIPLIER,
            
            VALID   => VALID,
            
            RESULT  => RESULT
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
        
        procedure multiplication_test(
            constant l, r   : in natural;
            constant expected_result : in natural
        ) is
            variable timeout    : natural;
        begin
            wait until rising_edge(CLK);
            MULTIPLICAND    <= stdulv(l, WIDTH);
            MULTIPLIER      <= stdulv(r, WIDTH);
            START       <= '1';
            wait until rising_edge(CLK);
            START   <= '0';
            timeout := 2**WIDTH+10;
            
            while timeout > 0 loop
                
                if VALID='1' then
                    assert RESULT=stdulv(expected_result, 2*WIDTH)
                        report "Got wrong result!"
                        severity FAILURE;
                    exit;
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
        
        multiplication_test(   1,    1,    1);
        multiplication_test( 100,   10, 1000);
        multiplication_test(  10,  100, 1000);
        multiplication_test(2**WIDTH-1, 1, 2**WIDTH-1);
        multiplication_test(2**WIDTH-1, 2**WIDTH-1, (2**WIDTH-1)**2);
        multiplication_test(  33,   33, 1089);
        multiplication_test(   1,    0,    0);
        multiplication_test(   0,    1,    0);
        
        wait for 10 us;
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;