----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    19:39:55 11/19/2014 
-- Module Name:    DEBOUNCE - rtl 
-- Project Name:   DEBOUNCE
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--  Simple debounce component, applies a signal after the defined
--  cycles of steadiness
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DEBOUNCE is
    generic (
        CYCLE_COUNT : natural := 10
    );
    port (
        CLK : in std_ulogic;
        
        I   : in std_ulogic;
        O   : out std_ulogic := '0'
    );
end DEBOUNCE;

architecture rtl of DEBOUNCE is
    
    type state_type is (
        STABLE,
        RESETTING,
        WAITING
    );
    
    signal state    : state_type := STABLE;
    signal counter  : natural range 0 to CYCLE_COUNT-1 := 0;
    signal I_q      : std_ulogic := '0';
begin
    
    process(CLK)
    begin
        if rising_edge(CLK) then
            I_q <= I;
            case state is
                
                when STABLE =>
                    if I/=I_q then
                        state   <= RESETTING;
                    end if;
                
                when RESETTING =>
                    counter <= 0;
                    if I=I_q then
                        state   <= WAITING;
                    end if;
                
                when WAITING =>
                    counter <= counter+1;
                    if I/=I_q then
                        state   <= RESETTING;
                    elsif counter=CYCLE_COUNT-2 then
                        O       <= I;
                        state   <= STABLE;
                    end if;
                
            end case;
        end if;
    end process;
    
end rtl;

