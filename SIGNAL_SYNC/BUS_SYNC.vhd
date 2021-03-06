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
    
    bus_SIGNAL_SYNC_gen : for i in 0 to WIDTH-1 generate
        
        bit_SIGNAL_SYNC_inst : entity work.SIGNAL_SYNC
            generic map (
                SHIFT_LEVELS    => SHIFT_LEVELS
            )
            port map (
                CLK     => CLK,
                DIN     => DIN(i),
                DOUT    => DOUT(i)
            );
        
    end generate;
    
end rtl;



