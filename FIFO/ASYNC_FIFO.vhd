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
use work.help_funcs.all;

entity ASYNC_FIFO is
    generic (
        -- default: 1 Kilobyte in bytes
        WIDTH   : natural := 8;
        DEPTH   : natural := 1024
    );
    port (
        CLK     : in std_ulogic;
        RST     : in std_ulogic;
        
        DIN     : in std_ulogic_vector(WIDTH-1 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        
        DOUT            : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
        FULL            : out std_ulogic := '0';
        EMPTY           : out std_ulogic := '0';
        ALMOST_FULL     : out std_ulogic := '0'; -- space for one packet left
        ALMOST_EMPTY    : out std_ulogic := '0'; -- one packet left
        WR_ACK          : out std_ulogic := '0'; -- write was successful
        RD_ACK          : out std_ulogic := '0'; -- read was successful
        COUNT           : out std_ulogic_vector (log2(DEPTH) downto 0) := (others => '0')
    ); 
end ASYNC_FIFO;

architecture rtl of ASYNC_FIFO is
    type ram_type is array(0 to DEPTH-1) of std_ulogic_vector(WIDTH-1 downto 0);
    signal ram      : ram_type := (others => (others => '0'));
    signal rd_p     : natural range 0 to DEPTH-1 := 0;
    signal wr_p     : natural range 0 to DEPTH-1 := 0;
    signal cnt_u    : natural range 0 to DEPTH := 0;

    -- pragma translate_off
    signal used_cnt     : natural := 0; -- for debugging, keeps the highest number of buffered packets
    signal missing_cnt  : natural := 0; -- for debugging, counts write attempts when already full
    -- pragma translate_on
begin

    FULL            <= '1' when cnt_u=DEPTH                       else '0';
    EMPTY           <= '1' when cnt_u=0                           else '0';
    ALMOST_FULL     <= '1' when cnt_u=DEPTH-1 or cnt_u=DEPTH      else '0';
    ALMOST_EMPTY    <= '1' when cnt_u=1       or cnt_u=0          else '0';
    COUNT           <= stdulv(cnt_u, COUNT'length);

    push_proc : process (RST, CLK)
    begin
        if RST='1' then
            wr_p    <= 0;
            WR_ACK  <= '0';
        elsif rising_edge(CLK) then
            WR_ACK  <= '0';
            if WR_EN='1' and cnt_u/=DEPTH then
                ram(wr_p)   <= DIN;
                WR_ACK      <= '1';
                wr_p        <= (wr_p+1) mod DEPTH;
            end if;
        end if;
    end process;

    pop_proc : process (RST, CLK)
    begin
        if RST='1' then
            rd_p    <= 0;
            RD_ACK  <= '0';
        elsif rising_edge(CLK) then
            RD_ACK  <= '0';
            if RD_EN='1' and cnt_u/=0 then
                DOUT    <= ram(rd_p);
                RD_ACK  <= '1';
                rd_p    <= (rd_p+1) mod DEPTH;
            end if;
        end if;
    end process;

    count_proc : process (RST, CLK)
    begin
        if RST='1' then
            cnt_u       <= 0;
            -- pragma translate_off
            used_cnt    <= 0;
            missing_cnt <= 0;
            -- pragma translate_on
        elsif rising_edge(CLK) then
            if WR_EN='1' and RD_EN='0' and cnt_u/=DEPTH then
                cnt_u   <= cnt_u+1;
            elsif RD_EN='1' and WR_EN='0' and cnt_u/=0 then
                cnt_u   <= cnt_u-1;
            end if;

            -- pragma translate_off
            -- debugging
            if WR_EN='1' and RD_EN='0' and cnt_u=DEPTH then
                missing_cnt <= missing_cnt+1;
            end if;
            if cnt_u>used_cnt then
                used_cnt    <= cnt_u;
            end if;
            -- pragma translate_on
        end if;
    end process;

end rtl;

