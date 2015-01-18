----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    13:19:55 09/16/2014 
-- Module Name:    SIGNAL_SYNC - rtl 
-- Project Name:   SIGNAL_SYNC
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FLAG_SYNC is
    generic (
        SHIFT_LEVELS    : positive range 3 to 16 := 3
    );
    port (
        CLK_IN  : in std_ulogic;
        CLK_OUT : in std_ulogic;
        
        DIN : in std_ulogic;
        
        DOUT    : out std_ulogic := '0'
    );
end FLAG_SYNC;

architecture rtl of FLAG_SYNC is
    signal toggle_in    : std_ulogic := '0';
    signal q            : std_ulogic_vector(SHIFT_LEVELS-1 downto 0)
                            := (others => '0');
begin
    
    DOUT    <= q(q'high) xor q(q'high-1);
    
    sync_in_proc : process(CLK_IN)
    begin
        if rising_edge(CLK_IN) then
            toggle_in   <= toggle_in xor DIN;
        end if;
    end process;
    
    sync_out_proc : process(CLK_OUT)
    begin
        if rising_edge(CLK_OUT) then
            q(q'high downto 1)  <= q(q'high-1 downto 0);
            q(0)                <= toggle_in;
        end if;
    end process;
    
end rtl;

