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
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity SPI_FLASH_CONTROL is
    generic (
        CLK_IN_PERIOD       : real;
        CLK_OUT_MULT        : natural range 2 to 256;
        CLK_OUT_DIV         : natural range 1 to 256;
        STATUS_POLL_INTERV  : natural := 50_000; -- 1 ms at 50 MHz
        BUF_SIZE            : natural := 1024
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        ADDR    : in std_ulogic_vector(23 downto 0);
        DIN     : in std_ulogic_vector(7 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        MISO    : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(7 downto 0) := x"00";
        VALID   : out std_ulogic := '0';
        WR_ACK  : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0';
        FULL    : out std_ulogic := '0';
        MOSI    : out std_ulogic := '0';
        C       : out std_ulogic := '0';
        SN      : out std_ulogic := '1'
    );
end SPI_FLASH_CONTROL;

architecture rtl of SPI_FLASH_CONTROL is
    
    subtype cmd_type is std_ulogic_vector(7 downto 0);
    
    constant CMDS_WRITE_ENABLE          : cmd_type := x"06";
    constant CMDS_SECTOR_ERASE          : cmd_type := x"D8";
    constant CMDS_READ_DATA_BYTES       : cmd_type := x"0B"; -- read at higher speed
    constant CMDS_READ_STATUS_REGISTER  : cmd_type := x"05";
    
    type state_type is (
        WAIT_FOR_INPUT,
        
        -- Read
        SEND_READ_COMMAND,
        SEND_READ_ADDR,
        SEND_DUMMY_BYTE,
        READ_DATA,
        
        -- Erase
        ERASE_SEND_WRITE_ENABLE_COMMAND,
        ERASE_END_WRITE_ENABLE_COMMAND,
        SEND_SECTOR_ERASE_COMMAND,
        SEND_ERASE_ADDRESS,
        END_SECTOR_ERASE_COMMAND,
        WAIT_FOR_SECTOR_ERASE,
        ERASE_SEND_READ_STATUS_REGISTER_COMMAND,
        ERASE_READ_STATUS_REGISTER,
        
        -- Program
        PROGRAM_SEND_WRITE_ENABLE_COMMAND,
        PROGRAM_END_WRITE_ENABLE_COMMAND,
        SEND_PROGRAM_COMMAND,
        SEND_PROGRAM_ADDR,
        SEND_DATA,
        END_PROGRAM_COMMAND,
        WAIT_FOR_PROGRAM,
        PROGRAM_SEND_READ_STATUS_REGISTER_COMMAND,
        PROGRAM_READ_STATUS_REGISTER
    );
    
    type reg_type is record
        state           : state_type;
        mosi            : std_ulogic;
        sn              : std_ulogic;
        valid           : std_ulogic;
        wr_ack          : std_ulogic;
        data_bit_index  : unsigned(2 downto 0);
        addr_bit_index  : unsigned(5 downto 0);
        data            : std_ulogic_vector(7 downto 0);
        tick_count      : natural range 0 to STATUS_POLL_INTERV;
        fifo_rd_en      : std_ulogic;
    end record;
    
    constant reg_type_def   : reg_type := (
        state           => WAIT_FOR_INPUT,
        mosi            => '0',
        sn              => '1',
        valid           => '0',
        wr_ack          => '0',
        data_bit_index  => uns(7, 3),
        addr_bit_index  => uns(23, 6),
        data            => x"00",
        tick_count      => 0,
        fifo_rd_en      => '0'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal clk_out, clk_out_180 : std_ulogic := '0';
    signal clk_out_locked       : std_ulogic := '0';
    
    signal rd_en_sync, wr_en_sync   : std_ulogic := '0';
    
    signal busy_unsync  : std_ulogic := '0';
    
    signal fifo_dout    : std_ulogic_vector(7 downto 0) := x"00";
    signal fifo_empty   : std_ulogic := '0';
    
begin
    
    DOUT    <= cur_reg.data;
    
    busy_unsync <= '1' when cur_reg.state/=WAIT_FOR_INPUT or clk_out_locked='0' else '0';
    
    MOSI    <= cur_reg.mosi;
    C       <= clk_out_180;
    SN      <= cur_reg.sn;
    
    rd_en_SIGNAL_SYNC_inst  : entity work.FLAG_SYNC port map (CLK, clk_out, RD_EN, rd_en_sync);
    wr_en_SIGNAL_SYNC_inst  : entity work.FLAG_SYNC port map (CLK, clk_out, WR_EN, wr_en_sync);
    
    valid_SIGNAL_SYNC_inst  : entity work.FLAG_SYNC port map (clk_out, CLK, cur_reg.valid, VALID);
    wr_ack_SIGNAL_SYNC_inst : entity work.FLAG_SYNC port map (clk_out, CLK, cur_reg.wr_ack, WR_ACK);
    busy_SIGNAL_SYNC_inst   : entity work.SIGNAL_SYNC port map (clk_out, CLK, busy_unsync, BUSY);
    
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
            DEPTH           => BUF_SIZE,
            COUNT_ON_READ   => false
        )
        port map (
            RD_CLK  => clk_out,
            WR_CLK  => CLK,
            RST     => RST,
            
            DIN     => DIN,
            RD_EN   => cur_reg.fifo_rd_en,
            WR_EN   => WR_EN,
            
            DOUT    => fifo_dout,
            FULL    => FULL,
            EMPTY   => fifo_empty
        );
    
    stm_proc : process(RST, cur_reg, ADDR, MISO, fifo_dout, fifo_empty, rd_en_sync, wr_en_sync)
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
                if RD_EN='1' then
                    r.state := SEND_READ_COMMAND;
                end if;
                if fifo_empty='0' then
                    r.state := ERASE_SEND_WRITE_ENABLE_COMMAND;
                end if;
            
            -- Read
            
            when SEND_READ_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMDS_READ_DATA_BYTES(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_READ_ADDR;
                end if;
            
            when SEND_READ_ADDR =>
                r.mosi              := ADDR(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=0 then
                    r.state := SEND_DUMMY_BYTE;
                end if;
            
            when SEND_DUMMY_BYTE =>
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := READ_DATA;
                end if;
            
            when READ_DATA =>
                r.data(int(cr.data_bit_index))  := MISO;
                r.data_bit_index                := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.valid := '1';
                    if RD_EN='0' then
                        r.state := WAIT_FOR_INPUT;
                    end if;
                end if;
            
            -- Erase
            
            when ERASE_SEND_WRITE_ENABLE_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMDS_WRITE_ENABLE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := ERASE_END_WRITE_ENABLE_COMMAND;
                end if;
            
            when ERASE_END_WRITE_ENABLE_COMMAND =>
                r.sn    := '1';
                r.state := SEND_SECTOR_ERASE_COMMAND;
            
            when SEND_SECTOR_ERASE_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMDS_SECTOR_ERASE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_ERASE_ADDRESS;
                end if;
            
            when SEND_ERASE_ADDRESS =>
                r.mosi              := ADDR(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=0 then
                    r.state := END_SECTOR_ERASE_COMMAND;
                end if;
            
            when END_SECTOR_ERASE_COMMAND =>
                r.sn                := '1';
                r.state             := WAIT_FOR_SECTOR_ERASE;
            
            when WAIT_FOR_SECTOR_ERASE =>
                r.tick_count    := cr.tick_count+1;
                if cr.tick_count=STATUS_POLL_INTERV-1 then
                    r.state := ERASE_SEND_READ_STATUS_REGISTER_COMMAND;
                end if;
            
            when ERASE_SEND_READ_STATUS_REGISTER_COMMAND =>
                r.tick_count        := 0;
                r.sn                := '0';
                r.mosi              := CMDS_READ_STATUS_REGISTER(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := ERASE_READ_STATUS_REGISTER;
                end if;
            
            when ERASE_READ_STATUS_REGISTER =>
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    -- WIP (write in progress) bit
                    r.state := WAIT_FOR_SECTOR_ERASE;
                    if MISO='0' then
                        r.state := PROGRAM_SEND_WRITE_ENABLE_COMMAND;
                    end if;
                end if;
            
            -- Program
            
            when PROGRAM_SEND_WRITE_ENABLE_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMDS_WRITE_ENABLE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := PROGRAM_END_WRITE_ENABLE_COMMAND;
                end if;
            
            when PROGRAM_END_WRITE_ENABLE_COMMAND =>
                r.sn                := '1';
                r.addr_bit_index    := uns(23, 6);
                r.state             := SEND_PROGRAM_COMMAND;
            
            when SEND_PROGRAM_COMMAND =>
                r.sn                := '0';
                r.mosi              := CMDS_READ_DATA_BYTES(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_PROGRAM_ADDR;
                end if;
            
            when SEND_PROGRAM_ADDR =>
                r.mosi              := ADDR(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=0 then
                    r.fifo_rd_en    := '1';
                    r.state         := SEND_DATA;
                end if;
            
            when SEND_DATA =>
                r.mosi              := fifo_dout(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                r.addr_bit_index    := uns(23, 6);
                if cr.data_bit_index=0 then
                    r.fifo_rd_en    := '1';
                    if fifo_empty='1' then
                        r.state := END_PROGRAM_COMMAND;
                    end if;
                end if;
            
            when END_PROGRAM_COMMAND =>
                r.sn    := '1';
                r.state := WAIT_FOR_PROGRAM;
            
            when WAIT_FOR_PROGRAM =>
                r.tick_count    := cr.tick_count+1;
                if cr.tick_count=STATUS_POLL_INTERV-1 then
                    r.state := PROGRAM_SEND_READ_STATUS_REGISTER_COMMAND;
                end if;
            
            when PROGRAM_SEND_READ_STATUS_REGISTER_COMMAND =>
                r.tick_count        := 0;
                r.sn                := '0';
                r.mosi              := CMDS_READ_STATUS_REGISTER(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := PROGRAM_READ_STATUS_REGISTER;
                end if;
            
            when PROGRAM_READ_STATUS_REGISTER =>
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    -- WIP (write in progress) bit
                    r.state := WAIT_FOR_PROGRAM;
                    if MISO='0' then
                        r.state := WAIT_FOR_INPUT;
                    end if;
                end if;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        next_reg    <= r;
    end process;
    
    sync_stm_proc : process(RST, clk_out)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(clk_out) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

