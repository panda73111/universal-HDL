----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    18:33:33 02/09/2015 
-- Module Name:    TRANSPORT_LAYER_SENDER - rtl 
-- Project Name:   TRABSPORT_LAYER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  
-- Additional Comments:
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TRANSPORT_LAYER_SENDER is
    generic (
        BUFFERED_PACKETS    : positive;
        DATA_MAGIC          : std_ulogic_vector(7 downto 0);
        ACK_MAGIC           : std_ulogic_vector(7 downto 0);
        RESEND_MAGIC        : std_ulogic_vector(7 downto 0)
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PACKET_OUT          : out std_ulogic_vector(7 downto 0) := x"00";
        PACKET_OUT_VALID    : out std_ulogic := '0';
        
        DIN         : in std_ulogic_vector(7 downto 0);
        DIN_WR_EN   : in std_ulogic;
        SEND        : in std_ulogic;
        
        PENDING_TIMEOUTS    : in std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        TIMEOUT_ACK         : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        TIMEOUT_START       : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        
        BUSY    : out std_ulogic := '0'
    );
end TRANSPORT_LAYER_SENDER;

architecture rtl of TRANSPORT_LAYER_SENDER is
    
    constant BUF_INDEX_BITS : natural := log2(BUFFERED_PACKETS);
    
    type state_type is (
        WAITING_FOR_DATA
    );
    
    type reg_type is record
        state                   : state_type;
        packet_out              : std_ulogic_vector(7 downto 0);
        packet_out_valid        : std_ulogic;
        buf_wr_addr             : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        buf_rd_addr             : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        packet_length           : unsigned(7 downto 0);
        packet_index            : unsigned(BUF_INDEX_BITS-1 downto 0);
        bytes_left_counter      : unsigned(8 downto 0);
        next_packet_number      : unsigned(7 downto 0);
        packet_records_p        : natural range 0 to BUFFERED_PACKETS;
        packet_records_wr_en    : boolean;
        timeout_ack             : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        timeout_start           : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        checksum                : std_ulogic_vector(7 downto 0);
        records_index           : unsigned(7 downto 0);
        records_din             : packet_record_type;
        records_wr_en           : std_ulogic;
        buffered_packets_count  : unsigned(BUF_INDEX_BITS-1 downto 0);
        next_free_buf_index     : unsigned(BUF_INDEX_BITS-1 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state                   => WAITING_FOR_DATA,
        packet_out              => x"00",
        packet_out_valid        => '0',
        buf_wr_addr             => (others => '0'),
        buf_rd_addr             => (others => '0'),
        packet_length           => x"00",
        packet_index            => (others => '0'),
        bytes_left_counter      => (others => '0'),
        next_packet_number      => x"00",
        packet_records_p        => 0,
        packet_records_wr_en    => false,
        timeout_ack             => (others => '0'),
        timeout_start           => (others => '0'),
        checksum                => x"00",
        records_index           => x"00",
        records_din             => packet_record_type_def,
        records_wr_en           => '0',
        buffered_packets_count  => (others => '0'),
        next_free_buf_index     => (others => '0')
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal buf_dout : std_ulogic_vector(7 downto 0) := x"00";
    
begin
    
    PACKET_OUT          <= cur_reg.packet_out;
    PACKET_OUT_VALID    <= cur_reg.packet_out_valid;
    
    TIMEOUT_ACK     <= cur_reg.timeout_ack;
    TIMEOUT_START   <= cur_reg.timeout_start;
    
    BUSY    <= '1' when cur_reg.state/=WAITING_FOR_DATA else '0';
    
    send_buf_DUAL_PORT_RAM_inst : entity work.DUAL_PORT_RAM
        generic map (
            WIDTH   => 8,
            DEPTH   => BUFFERED_PACKETS*256
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            RD_ADDR => cur_reg.buf_rd_addr,
            WR_ADDR => cur_reg.buf_wr_addr,
            WR_EN   => DIN_WR_EN,
            DIN     => DIN,
            
            DOUT    => buf_dout
        );
    
    stm_proc : process(RST, cur_reg, PENDING_TIMEOUTS, SEND, DIN_WR_EN)
        alias cr is cur_send_reg;
        variable r  : reg_type := reg_type_def;
        
        procedure send_packet_byte(
            d           : in std_ulogic_vector(7 downto 0);
            next_state  : in state_type;
            change_cond : in boolean
        ) is
        begin
            r.packet_out        := d;
            r.packet_out_valid  := '1';
            if change_cond then
                r.state     := next_state;
            end if;
        end procedure;
        
        procedure send_packet_byte(
            d           : in std_ulogic_vector(7 downto 0);
            next_state  : in state_type
        ) is
        begin
            send_packet_byte(d, next_state, true);
        end procedure;
    begin
        r   := cr;
        
        r.packet_out_valid  := '0';
        r.timeout_ack       := (others => '0');
        r.timeout_start     := (others => '0');
        
        if DIN_WR_EN='1' then
            r.packet_length := cr.packet_length+1;
        end if;
        
        case cr.state is
            
            when WAITING_FOR_DATA =>
                if PENDING_TIMEOUTS/=(pending_timeouts'range => '0') then
                    r.state := EVALUATING_PACKET_ADDR_TO_RESEND;
                end if;
                if SEND='1' then
                    r.state := SENDING_DATA_PACKET_MAGIC;
                end if;
            
            when SENDING_DATA_PACKET_MAGIC =>
                r.checksum  := uns(DATA_MAGIC);
                send_packet_byte(DATA_MAGIC, SENDING_DATA_PACKET_NUMBER);
            
            when SENDING_DATA_PACKET_NUMBER =>
                r.checksum  := cr.checksum+cr.next_packet_number;
                send_packet_byte(cr.next_packet_number, SENDING_DATA_PACKET_LENGTH);
            
            when SENDING_DATA_PACKET_LENGTH =>
                r.send_buf_rd_en        := '1';
                r.bytes_left_counter    := cr.packet_length-1;
                r.checksum              := cr.checksum+cr.packet_length;
                send_packet_byte(stdulv(cr.packet_length), SENDING_DATA_PACKET_PAYLOAD);
            
            when SENDING_DATA_PACKET_PAYLOAD =>
                r.send_buf_rd_en        := '1';
                r.bytes_left_counter    := cr.bytes_left_counter-1;
                r.checksum              := cr.checksum+send_buf_dout;
                send_packet_byte(send_buf_dout, SENDING_CHECKSUM, cr.bytes_left_counter(8)='1');
            
            when SENDING_CHECKSUM =>
                r.timeout_start(int(cr.packet_index))   := '1';
                send_packet_byte(stdulv(cr.checksum), WAITING_FOR_DATA);
            
            when EVALUATING_PACKET_ADDR_TO_RESEND =>
                for i in 0 to BUFFERED_PACKETS-1 loop
                    if pending_timeouts(i)='1' then
                        r.packet_index      := uns(i, BUF_INDEX_BITS);
                        r.send_buf_rd_addr  := stdulv(i, BUF_INDEX_BITS) & x"00";
                        r.state             := SENDING_DATA_PACKET_MAGIC;
                        r.timeout_ack       := (i => '1', others => '0');
                    end if;
                end loop;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        
        next_reg   <= r;
    end process;
    
    stm_sync_proc : process(RST, CLK)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(CLK) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

