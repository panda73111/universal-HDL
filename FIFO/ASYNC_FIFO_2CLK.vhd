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
--  reference: http://www.asic-world.com/examples/vhdl/asyn_fifo.html
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
    
    signal rd_p : std_ulogic_vector(ADDR_BITS-1 downto 0) := (others => '0');
    signal wr_p : std_ulogic_vector(ADDR_BITS-1 downto 0) := (others => '0');
    
    signal is_full, is_empty    : boolean := false;
    signal collision            : boolean := false;
    
    signal rd_p_counter_en  : std_ulogic := '0';
    signal wr_p_counter_en  : std_ulogic := '0';
    
    signal status       : std_ulogic := '0';
    signal set_status   : std_ulogic := '0';
    signal rst_status   : std_ulogic := '0';
    
    signal preset_full  : std_ulogic := '0';
    signal preset_empty : std_ulogic := '0';
    
begin

    FULL    <= '1' when is_full     else '0';
    EMPTY   <= '1' when is_empty    else '0';
    
    collision   <= rd_p=wr_p;
    
    preset_full     <= '1' when status='1' and collision else '0';
    preset_empty    <= '1' when status='0' and collision else '0';
    
    wr_p_counter_en <= '1' when WR_EN='1' and not is_full else '0';
    rd_p_counter_en <= '1' when RD_EN='1' and not is_empty else '0';
    
    rd_GRAY_CODE_COUNTER_inst : entity work.GRAY_CODE_COUNTER
        generic map (
            WIDTH   => ADDR_BITS
        )
        port map (
            CLK => RD_CLK,
            RST => RST,
            
            EN  =>  rd_p_counter_en,
            
            COUNTER => rd_p
        );
    
    wr_GRAY_CODE_COUNTER_inst : entity work.GRAY_CODE_COUNTER
        generic map (
            WIDTH   => ADDR_BITS
        )
        port map (
            CLK => WR_CLK,
            RST => RST,
            
            EN  =>  wr_p_counter_en,
            
            COUNTER => wr_p
        );
    
    push_proc : process (RST, WR_CLK)
    begin
        if RST='1' then
            WR_ACK  <= '0';
        elsif rising_edge(WR_CLK) then
            WR_ACK  <= '0';
            if WR_EN='1' and not is_full then
                ram(nat(wr_p))  <= DIN;
                WR_ACK          <= '1';
            end if;
        end if;
    end process;

    pop_proc : process (RST, RD_CLK)
    begin
        if RST='1' then
            VALID   <= '0';
        elsif rising_edge(RD_CLK) then
            VALID   <= '0';
            DOUT    <= ram(nat(rd_p));
            if RD_EN='1' and not is_empty then
                VALID   <= '1';
            end if;
        end if;
    end process;

    change_status_proc : process(rd_p, wr_p)
        variable set_status_bit0, set_status_bit1   : std_ulogic;
        variable rst_status_bit0, rst_status_bit1   : std_ulogic;
    begin
        set_status_bit0 := wr_p(ADDR_BITS-2) xnor rd_p(ADDR_BITS-1);
        set_status_bit1 := wr_p(ADDR_BITS-1) xor rd_p(ADDR_BITS-2);
        set_status      <= set_status_bit0 and set_status_bit1;
        rst_status_bit0 := wr_p(ADDR_BITS-2) xor rd_p(ADDR_BITS-1);
        rst_status_bit1 := wr_p(ADDR_BITS-1) xnor rd_p(ADDR_BITS-2);
        rst_status      <= rst_status_bit0 and rst_status_bit1;
    end process;
    
    status_proc : process(RST, set_status, rst_status)
    begin
        if RST='1' or rst_status='1' then
            status  <= '0';
        elsif set_status='1' then
            status  <= '1';
        end if;
    end process;
    
    full_detect_proc : process(preset_full, WR_CLK)
    begin
        if preset_full='1' then
            is_full <= true;
        elsif rising_edge(WR_CLK) then
            is_full <= false;
        end if;
    end process;
    
    empty_detect_proc : process(preset_full, RD_CLK)
    begin
        if preset_empty='1' then
            is_empty    <= true;
        elsif rising_edge(RD_CLK) then
            is_empty    <= false;
        end if;
    end process;
    
end rtl;
