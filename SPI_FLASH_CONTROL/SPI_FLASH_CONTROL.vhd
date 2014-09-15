----------------------------------------------------------------------------------
-- Engineer: Sebastian Hüther
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
        SKIP_SEKTOR_REWRITE : boolean := false;
        STATUS_POLL_CYCLES  : natural := 50_000 -- 1 ms at 50 MHz
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        ADDR    : in std_ulogic_vector(23 downto 0);
        DIN     : in std_ulogic_vector(7 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        BULK    : in std_ulogic;
        DQ1     : in std_ulogic;
        
        DOUT    : out std_ulogic_vector(7 downto 0) := x"00";
        VALID   : out std_ulogic := '0';
        WR_ACK  : out std_ulogic := '0';
        BUSY    : out std_ulogic := '0';
        DQ0     : out std_ulogic := '0';
        C       : out std_ulogic := '0';
        SN      : out std_ulogic := '1'
    );
end SPI_FLASH_CONTROL;

architecture rtl of SPI_FLASH_CONTROL is
    
    subtype cmd_type is std_ulogic_vector(7 downto 0);
    
    constant CMDS_WRITE_ENABLE      : cmd_type := x"06";
    constant CMDS_SECTOR_ERASE      : cmd_type := x"D8";
    constant CMDS_READ_DATA_BYTES   : cmd_type := x"03";
    
    type state_type is (
        WAIT_FOR_INPUT,
        
        -- Read
        SEND_READ_COMMAND,
        SEND_READ_ADDR,
        READ_DATA,
        
        -- Erase
        ERASE_SEND_WRITE_ENABLE_COMMAND,
        ERASE_END_WRITE_ENABLE_COMMAND,
        SEND_SECTOR_ERASE_COMMAND,
        
        READ_WRITE_STATUS_REGISTER,
        
        -- Program
        PROGRAM_SEND_WRITE_ENABLE_COMMAND,
        PROGRAM_END_WRITE_ENABLE_COMMAND,
        SEND_PROGRAM_COMMAND
    );
    
    type reg_type is record
        state           : state_type;
        dq0             : std_ulogic;
        sn              : std_ulogic;
        valid           : std_ulogic;
        wr_ack          : std_ulogic;
        data_bit_index  : unsigned(2 downto 0);
        addr_bit_index  : unsigned(5 downto 0);
        dout            : std_ulogic_vector(7 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state           => WAIT_FOR_INPUT,
        dq0             => '0',
        sn              => '1',
        valid           => '0',
        wr_ack          => '0',
        data_bit_index  => uns(7, 3),
        addr_bit_index  => uns(24, 6),
        dout            => x"00"
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal clk_out, clk_out_180 : std_ulogic := '0';
    signal clk_out_locked       : std_ulogic := '0';
    
begin
    
    DOUT    <= cur_reg.dout;
    VALID   <= cur_reg.valid;
    WR_ACK  <= cur_reg.wr_ack;
    BUSY    <= '1' when cur_reg.state/=WAIT_FOR_INPUT or clk_out_locked='0' else '0';
    
    DQ0 <= cur_reg.dq0;
    C   <= clk_out_180;
    SN  <= cur_reg.sn;
    
    CLK_MAN_inst : entity work.CLK_MAN
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            MULTIPLIER      => CLK_OUT_MULT,
            DIVIDER         => CLK_OUT_DIV
        )
        port map (
            CLK => CLK,
            
            CLK_OUT     => clk_out,
            CLK_OUT_180 => clk_out_180,
            LOCKED      => clk_out_locked
        );
    
    stm_proc : process(RST, cur_reg, ADDR, DIN, RD_EN, WR_EN, DQ1, BULK)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cur_reg;
        
        r.valid     := '0';
        r.wr_ack    := '0';
        
        case cr.state is
            
            when WAIT_FOR_INPUT =>
                r.sn                := '1';
                r.addr_bit_index    := uns(23, 6);
                if RD_EN='1' then
                    r.state := SEND_READ_COMMAND;
                end if;
                if WR_EN='1' then
                    r.state := ERASE_SEND_WRITE_ENABLE_COMMAND;
                end if;
            
            -- Read
            
            when SEND_READ_COMMAND =>
                r.sn                := '0';
                r.dq0               := CMDS_READ_DATA_BYTES(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_READ_ADDR;
                end if;
            
            when SEND_READ_ADDR =>
                r.dq0               := ADDR(int(cr.addr_bit_index));
                r.addr_bit_index    := cr.addr_bit_index-1;
                if cr.addr_bit_index=0 then
                    r.state := READ_DATA;
                end if;
            
            when READ_DATA =>
                r.dout(int(cr.data_bit_index))  := DQ1;
                r.data_bit_index                := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.valid := '1';
                    if BULK='0' then
                        r.state := WAIT_FOR_INPUT;
                    end if;
                end if;
            
            -- Erase
            
            when ERASE_SEND_WRITE_ENABLE_COMMAND =>
                r.sn                := '0';
                r.dq0               := CMDS_WRITE_ENABLE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := ERASE_END_WRITE_ENABLE_COMMAND;
                end if;
            
            when ERASE_END_WRITE_ENABLE_COMMAND =>
                r.sn    := '1';
                r.state := SEND_SECTOR_ERASE_COMMAND;
                if SKIP_ERASE then
                    r.state := SEND_PROGRAM_COMMAND;
                end if;
            
            when SEND_SECTOR_ERASE_COMMAND =>
                r.sn                := '0';
                r.dq0               := CMDS_SECTOR_ERASE(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_PROGRAM_COMMAND;
                end if;
            
            -- Program
            
            when SEND_PROGRAM_COMMAND =>
                r.sn                := '0';
                r.dq0               := CMDS_READ_DATA_BYTES(int(cr.data_bit_index));
                r.data_bit_index    := cr.data_bit_index-1;
                if cr.data_bit_index=0 then
                    r.state := SEND_READ_ADDR;
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

