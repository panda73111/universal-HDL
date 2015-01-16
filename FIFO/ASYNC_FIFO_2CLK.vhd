----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    14:18:23 09/16/2014 
-- Module Name:    ASYNC_FIFO_2CLK - rtl 
-- Project Name:   ASYNC_FIFO_2CLK
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--  reference: ftp://ftp.sigmet.com/outgoing/custom/vaisala/ProgrammingDocs/Verilog/CummingsSNUG2002SJ_FIFO1.pdf
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity ASYNC_FIFO_2CLK is
    generic (
        -- default: 1 Kilobyte in bytes
        WIDTH   : positive := 8;
        DEPTH   : positive := 1024
    );
    port (
        RD_CLK  : in std_ulogic;
        WR_CLK  : in std_ulogic;
        RST     : in std_ulogic;
        
        DIN     : in std_ulogic_vector(WIDTH-1 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(WIDTH-1 downto 0) := (others => '0');
        FULL    : out std_ulogic := '0';
        EMPTY   : out std_ulogic := '0';
        WR_ACK  : out std_ulogic := '0'; -- write was successful
        VALID   : out std_ulogic := '0'  -- read was successful
    ); 
end ASYNC_FIFO_2CLK;

architecture rtl of ASYNC_FIFO_2CLK is
    
    constant ADDR_BITS  : positive := log2(DEPTH);
    
    type ram_type is
        array(0 to DEPTH-1) of
        std_ulogic_vector(WIDTH-1 downto 0);
    
    signal ram  : ram_type;
    
    signal rd_p, rd_p_wr_sync   : std_ulogic_vector(ADDR_BITS downto 0) := (others => '0');
    signal wr_p, wr_p_rd_sync   : std_ulogic_vector(ADDR_BITS downto 0) := (others => '0');
    
    signal rd_p_bin : std_ulogic_vector(ADDR_BITS downto 0) := (others => '0');
    signal wr_p_bin : std_ulogic_vector(ADDR_BITS downto 0) := (others => '0');
    
    signal rd_p_next, rd_p_bin_next : std_ulogic_vector(ADDR_BITS downto 0) := (others => '0');
    signal wr_p_next, wr_p_bin_next : std_ulogic_vector(ADDR_BITS downto 0) := (others => '0');
    
    signal rd_addr  : std_ulogic_vector(ADDR_BITS-1 downto 0) := (others => '0');
    signal wr_addr  : std_ulogic_vector(ADDR_BITS-1 downto 0) := (others => '0'); 
    
    signal is_full, is_full_next    : std_ulogic := '0';
    signal is_empty, is_empty_next  : std_ulogic := '1';
    
    signal rd_p_inc : std_ulogic := '0';
    signal wr_p_inc : std_ulogic := '0';
    
begin
    
    FULL    <= is_full;
    EMPTY   <= is_empty;
    
    rd_p_inc    <= RD_EN and not is_empty;
    wr_p_inc    <= WR_EN and not is_full;
    
    rd_addr <= rd_p_bin(ADDR_BITS-1 downto 0);
    wr_addr <= wr_p_bin(ADDR_BITS-1 downto 0);
    
    rd_p_bin_next   <= rd_p_bin + (rd_p_inc and not is_empty);
    wr_p_bin_next   <= wr_p_bin + (wr_p_inc and not is_full);
    
    -- gray code conversion
    rd_p_next   <=  rd_p_bin_next(ADDR_BITS) &
                    (rd_p_bin_next(ADDR_BITS downto 1) xor rd_p_bin_next(ADDR_BITS-1 downto 0));
    wr_p_next   <=  wr_p_bin_next(ADDR_BITS) &
                    (wr_p_bin_next(ADDR_BITS downto 1) xor wr_p_bin_next(ADDR_BITS-1 downto 0));
    
    is_full_next    <=  '1' when wr_p_next=
                            (not rd_p_wr_sync(ADDR_BITS downto ADDR_BITS-1) &
                            rd_p_wr_sync(ADDR_BITS-2 downto 0))
                        else '0';
    
    is_empty_next   <= '1' when rd_p_next=wr_p_rd_sync else '0';
    
    rd_p_wr_sync_BUS_SYNC_inst : entity work.BUS_SYNC
        generic map (ADDR_BITS+1) port map (WR_CLK, rd_p, rd_p_wr_sync);
    
    wr_p_rd_sync_BUS_SYNC_inst : entity work.BUS_SYNC
        generic map (ADDR_BITS+1) port map (RD_CLK, wr_p, wr_p_rd_sync);
    
    push_proc : process (RST, WR_CLK)
    begin
        if RST='1' then
            WR_ACK      <= '0';
            wr_p        <= (others => '0');
            wr_p_bin    <= (others => '0');
            is_full     <= '0';
        elsif rising_edge(WR_CLK) then
            WR_ACK  <= wr_p_inc;
            if wr_p_inc='1' then
                ram(nat(wr_addr))  <= DIN;
            end if;
            wr_p        <= wr_p_next;
            wr_p_bin    <= wr_p_bin_next;
            is_full     <= is_full_next;
        end if;
    end process;

    pop_proc : process (RST, RD_CLK)
    begin
        if RST='1' then
            VALID       <= '0';
            rd_p        <= (others => '0');
            rd_p_bin    <= (others => '0');
            is_empty    <= '1';
        elsif rising_edge(RD_CLK) then
            VALID       <= rd_p_inc;
            if rd_p_inc='1' then
                DOUT    <= ram(nat(rd_addr));
            end if;
            rd_p        <= rd_p_next;
            rd_p_bin    <= rd_p_bin_next;
            is_empty    <= is_empty_next;
        end if;
    end process;
    
end rtl;
