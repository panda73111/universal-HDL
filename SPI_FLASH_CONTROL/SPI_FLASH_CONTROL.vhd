----------------------------------------------------------------------------------
-- Engineer: Sebastian Hther
-- 
-- Create Date:    10:28:41 09/13/2014 
-- Module Name:    SPI_FLASH_CONTROL - rtl 
-- Project Name:   SPI_FLASH_CONTROL
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--  Only powers of 2 are supported for PAGE_SIZE and SECTOR_SIZE
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.help_funcs.all;

entity SPI_FLASH_CONTROL is
    generic (
        CLK_IN_PERIOD           : real;
        CLK_OUT_MULT            : positive range 2 to 256;
        CLK_OUT_DIV             : positive range 1 to 256;
        STATUS_POLL_INTERVAL    : real := 100_000.0; -- 100 us
        DESELECT_HOLD_TIME      : real := 200.0;
        BUFFER_SIZE             : positive := 1024;
        BUFFER_AFULL_COUNT      : positive := 786;
        PAGE_SIZE               : positive := 2**8; -- 256 Bytes
        SECTOR_SIZE             : positive := 2**16 -- 64 KBytes
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        ADDR    : in std_ulogic_vector(23 downto 0);
        DIN     : in std_ulogic_vector(7 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        END_WR  : in std_ulogic;
        MISO    : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(7 downto 0) := x"00";
        VALID   : out std_ulogic := '0';
        WR_ACK  : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0';
        FULL    : out std_ulogic := '0';
        AFULL   : out std_ulogic := '0';
        MOSI    : out std_ulogic := '0';
        C       : out std_ulogic := '1';
        SN      : out std_ulogic := '1'
    );
end SPI_FLASH_CONTROL;

architecture rtl of SPI_FLASH_CONTROL is
    
    subtype cmd_type is std_ulogic_vector(7 downto 0);
    
    constant CMD_WRITE_ENABLE           : cmd_type := x"06";
    constant CMD_SECTOR_ERASE           : cmd_type := x"D8";
    constant CMD_READ_DATA_BYTES        : cmd_type := x"03";
    constant CMD_PAGE_PROGRAM           : cmd_type := x"02";
    constant CMD_READ_STATUS_REGISTER   : cmd_type := x"05";
    
    constant SECTOR_MASK    : std_ulogic_vector(23 downto 0) := stdulv(SECTOR_SIZE-1, 24);
    
    constant CLK_OUT_PERIOD         : real := CLK_IN_PERIOD * real(CLK_OUT_DIV) / real(CLK_OUT_MULT);
    constant STATUS_POLL_TICKS      : natural := maximum(int(ceil(STATUS_POLL_INTERVAL / CLK_OUT_PERIOD)), 2);
    constant DESELECT_HOLD_TICKS    : natural := maximum(int(ceil(DESELECT_HOLD_TIME / CLK_OUT_PERIOD)), 2);
    
    type state_type is (
        WAIT_FOR_INPUT,
        
        -- Read
        SEND_READ_COMMAND,
        SEND_READ_ADDR,
        WAIT_FOR_DATA_1,
        WAIT_FOR_DATA_2,
        READ_DATA,
        READ_DESELECT,
        
        -- Erase
        ERASE_SEND_WRITE_ENABLE_COMMAND,
        ERASE_END_WRITE_ENABLE_COMMAND,
        SEND_SECTOR_ERASE_COMMAND,
        SEND_ERASE_ADDRESS,
        END_SECTOR_ERASE_COMMAND,
        WAIT_FOR_SECTOR_ERASE,
        ERASE_SEND_READ_STATUS_REGISTER_COMMAND,
        ERASE_WAIT_FOR_DATA,
        ERASE_READ_STATUS_REGISTER,
        ERASE_CHECK_WIP_BIT,
        ERASE_HOLD_DESELECT,
        
        -- Program
        PROGRAM_SEND_WRITE_ENABLE_COMMAND,
        PROGRAM_END_WRITE_ENABLE_COMMAND,
        SEND_PROGRAM_COMMAND,
        SEND_PROGRAM_ADDR,
        SEND_DATA,
        END_PROGRAM_COMMAND,
        WAIT_FOR_PROGRAM,
        PROGRAM_SEND_READ_STATUS_REGISTER_COMMAND,
        PROGRAM_WAIT_FOR_DATA,
        PROGRAM_READ_STATUS_REGISTER,
        PROGRAM_CHECK_WIP_BIT,
        PROGRAM_HOLD_DESELECT,
        PROGRAM_EVAL_NEXT_STATE
    );
    
    type reg_type is record
        state               : state_type;
        mosi                : std_ulogic;
        sn                  : std_ulogic;
        valid               : std_ulogic;
        wr_ack              : std_ulogic;
        data_bit_index      : unsigned(2 downto 0);
        addr_bit_index      : unsigned(5 downto 0);
        data                : std_ulogic_vector(7 downto 0);
        poll_tick_count     : unsigned(log2(STATUS_POLL_TICKS) downto 0);
        desel_tick_count    : unsigned(log2(DESELECT_HOLD_TICKS) downto 0);
        fifo_rd_en          : std_ulogic;
        cur_addr            : std_ulogic_vector(23 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state               => WAIT_FOR_INPUT,
        mosi                => '0',
        sn                  => '1',
        valid               => '0',
        wr_ack              => '0',
        data_bit_index      => uns(7, 3),
        addr_bit_index      => uns(23, 6),
        data                => x"00",
        poll_tick_count     => uns(STATUS_POLL_TICKS-2, log2(STATUS_POLL_TICKS)+1),
        desel_tick_count    => uns(DESELECT_HOLD_TICKS-2, log2(DESELECT_HOLD_TICKS)+1),
        fifo_rd_en          => '0',
        cur_addr            => (others => '0')
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal clk_out, clk_out_180 : std_ulogic := '0';
    signal clk_out_locked       : std_ulogic := '0';
    signal oddr2_rst            : std_ulogic := '0';
    signal oddr2_q              : std_ulogic := '0';
    
    signal rd_en_sync   : std_ulogic := '0';
    signal sn_sync      : std_ulogic := '0';
    signal busy_unsync  : std_ulogic := '0';
    
    signal fifo_din     : std_ulogic_vector(7 downto 0) := x"00";
    signal fifo_rd_en   : std_ulogic := '0';
    signal fifo_wr_en   : std_ulogic := '0';
    signal fifo_dout    : std_ulogic_vector(7 downto 0) := x"00";
    signal fifo_empty   : std_ulogic := '0';
    signal fifo_full    : std_ulogic := '0';
    signal fifo_count   : std_ulogic_vector(log2(BUFFER_SIZE) downto 0) := (others => '0');
    
    signal next_addr            : std_ulogic_vector(23 downto 0) := x"000000";
    
    signal page_transition      : boolean := false;
    signal sector_transition    : boolean := false;
    
    signal time_to_poll     : boolean := false;
    signal time_to_reselect : boolean := false;
    
begin
    
    SN      <= sn_sync;
    
    busy_unsync <= '1' when cur_reg.state/=WAIT_FOR_INPUT or clk_out_locked='0' else '0';
    oddr2_rst   <= sn_sync;
    
    FULL    <= fifo_full;
    AFULL   <= '1' when fifo_count >= BUFFER_AFULL_COUNT else '0';
    
    fifo_din    <= DIN;
    fifo_rd_en  <= cur_reg.fifo_rd_en;
    fifo_wr_en  <= WR_EN;
    
    next_addr       <= cur_reg.cur_addr+1;
    
    page_transition <=
        cur_reg.cur_addr(log2(PAGE_SIZE)) /=
        next_addr(log2(PAGE_SIZE));
    
    sector_transition   <=
        cur_reg.cur_addr(log2(SECTOR_SIZE)) /=
        next_addr(log2(SECTOR_SIZE));
    
    time_to_poll        <= cur_reg.poll_tick_count(cur_reg.poll_tick_count'high)='1';
    time_to_reselect    <= cur_reg.desel_tick_count(cur_reg.desel_tick_count'high)='1';
    
    c_ODDR2_inst : ODDR2
        generic map (
            INIT    => '0'
        )
        port map (
            S   => '0',
            R   => oddr2_rst,
            D0  => '1',
            D1  => '0',
            C0  => clk_out,
            C1  => clk_out_180,
            CE  => '1',
            Q   => C
        );
    
    -- apply data on the falling edge of C
    mosi_SIGNAL_SYNC_inst   : entity work.SIGNAL_SYNC port map (clk_out_180, cur_reg.mosi, MOSI);
    sn_SIGNAL_SYNC_inst     : entity work.SIGNAL_SYNC generic map ('1') port map (clk_out_180, cur_reg.sn, sn_sync);
    
    rd_en_SIGNAL_SYNC_inst  : entity work.SIGNAL_SYNC port map (clk_out, RD_EN, rd_en_sync);
    
    valid_FLAG_SYNC_inst    : entity work.FLAG_SYNC port map (clk_out, CLK, cur_reg.valid, VALID);
    wr_ack_FLAG_SYNC_inst   : entity work.FLAG_SYNC port map (clk_out, CLK, cur_reg.wr_ack, WR_ACK);
    busy_SIGNAL_SYNC_inst   : entity work.SIGNAL_SYNC port map (CLK, busy_unsync, BUSY);
    dout_BUS_SYNC_inst      : entity work.BUS_SYNC generic map (8, 3) port map (CLK, cur_reg.data, DOUT);
    
    CLK_MAN_inst : entity work.CLK_MAN
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            MULTIPLIER      => CLK_OUT_MULT,
            DIVISOR         => CLK_OUT_DIV
        )
        port map (
            CLK_IN  => CLK,
            RST     => RST,
            
            CLK_OUT     => clk_out,
            CLK_OUT_180 => clk_out_180,
            LOCKED      => clk_out_locked
        );
    
    write_buffer_inst : entity work.ASYNC_FIFO_2CLK
        generic map (
            DEPTH   => BUFFER_SIZE
        )
        port map (
            RD_CLK  => clk_out,
            WR_CLK  => CLK,
            RST     => RST,
            
            DIN     => fifo_din,
            RD_EN   => fifo_rd_en,
            WR_EN   => fifo_wr_en,
            
            DOUT    => fifo_dout,
            FULL    => fifo_full,
            EMPTY   => fifo_empty,
            COUNT   => fifo_count
        );
    
    stm_proc : process(
            RST, cur_reg, ADDR, MISO, END_WR, fifo_empty, rd_en_sync, page_transition,
            sector_transition, time_to_reselect, time_to_poll)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cur_reg;
        
        r.valid         := '0';
        r.wr_ack        := '0';
        r.fifo_rd_en    := '0';
        
        case cr.state is
            
            when WAIT_FOR_INPUT =>
                r.sn                := '1';
                r.addr_bit_index    := uns(23, 6);
                r.data_bit_index    := uns(7, 3);
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                r.cur_addr          := ADDR;
                if rd_en_sync='1' then
                    r.state := SEND_READ_COMMAND;
                end if;
                if fifo_empty='0' then
                    r.state := ERASE_SEND_WRITE_ENABLE_COMMAND;
                end if;
            
            -- Read
            
            when SEND_READ_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMD_READ_DATA_BYTES(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_READ_ADDR;
                end if;
            
            when SEND_READ_ADDR =>
                r.mosi              := cr.cur_addr(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=0 then
                    r.state := WAIT_FOR_DATA_1;
                end if;
            
            when WAIT_FOR_DATA_1 =>
                r.state := WAIT_FOR_DATA_2;
            
            when WAIT_FOR_DATA_2 =>
                r.state := READ_DATA;
            
            when READ_DATA =>
                r.data(int(cr.data_bit_index))  := MISO;
                r.data_bit_index                := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.valid := '1';
                end if;
                if rd_en_sync='0' then
                    r.sn    := '1';
                    r.state := READ_DESELECT;
                end if;
            
            when READ_DESELECT =>
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := WAIT_FOR_INPUT;
                end if;
            
            -- Erase
            
            when ERASE_SEND_WRITE_ENABLE_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMD_WRITE_ENABLE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := ERASE_END_WRITE_ENABLE_COMMAND;
                end if;
            
            when ERASE_END_WRITE_ENABLE_COMMAND =>
                r.sn                := '1';
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := SEND_SECTOR_ERASE_COMMAND;
                end if;
            
            when SEND_SECTOR_ERASE_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMD_SECTOR_ERASE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                if cr.data_bit_index=0 then
                    r.state := SEND_ERASE_ADDRESS;
                end if;
            
            when SEND_ERASE_ADDRESS =>
                r.mosi              := cr.cur_addr(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=0 then
                    r.state := END_SECTOR_ERASE_COMMAND;
                end if;
            
            when END_SECTOR_ERASE_COMMAND =>
                r.sn                := '1';
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := WAIT_FOR_SECTOR_ERASE;
                end if;
            
            when WAIT_FOR_SECTOR_ERASE =>
                r.poll_tick_count   := cr.poll_tick_count-1;
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                if time_to_poll then
                    r.state := ERASE_SEND_READ_STATUS_REGISTER_COMMAND;
                end if;
            
            when ERASE_SEND_READ_STATUS_REGISTER_COMMAND =>
                r.poll_tick_count   := reg_type_def.poll_tick_count;
                r.sn                := '0';
                r.mosi              := CMD_READ_STATUS_REGISTER(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := ERASE_WAIT_FOR_DATA;
                end if;
            
            when ERASE_WAIT_FOR_DATA =>
                r.state := ERASE_READ_STATUS_REGISTER;
            
            when ERASE_READ_STATUS_REGISTER =>
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.sn    := '1';
                    r.state := ERASE_CHECK_WIP_BIT;
                end if;
            
            when ERASE_CHECK_WIP_BIT =>
                -- WIP = 'write in progress' bit
                r.state := WAIT_FOR_SECTOR_ERASE;
                if MISO='0' then
                    r.state := ERASE_HOLD_DESELECT;
                end if;
            
            when ERASE_HOLD_DESELECT =>
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := PROGRAM_SEND_WRITE_ENABLE_COMMAND;
                end if;
            
            -- Program
            
            when PROGRAM_SEND_WRITE_ENABLE_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMD_WRITE_ENABLE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                if cr.data_bit_index=0 then
                    r.state := PROGRAM_END_WRITE_ENABLE_COMMAND;
                end if;
            
            when PROGRAM_END_WRITE_ENABLE_COMMAND =>
                r.sn                := '1';
                r.addr_bit_index    := uns(23, 6);
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := SEND_PROGRAM_COMMAND;
                end if;
            
            when SEND_PROGRAM_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMD_PAGE_PROGRAM(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                if cr.data_bit_index=0 then
                    r.state := SEND_PROGRAM_ADDR;
                end if;
            
            when SEND_PROGRAM_ADDR =>
                r.mosi              := cr.cur_addr(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=1 then
                    r.fifo_rd_en    := '1';
                elsif cr.addr_bit_index=0 then
                    r.state         := SEND_DATA;
                end if;
            
            when SEND_DATA =>
                r.mosi              := fifo_dout(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=1 then
                    if
                        not page_transition and
                        not sector_transition
                    then
                        r.fifo_rd_en    := '1';
                    end if;
                elsif cr.data_bit_index=0 then
                    r.wr_ack    := '1';
                    r.cur_addr  := cr.cur_addr+1;
                    if
                        fifo_empty='1' or
                        page_transition or
                        sector_transition
                    then
                        r.state := END_PROGRAM_COMMAND;
                    end if;
                end if;
            
            when END_PROGRAM_COMMAND =>
                r.sn                := '1';
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := WAIT_FOR_PROGRAM;
                end if;
            
            when WAIT_FOR_PROGRAM =>
                r.poll_tick_count   := cr.poll_tick_count-1;
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                if time_to_poll then
                    r.state := PROGRAM_SEND_READ_STATUS_REGISTER_COMMAND;
                end if;
            
            when PROGRAM_SEND_READ_STATUS_REGISTER_COMMAND =>
                r.poll_tick_count   := reg_type_def.poll_tick_count;
                r.sn                := '0';
                r.mosi              := CMD_READ_STATUS_REGISTER(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := PROGRAM_WAIT_FOR_DATA;
                end if;
            
            when PROGRAM_WAIT_FOR_DATA =>
                r.state := PROGRAM_READ_STATUS_REGISTER;
            
            when PROGRAM_READ_STATUS_REGISTER =>
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.sn    := '1';
                    r.state := PROGRAM_CHECK_WIP_BIT;
                end if;
            
            when PROGRAM_CHECK_WIP_BIT =>
                -- WIP (write in progress) bit
                r.state := WAIT_FOR_PROGRAM;
                if MISO='0' then
                    r.state := PROGRAM_HOLD_DESELECT;
                end if;
            
            when PROGRAM_HOLD_DESELECT =>
                r.desel_tick_count  := cr.desel_tick_count-1;
                if time_to_reselect then
                    r.state := PROGRAM_EVAL_NEXT_STATE;
                end if;
            
            when PROGRAM_EVAL_NEXT_STATE =>
                r.desel_tick_count  := reg_type_def.desel_tick_count;
                r.addr_bit_index    := uns(23, 6);
                r.data_bit_index    := uns(7, 3);
                if fifo_empty='0' then
                    r.state := PROGRAM_SEND_WRITE_ENABLE_COMMAND;
                    if sector_transition then
                        r.state := ERASE_SEND_WRITE_ENABLE_COMMAND;
                    end if;
                elsif END_WR='1' then
                    r.state := WAIT_FOR_INPUT;
                end if;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        
        next_reg    <= r;
    end process;
    
    stm_sync_proc : process(RST, clk_out)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(clk_out) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

