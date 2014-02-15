
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity DELAY_QUEUE is
  generic (
    CYCLES  : integer := 10;
    DATA_WIDTH  : integer := 8
    );
  port (
    CLK : in std_logic;
    
    DATA_IN : in std_logic_vector(DATA_WIDTH-1 downto 0);
--    ENABLE  : in std_logic := '1';
    
    DATA_OUT  : out std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0')
    );
end DELAY_QUEUE;

architecture Behavioral of DELAY_QUEUE is
  type ram_type is array(0 to CYCLES-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram  : ram_type := (others => (others => '0'));
  signal wr_a : integer range 0 to CYCLES-1 := 0;
  signal rd_a : integer range 0 to CYCLES-1 := 1;
  signal data_out_buf : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  attribute ram_style : string;
  attribute ram_style of ram  : signal is "BLOCK";
begin
  
  data_out_buf  <= ram(rd_a);
  
  process(CLK)
  begin
    if rising_edge(CLK) then
    
      ram(wr_a) <= DATA_IN;
      DATA_OUT  <= data_out_buf;
      
--      rd_a  <= (rd_a + 1) mod CYCLES;
--      wr_a  <= (wr_a + 1) mod CYCLES;
      rd_a  <= rd_a + 1;
      if rd_a = CYCLES-1 then
        rd_a  <= 0;
      end if;
      wr_a  <= wr_a + 1;
      if wr_a = CYCLES-1 then
        wr_a  <= 0;
      end if;
      
    end if;
  end process;
  
end Behavioral;

