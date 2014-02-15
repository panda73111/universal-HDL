
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

-- Write First Mode

entity DUAL_PORT_RAM is
  generic (
    -- default: 1 Kilobyte in bytes
    ADDR_WIDTH  : integer := 10;
    DATA_WIDTH  : integer := 8
    );
  port (
    CLK : in std_logic;
    
    RD_ADDR : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    WR_EN : in std_logic;
    WR_ADDR : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    DATA_IN : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    
    DATA_OUT  : out std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0')
    );
end DUAL_PORT_RAM;

architecture Behavioral of DUAL_PORT_RAM is
  type ram_type is array (0 to 2 ** ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));
begin
  
  process(CLK)
  begin
    if rising_edge(CLK) then
      if WR_EN = '1' then
        ram(to_integer(unsigned(WR_ADDR))) <= DATA_IN;
      end if;
      
      DATA_OUT <= ram(to_integer(unsigned(RD_ADDR)));
      
      if WR_EN = '1' and WR_ADDR = RD_ADDR then
        DATA_OUT  <= DATA_IN;
      end if;
    end if;
  end process;
  
end Behavioral;

