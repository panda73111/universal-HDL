----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    18:41:28 02/09/2015 
-- Module Name:    TRANSPORT_LAYER_RECEIVER - rtl 
-- Project Name:   TRANSPORT_LAYER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  
-- Additional Comments:
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.TRANSPORT_LAYER_PKG.all;
use work.help_funcs.all;

entity TRANSPORT_LAYER_RECEIVER is
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PACKET_IN       : in std_ulogic_vector(7 downto 0);
        PACKET_IN_WR_EN : in std_ulogic;
        
        DOUT        : out std_ulogic_vector(7 downto 0) := x"00";
        DOUT_VALID  : out std_ulogic := '0';
        
        RESEND_REQUEST_ACK      : in std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        PENDING_RESEND_REQUESTS : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        
        ACK_ACK         : in std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        PENDING_ACKS    : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        
        RECORDS_INDEX   : out std_ulogic_vector(7 downto 0) := x"00";
        RECORDS_DOUT    : in packet_record_type;
        RECORDS_DIN     : out packet_record_type := packet_record_type_def;
        RECORDS_WR_EN   : out std_ulogic := '0';
        
        BUSY    : out std_ulogic := '0'
    );
end TRANSPORT_LAYER_RECEIVER;

architecture rtl of TRANSPORT_LAYER_RECEIVER is
    
    constant BUF_INDEX_BITS : natural := log2(BUFFERED_PACKETS);
    
    type state_type is (
        WAITING_FOR_DATA,
        GETTING_DATA_PACKET_NUMBER,
        GETTING_DATA_LENGTH,
        GETTING_DATA,
        COMPARING_DATA_CHECKSUM,
        GETTING_ACK_PACKET_NUMBER,
        COMPARING_ACK_CHECKSUM,
        GETTING_RESEND_PACKET_NUMBER,
        COMPARING_RESEND_CHECKSUM
    );
    
    type reg_type is record
        state               : state_type;
        packet_number       : unsigned(7 downto 0);
        packet_index        : unsigned(BUF_INDEX_BITS-1 downto 0);
        bytes_left_counter  : unsigned(8 downto 0);
        checksum            : std_ulogic_vector(7 downto 0);
        occupied_buf_slots  : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        next_free_buf_index : unsigned(BUF_INDEX_BITS-1 downto 0);
        got_first_packet    : boolean;
        --- resend request and acknowledge handling ---
        pending_resend_reqs : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        pending_acks        : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        --- packet buffer ---
        buf_wr_en           : std_ulogic;
        buf_wr_addr         : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        --- global packet records ---
        records_index       : unsigned(7 downto 0);
        records_din         : packet_record_type;
        records_wr_en       : std_ulogic;
        --- packet meta information records ---
        meta_din            : packet_meta_record_type;
        meta_wr_en          : std_ulogic;
    end record;
    
    constant reg_type_def  : reg_type := (
        state               => WAITING_FOR_DATA,
        packet_number       => x"00",
        packet_index        => (others => '0'),
        bytes_left_counter  => (others => '0'),
        checksum            => x"00",
        occupied_buf_slots  => (others => '0'),
        next_free_buf_index => (others => '0'),
        got_first_packet    => false,
        --- resend request and acknowledge handling ---
        pending_resend_reqs => (others => '0'),
        pending_acks        => (others => '0'),
        --- packet buffer ---
        buf_wr_en           => '0',
        buf_wr_addr         => (others => '0'),
        --- global packet records ---
        records_index       => x"00",
        records_din         => packet_record_type_def,
        records_wr_en       => '0',
        --- packet meta information records ---
        meta_din            => packet_meta_record_type_def,
        meta_wr_en          => '0'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal buf_dout : std_ulogic_vector(7 downto 0) := x"00";
    
    signal packet_meta_records  : packet_meta_records_type := packet_meta_records_type_def;
    signal meta_dout            : packet_meta_record_type := packet_meta_record_type_def;
    
    --- buffer readout ---
    signal buf_rd_addr          : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0) := (others => '0');
    signal next_number_to_read  : unsigned(7 downto 0) := x"00";
    signal bytes_left_to_read   : unsigned(8 downto 0) := (others => '0');
    signal reading_out          : boolean := false;
    signal readout_index        : unsigned(BUF_INDEX_BITS-1 downto 0) := (others => '0');
    signal readout_meta_rm_en   : std_ulogic := '0';
    
begin
    
    DOUT        <= buf_dout;
    
    RECORDS_INDEX   <= stdulv(next_reg.records_index);
    RECORDS_DIN     <= cur_reg.records_din;
    RECORDS_WR_EN   <= cur_reg.records_wr_en;
    
    PENDING_RESEND_REQUESTS <= cur_reg.pending_resend_reqs;
    PENDING_ACKS            <= cur_reg.pending_acks;
    
    BUSY    <= '1' when cur_reg.state/=WAITING_FOR_DATA or reading_out else '0';
    
    receive_buf_DUAL_PORT_RAM_inst : entity work.DUAL_PORT_RAM
        generic map (
            WIDTH   => 8,
            DEPTH   => BUFFERED_PACKETS*256
        )
        port map (
            CLK => CLK,
            
            RD_ADDR => buf_rd_addr,
            WR_ADDR => cur_reg.buf_wr_addr,
            WR_EN   => next_reg.buf_wr_en,
            DIN     => PACKET_IN,
            
            DOUT    => buf_dout
        );
    
    meta_proc : process(RST, CLK)
    begin
        if RST='1' then
            packet_meta_records <= packet_meta_records_type_def;
        elsif rising_edge(CLK) then
            meta_dout   <= packet_meta_records(int(readout_index));
            if cur_reg.meta_wr_en='1' then
                packet_meta_records(int(cur_reg.packet_index))  <= cur_reg.meta_din;
            end if;
            if readout_meta_rm_en='1' then
                packet_meta_records(int(readout_index)) <= packet_meta_record_type_def;
            end if;
        end if;
    end process;
    
    readout_proc : process(RST, CLK)
    begin
        if RST='1' then
            DOUT_VALID          <= '0';
            next_number_to_read <= x"00";
            reading_out         <= false;
            readout_meta_rm_en  <= '0';
        elsif rising_edge(CLK) then
            DOUT_VALID          <= '0';
            readout_meta_rm_en  <= '0';
            
            if reading_out then
                
                DOUT_VALID          <= '1';
                buf_rd_addr         <= buf_rd_addr+1;
                bytes_left_to_read  <= bytes_left_to_read-1;
                if bytes_left_to_read(8)='1' then
                    -- finished reading one packet, remove it from the buffer
                    reading_out         <= false;
                    readout_meta_rm_en  <= '1';
                    next_number_to_read <= next_number_to_read+1;
                end if;
                
            elsif cur_reg.got_first_packet then
                
                buf_rd_addr         <= stdulv(readout_index-1) & x"00";
                readout_index       <= readout_index-1;
                bytes_left_to_read  <= ("0" & meta_dout.packet_length)-2;
                if
                    meta_dout.is_buffered and
                    meta_dout.packet_number=next_number_to_read
                then
                    reading_out         <= true;
                else
                    -- search the next packet number to read in the metadata records
                    readout_index   <= readout_index+1;
                end if;
                
            end if;
        end if;
    end process;
    
    stm_proc : process(RST, cur_reg, readout_meta_rm_en, readout_index,
        ACK_ACK, RESEND_REQUEST_ACK, PACKET_IN, PACKET_IN_WR_EN, RECORDS_DOUT)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        r.records_wr_en         := '0';
        r.buf_wr_en             := '0';
        r.records_din.was_sent  := false;
        r.meta_wr_en            := '0';
        r.meta_din.is_buffered  := true;
        
        -- high ACK_ACK and RESEND_REQUEST_ACK bits clear high pending_acks and pending_resend_reqs bits
        r.pending_acks          := cr.pending_acks          and (cr.pending_acks xor ACK_ACK);
        r.pending_resend_reqs   := cr.pending_resend_reqs   and (cr.pending_resend_reqs xor RESEND_REQUEST_ACK);
        
        if readout_meta_rm_en='1' then
            r.occupied_buf_slots(int(readout_index))    := '0';
        end if;
        
        case cr.state is
            
            when WAITING_FOR_DATA =>
                r.occupied_buf_slots(int(cr.next_free_buf_index))   := '1';
                r.records_index             := cr.packet_number;
                r.packet_index              := cr.next_free_buf_index;
                r.records_din.is_buffered   := true;
                r.records_din.buf_index     := cr.next_free_buf_index;
                r.checksum                  := PACKET_IN;
                if PACKET_IN_WR_EN='1' then
                    if PACKET_IN=DATA_MAGIC then
                        r.state := GETTING_DATA_PACKET_NUMBER;
                    elsif PACKET_IN=ACK_MAGIC then
                        r.state := GETTING_ACK_PACKET_NUMBER;
                    elsif PACKET_IN=RESEND_MAGIC then
                        r.state := GETTING_RESEND_PACKET_NUMBER;
                    end if;
                end if;
            
            when GETTING_DATA_PACKET_NUMBER =>
                r.packet_number             := uns(PACKET_IN);
                r.records_index             := uns(PACKET_IN);
                r.meta_din.packet_number    := uns(PACKET_IN);
                if PACKET_IN_WR_EN='1' then
                    r.checksum  := cr.checksum+PACKET_IN;
                    r.state     := GETTING_DATA_LENGTH;
                end if;
            
            when GETTING_DATA_LENGTH =>
                r.meta_din.packet_length    := uns(PACKET_IN);
                r.bytes_left_counter        := ("0" & uns(PACKET_IN))-2;
                if PACKET_IN_WR_EN='1' then
                    r.checksum  := cr.checksum+PACKET_IN;
                    r.state     := GETTING_DATA;
                end if;
            
            when GETTING_DATA =>
                if PACKET_IN_WR_EN='1' then
                    r.buf_wr_en             := '1';
                    r.buf_wr_addr           := cr.buf_wr_addr+1;
                    r.checksum              := cr.checksum+PACKET_IN;
                    r.bytes_left_counter    := cr.bytes_left_counter-1;
                    if cr.bytes_left_counter(8)='1' then
                        r.state := COMPARING_DATA_CHECKSUM;
                    end if;
                end if;
            
            when COMPARING_DATA_CHECKSUM =>
                for i in BUFFERED_PACKETS-1 downto 0 loop
                    if cr.occupied_buf_slots(i)='0' then
                        r.next_free_buf_index   := uns(i, BUF_INDEX_BITS);
                        r.buf_wr_addr           := stdulv(i, BUF_INDEX_BITS) & x"00";
                    end if;
                end loop;
                if PACKET_IN_WR_EN='1' then
                    if cr.checksum=PACKET_IN then
                        r.meta_wr_en        := '1';
                        r.got_first_packet  := true;
                        r.records_wr_en     := '1';
                    end if;
                    r.state := WAITING_FOR_DATA;
                end if;
            
            when GETTING_ACK_PACKET_NUMBER =>
                r.packet_number := uns(PACKET_IN);
                r.checksum      := cr.checksum+PACKET_IN;
                r.records_index := uns(PACKET_IN);
                if PACKET_IN_WR_EN='1' then
                    r.state := COMPARING_ACK_CHECKSUM;
                end if;
            
            when COMPARING_ACK_CHECKSUM =>
                r.records_din.is_buffered   := false;
                if
                    cr.checksum=PACKET_IN and
                    RECORDS_DOUT.is_buffered and
                    RECORDS_DOUT.was_sent
                then
                    r.pending_acks(int(RECORDS_DOUT.buf_index)) := '1';
                    r.records_wr_en := '1';
                end if;
                r.state     := WAITING_FOR_DATA;
            
            when GETTING_RESEND_PACKET_NUMBER =>
                r.packet_number := uns(PACKET_IN);
                r.checksum      := cr.checksum+PACKET_IN;
                r.records_index := uns(PACKET_IN);
                r.state         := COMPARING_RESEND_CHECKSUM;
            
            when COMPARING_RESEND_CHECKSUM =>
                if
                    cr.checksum=PACKET_IN and
                    RECORDS_DOUT.is_buffered and
                    RECORDS_DOUT.was_sent
                then
                    r.pending_resend_reqs(int(RECORDS_DOUT.buf_index))  := '1';
                end if;
                r.state := WAITING_FOR_DATA;
            
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

