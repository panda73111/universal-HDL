
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity DELAY_QUEUE is
    generic (
        CYCLES  : natural := 10;
        WIDTH   : natural := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        DIN : in std_ulogic_vector(WIDTH-1 downto 0);
        EN  : in std_ulogic := '1';
        
        DOUT    : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0')
    );
end DELAY_QUEUE;

architecture Behavioral of DELAY_QUEUE is
    
    signal start        : std_ulogic := '0';
    signal cycle_count  : unsigned(log2(CYCLES) downto 0) := uns(CYCLES-2, log2(CYCLES)+1);
    signal rd_en        : std_ulogic := '0';
    signal wr_en        : std_ulogic := '0';
    
begin
    
    rd_en   <= cycle_count(cycle_count'high) and EN;
    wr_en   <= start and EN;
    
    ASYNC_FIFO_inst : entity work.ASYNC_FIFO
        generic map (
            WIDTH   => WIDTH,
            DEPTH   => 2**log2(CYCLES)
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            DIN     => DIN,
            RD_EN   => rd_en,
            WR_EN   => wr_en,
            
            DOUT    => DOUT
        );
    
    count_proc : process(CLK, RST)
    begin
        if RST='1' then
            start       <= '0';
            cycle_count <= uns(CYCLES-2, log2(CYCLES)+1);
        elsif rising_edge(CLK) then
            start   <= '1';
            if cycle_count(cycle_count'high)='0' and start='1' and EN='1' then
                cycle_count <= cycle_count-1;
            end if;
        end if;
    end process;
    
end Behavioral;

