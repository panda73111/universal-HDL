----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    08:47:55 11/13/2014 
-- Module Name:    BIDIR_REPEAT_BUFFER - Behavioral 
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--  Bidirectional buffer working as a repeater, including debounce logic
--  for weak pullups/pulldowns, so that after releasing the signal, the
--  input buffer doesn't read the own pulled signal level and deadlocks
-- Additional Comments: 
--  generics:
--   PULL               : "UP"/"DOWN", sets the signal level when floating
--   DEBOUNCE_CYCLES    : how many clock cycles the buffer waits until re-reading
--  ports:
--   CLK    : input clock
--   P0_IN  : first port input
--   P0_OUT : first port output
--   P1_IN  : second port input
--   P1_OUT : second port output
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity BIDIR_REPEAT_BUFFER is
    generic (
        PULL            : string := "UP";
        DEBOUNCE_CYCLES : natural := 5
    );
    port (
        CLK : in std_ulogic;
        
        P0_IN   : in std_ulogic;
        P0_OUT  : out std_ulogic := '0';
        P1_IN   : in std_ulogic;
        P1_OUT  : out std_ulogic := '0'
    );
end BIDIR_REPEAT_BUFFER;

architecture Behavioral of BIDIR_REPEAT_BUFFER is
    
    constant FLOATING_LEVEL : std_ulogic := sel(PULL="UP", '1', '0');
    constant DRIVING_LEVEL  : std_ulogic := sel(PULL="UP", '0', '1');
    
    type state_type is (
        FLOATING,
        P0_DRIVING,
        P1_DRIVING,
        DEBOUNCING
    );
    
    signal state        : state_type := FLOATING;
    signal cycle_cnt    : natural range 0 to DEBOUNCE_CYCLES-1 := 0;
    
begin
    
    process(CLK)
    begin
        if rising_edge(CLK) then
            case state is
                
                when FLOATING =>
                    P0_OUT  <= FLOATING_LEVEL;
                    P1_OUT  <= FLOATING_LEVEL;
                    if P0_IN=DRIVING_LEVEL then
                        state   <= P0_DRIVING;
                    end if;
                    if P1_IN=DRIVING_LEVEL then
                        state   <= P1_DRIVING;
                    end if;
                
                when P0_DRIVING =>
                    P0_OUT  <= FLOATING_LEVEL;
                    P1_OUT  <= DRIVING_LEVEL;
                    if P0_IN=FLOATING_LEVEL then
                        P1_out  <= FLOATING_LEVEL;
                        state   <= DEBOUNCING;
                    end if;
                
                when P1_DRIVING =>
                    P0_OUT  <= DRIVING_LEVEL;
                    P1_OUT  <= FLOATING_LEVEL;
                    if P0_IN=FLOATING_LEVEL then
                        P0_OUT  <= FLOATING_LEVEL;
                        state   <= DEBOUNCING;
                    end if;
                
                when DEBOUNCING =>
                    P0_OUT      <= FLOATING_LEVEL;
                    P1_OUT      <= FLOATING_LEVEL;
                    cycle_cnt   <= cycle_cnt+1;
                    if cycle_cnt=DEBOUNCE_CYCLES-1 then
                        cycle_cnt   <= 0;
                        state       <= FLOATING;
                    end if;
                
            end case;
        end if;
    end process;
    
end Behavioral;