--
--   asynchronous FIFO
--
-- width : bus width, size of one packet
-- depth : number of packets to be able to store
-- Writing and reading in the same cycle is supported, push and pop work indipendently.
--
--
-- author: Sebastian Huether, 26.10.2012
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity asynch_fifo is
    generic (
        width : integer;
        depth : integer
    );
    port (
        clk, rstn   : in  STD_LOGIC;
        din    : in  STD_LOGIC_VECTOR (width-1 downto 0);
        dout    : out  STD_LOGIC_VECTOR (width-1 downto 0);
        wr_en, rd_en : in STD_LOGIC;
        full, empty  : out STD_LOGIC;
        almost_full  : out STD_LOGIC; -- space for 1 packet left
        almost_empty : out STD_LOGIC; -- 1 packet left
        wr_ack   : out STD_LOGIC; -- packet was pushed last cycle
        valid    : out STD_LOGIC; -- dout has valid packet
        packet_count : out STD_LOGIC_VECTOR (23 downto 0)   --sd beschraenkung add
    ); 
end asynch_fifo;

architecture rtl of asynch_fifo is
    type ram_type is array(0 to depth-1) of std_logic_vector(width-1 downto 0);
    signal ram    : ram_type := (others => (others => '0'));
    signal in_pointer  : integer := 0;
    signal out_pointer : integer := 0;
    signal pack_count  : integer := 0;
    signal was_written : boolean := false;
    signal was_read  : boolean := false;

    -- pragma translate_off
    signal used_range  : integer := 0; -- for debugging, keeps the highest number of buffered packets
    signal missing_range : integer := 0; -- for debugging, counts write attempts when already full
    -- pragma translate_on
begin

    full            <= '1' when pack_count=depth  else '0';
    empty           <= '1' when pack_count=0   else '0';
    almost_full     <= '1' when pack_count>=depth-1 else '0';
    almost_empty    <= '1' when pack_count<=1   else '0';
    wr_ack          <= '1' when was_written    else '0';
    valid           <= '1' when was_read     else '0';
    packet_count    <= std_logic_vector(to_unsigned(pack_count, packet_count'length));

    push : process (rstn, clk)
    begin
        if rstn='0' then
            ram   <= (others => (others => '0'));
            in_pointer <= 0;
            was_written <= false;
        elsif rising_edge(clk) then
            was_written <= false;
            if wr_en='1' and (rd_en='1' or pack_count/=depth) then
                ram(in_pointer) <= din;
                was_written   <= true;
                if in_pointer=depth-1 then
                    in_pointer <= 0;
                else
                    in_pointer <= in_pointer+1;
                end if;
            end if;
        end if;
    end process;

    pop : process (rstn, clk)
    begin
        if rstn='0' then
            out_pointer <= 0;
            was_read  <= false;
            dout   <= (others => '0');
        elsif rising_edge(clk) then
            was_read <= false;
            if rd_en='1' and (wr_en='1' or pack_count/=0) then
                dout  <= ram(out_pointer);
                was_read <= true;
                if out_pointer=depth-1 then
                    out_pointer <= 0;
                else
                    out_pointer <= out_pointer+1;
                end if;
            end if; 
        end if;
    end process;

    count : process (rstn, clk)
    begin
        if rstn='0' then
            pack_count <= 0;
            -- pragma translate_off
            used_range  <= 0;
            missing_range <= 0;
            -- pragma translate_on
        elsif rising_edge(clk) then
            if wr_en='1' and rd_en='0' then
                if pack_count/=depth then
                    pack_count <= pack_count+1;
                end if;
            elsif wr_en='0' and rd_en='1' then
                if pack_count/=0 then
                    pack_count <= pack_count-1;
                end if;
            end if;

            -- pragma translate_off
            -- debugging
            if wr_en='1' and pack_count=depth then
                missing_range <= missing_range+1;
            end if;
            if pack_count>used_range then
                used_range <= pack_count;
            end if;
            -- pragma translate_on
        end if;
    end process;

end rtl;

