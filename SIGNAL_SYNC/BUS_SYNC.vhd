----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    18:37:05 12/21/2014 
-- Module Name:    BUS_SYNC - rtl 
-- Project Name:   BUS_SYNC
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity BUS_SYNC is
    generic (
        WIDTH           : positive := 8;
        SHIFT_LEVELS    : positive range 2 to 16 := 2
    );
    port (
        CLK : in std_ulogic;
        
        DIN : in std_ulogic_vector(WIDTH-1 downto 0);
        
        DOUT    : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0')
    );
end BUS_SYNC;

architecture rtl of BUS_SYNC is
    signal q    : std_ulogic_vector(WIDTH*(SHIFT_LEVELS-1)-1 downto 0)
                    := (others => '0');
begin
    
    shift_gen : if SHIFT_LEVELS>2 generate
        
        shift_proc : process(CLK)
        begin
            if rising_edge(CLK) then
                q(q'high downto WIDTH)    <= q(q'high-WIDTH downto 0);
            end if;
        end process;
        
    end generate;
    
    sync_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            DOUT                <= q(q'high downto q'high-WIDTH+1);
            q(WIDTH-1 downto 0) <= DIN;
        end if;
    end process;
    
end rtl;



