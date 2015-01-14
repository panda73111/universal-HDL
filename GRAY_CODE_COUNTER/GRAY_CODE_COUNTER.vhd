----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    12:28:50 01/14/2015 
-- Module Name:    GRAY_CODE_COUNTER - rtl 
-- Project Name:   GRAY_CODE_COUNTER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--
-- Additional Comments:
--  reference: http://www.asic-world.com/examples/vhdl/asyn_fifo.html
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity GRAY_CODE_COUNTER is
    generic (
        WIDTH   : positive := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        EN  : in std_ulogic;
        
        COUNTER : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0')
    );
end GRAY_CODE_COUNTER;

architecture rtl of GRAY_CODE_COUNTER is
    signal bin_counter  : unsigned(WIDTH-1 downto 0) := (others => '0');
begin
    
    count_proc : process(RST, CLK)
    begin
        if RST='1' then
            bin_counter <= (others => '0');
            COUNTER     <= (others => '0');
        elsif rising_edge(CLK) then
            if EN='1' then
                bin_counter <= bin_counter+1;
            end if;
            COUNTER <=  bin_counter(WIDTH-1) &
                stdulv(bin_counter(WIDTH-1 downto 1) xor bin_counter(WIDTH-2 downto 0));
        end if;
    end process;
    
end rtl;
