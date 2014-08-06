
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.help_funcs.all;

entity SINGLE_PORT_RAM is
    generic (
        -- default: 1 Kilobyte in bytes
        WIDTH       : natural := 10;
        DEPTH       : natural := 8;
        WRITE_FIRST : boolean := true
    );
    port (
        CLK : in std_ulogic;

        ADDR    : in std_ulogic_vector(log2(DEPTH)-1 downto 0);
        WR_EN   : in std_ulogic;
        DIN     : in std_ulogic_vector(WIDTH-1 downto 0);

        DOUT    : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0')
    );
end SINGLE_PORT_RAM;

architecture Behavioral of SINGLE_PORT_RAM is
    
    type ram_type is
        array (0 to DEPTH-1) of
        std_ulogic_vector(WIDTH-1 downto 0);
    
    signal ram  : ram_type;
    
begin
    
    ram_ctrl_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            
            DOUT    <= ram(int(ADDR));
            
            if WR_EN='1' then
                ram(int(ADDR))   <= DIN;
                if WRITE_FIRST then
                    DOUT    <= DIN;
                end if;
            end if;
            
        end if;
    end process;

end Behavioral;

