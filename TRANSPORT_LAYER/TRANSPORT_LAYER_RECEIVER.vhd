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
        
        ACK_RECEIVED_ACK        : in std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        PENDING_RECEIVED_ACKS   : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        
        ACK_SENT                    : in std_ulogic;
        PENDING_ACK_TO_SEND         : out std_ulogic := '0';
        PENDING_ACK_PACKET_NUMBER   : out std_ulogic_vector(7 downto 0) := x"00";
        
        SEND_RECORDS_DOUT   : in packet_record_type;
        SEND_RECORDS_INDEX  : out std_ulogic_vector(7 downto 0) := x"00";
        
        BUSY    : out std_ulogic := '1'
    );
end TRANSPORT_LAYER_RECEIVER;

architecture rtl of TRANSPORT_LAYER_RECEIVER is
    
    constant SLOT_BITS  : natural := log2(BUFFERED_PACKETS);
    
    type state_type is (
        CLEARING_RECORDS,
        WAITING_FOR_DATA,
        GETTING_DATA_PACKET_NUMBER,
        GETTING_DATA_LENGTH,
        GETTING_DATA,
        COMPARING_DATA_CHECKSUM,
        GETTING_ACK_PACKET_NUMBER,
        COMPARING_ACK_CHECKSUM
    );
    
    type packet_number_list_type is array(0 to BUFFERED_PACKETS-1) of packet_number_type;
    
    type reg_type is record
        state                       : state_type;
        packet_number               : packet_number_type;
        slot                        : natural range 0 to BUFFERED_PACKETS-1;
        bytes_left_counter          : unsigned(8 downto 0);
        checksum                    : std_ulogic_vector(7 downto 0);
        occupied_slots              : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        next_free_slot              : natural range 0 to BUFFERED_PACKETS-1;
        got_first_packet            : boolean;
        --- acknowledge handling ---
        pending_received_acks       : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        pending_ack_to_send         : std_ulogic;
        pending_ack_packet_number   : packet_number_type;
        --- packet buffer ---
        buf_wr_en                   : std_ulogic;
        buf_wr_addr                 : std_ulogic_vector(SLOT_BITS+7 downto 0);
        --- global packet records ---
        records_index               : packet_number_type;
        recv_records_din            : packet_record_type;
        recv_records_wr_en          : std_ulogic;
        --- packet meta information records ---
        meta_din                    : packet_meta_record_type;
        meta_wr_en                  : std_ulogic;
    end record;
    
    constant reg_type_def  : reg_type := (
        state                       => CLEARING_RECORDS,
        packet_number               => x"00",
        slot                        => 0,
        bytes_left_counter          => (others => '0'),
        checksum                    => x"00",
        occupied_slots              => (others => '0'),
        next_free_slot              => 0,
        got_first_packet            => false,
        --- acknowledge handling ---
        pending_received_acks       => (others => '0'),
        pending_ack_to_send         => '0',
        pending_ack_packet_number   => x"00",
        --- packet buffer ---
        buf_wr_en                   => '0',
        buf_wr_addr                 => (others => '0'),
        --- global packet records ---
        records_index               => x"00",
        recv_records_din            => packet_record_type_def,
        recv_records_wr_en          => '0',
        --- packet meta information records ---
        meta_din                    => packet_meta_record_type_def,
        meta_wr_en                  => '0'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal buf_dout : std_ulogic_vector(7 downto 0) := x"00";
    
    signal recv_packet_records          : packet_records_type := packet_records_type_def;
    signal recv_records_readout_dout    : packet_record_type := packet_record_type_def;
    signal recv_records_dout            : packet_record_type := packet_record_type_def;
    
    signal packet_meta_records  : packet_meta_records_type := packet_meta_records_type_def;
    signal meta_dout            : packet_meta_record_type := packet_meta_record_type_def;
    
    signal acceptable_numbers  : packet_number_list_type := (others => x"00");
    signal is_number_acceptable : boolean := false;
    
    --- buffer readout ---
    
    type readout_state_type is (
        WAITING_FOR_FIRST_PACKET,
        WAITING_FOR_NEXT_PACKET,
        GETTING_PACKET_LENGTH,
        READING_OUT,
        INCREMENTING_PACKET_NUMBER
    );
    
    type readout_reg_type is record
        state               : readout_state_type;
        dout_valid          : std_ulogic;
        buf_rd_addr         : std_ulogic_vector(SLOT_BITS+7 downto 0);
        packet_number       : packet_number_type;
        bytes_left_to_read  : unsigned(8 downto 0);
        slot                : natural range 0 to BUFFERED_PACKETS-1;
        packet_rm_en        : std_ulogic;
    end record;
    
    constant readout_reg_type_def   : readout_reg_type := (
        state               => WAITING_FOR_FIRST_PACKET,
        dout_valid          => '0',
        buf_rd_addr         => (others => '0'),
        packet_number       => x"00",
        bytes_left_to_read  => (others => '0'),
        slot                => 0,
        packet_rm_en        => '0'
    );
    
    signal next_readout_reg, cur_readout_reg    : readout_reg_type := readout_reg_type_def;
    
begin
    
    DOUT        <= buf_dout;
    DOUT_VALID  <= cur_readout_reg.dout_valid;
    
    SEND_RECORDS_INDEX  <= stdulv(next_reg.records_index);
    
    PENDING_RECEIVED_ACKS   <= cur_reg.pending_received_acks;
    
    PENDING_ACK_TO_SEND         <= cur_reg.pending_ack_to_send;
    PENDING_ACK_PACKET_NUMBER   <= stdulv(cur_reg.pending_ack_packet_number);
    
    BUSY    <= '1' when
        cur_reg.state/=WAITING_FOR_DATA or
        cur_readout_reg.state=READING_OUT or
        cur_reg.pending_received_acks/=(cur_reg.pending_received_acks'range => '0')
            else '0';
    
    receive_buf_DUAL_PORT_RAM_inst : entity work.DUAL_PORT_RAM
        generic map (
            WIDTH   => 8,
            DEPTH   => BUFFERED_PACKETS*256
        )
        port map (
            CLK => CLK,
            
            RD_ADDR => cur_readout_reg.buf_rd_addr,
            WR_ADDR => cur_reg.buf_wr_addr,
            WR_EN   => next_reg.buf_wr_en,
            DIN     => PACKET_IN,
            
            DOUT    => buf_dout
        );
    
    recv_records_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            recv_records_dout           <= vector_to_packet_record_type(recv_packet_records(int(cur_reg.records_index)));
            recv_records_readout_dout   <= vector_to_packet_record_type(recv_packet_records(int(next_readout_reg.packet_number)));
            if cur_reg.recv_records_wr_en='1' then
                recv_packet_records(int(cur_reg.records_index)) <= packet_record_type_to_vector(cur_reg.recv_records_din);
            end if;
            if next_readout_reg.packet_rm_en='1' then
                recv_packet_records(int(next_readout_reg.packet_number))   <= packet_record_type_to_vector(packet_record_type_def);
            end if;
        end if;
    end process;
    
    meta_proc : process(RST, CLK)
    begin
        if RST='1' then
            packet_meta_records <= packet_meta_records_type_def;
        elsif rising_edge(CLK) then
            meta_dout   <= packet_meta_records(next_readout_reg.slot);
            if cur_reg.meta_wr_en='1' then
                packet_meta_records(cur_reg.slot)   <= cur_reg.meta_din;
            end if;
            if cur_readout_reg.packet_rm_en='1' then
                packet_meta_records(cur_readout_reg.slot)   <= packet_meta_record_type_def;
            end if;
        end if;
    end process;
    
    acceptable_number_proc : process(RST, CLK)
    begin
        if rising_edge(CLK) then
            is_number_acceptable    <= false;
            for i in 0 to BUFFERED_PACKETS-1 loop
                acceptable_numbers(i)   <= cur_readout_reg.packet_number+i;
                if acceptable_numbers(i)=cur_reg.packet_number then
                    is_number_acceptable    <= true;
                end if;
            end loop;
        end if;
    end process;
    
    readout_stm_proc : process(RST, cur_reg, cur_readout_reg, meta_dout, recv_records_readout_dout)
        alias cr is cur_readout_reg;
        variable r  : readout_reg_type := readout_reg_type_def;
    begin
        r   := cr;
        
        r.dout_valid    := '0';
        r.packet_rm_en  := '0';
            
        case cr.state is
            
            when WAITING_FOR_FIRST_PACKET =>
                if cur_reg.got_first_packet then
                    r.state := WAITING_FOR_NEXT_PACKET;
                end if;
            
            when WAITING_FOR_NEXT_PACKET =>
                r.buf_rd_addr   := stdulv(recv_records_readout_dout.slot, SLOT_BITS) & x"00";
                r.slot          := recv_records_readout_dout.slot;
                if recv_records_readout_dout.is_buffered then
                    r.state := GETTING_PACKET_LENGTH;
                end if;
            
            when GETTING_PACKET_LENGTH =>
                r.bytes_left_to_read    := ("0" & meta_dout.packet_length)-1;
                r.state                 := READING_OUT;
            
            when READING_OUT =>
                r.buf_rd_addr         := cr.buf_rd_addr+1;
                r.bytes_left_to_read  := cr.bytes_left_to_read-1;
                r.dout_valid          := '1';
                if cr.bytes_left_to_read(8)='1' then
                    -- finished reading one packet, remove it from the buffer
                    r.packet_rm_en  := '1';
                    r.state         := INCREMENTING_PACKET_NUMBER;
                end if;
            
            when INCREMENTING_PACKET_NUMBER =>
                r.packet_number := cr.packet_number+1;
                r.state         := WAITING_FOR_NEXT_PACKET;
            
        end case;
        
        if RST='1' then
            r   := readout_reg_type_def;
        end if;
        
        next_readout_reg    <= r;
    end process;
    
    stm_proc : process(RST, cur_reg, cur_readout_reg, recv_records_dout, is_number_acceptable,
        ACK_RECEIVED_ACK, ACK_SENT, PACKET_IN, PACKET_IN_WR_EN, SEND_RECORDS_DOUT)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        r.buf_wr_en                     := '0';
        r.recv_records_wr_en            := '0';
        r.recv_records_din.is_buffered  := true;
        r.meta_wr_en                    := '0';
        
        -- high input bits clear high output bits
        r.pending_received_acks := cr.pending_received_acks and (cr.pending_received_acks xor ACK_RECEIVED_ACK);
        r.pending_ack_to_send   := cr.pending_ack_to_send   and (cr.pending_ack_to_send xor ACK_SENT);
        
        if cur_readout_reg.packet_rm_en='1' then
            r.occupied_slots(cur_readout_reg.slot)  := '0';
        end if;
        
        case cr.state is
            
            when CLEARING_RECORDS =>
                r.records_index         := cr.records_index+1;
                r.recv_records_din      := packet_record_type_def;
                r.recv_records_wr_en    := '1';
                if cr.records_index=uns(255, 8) then
                    r.state := WAITING_FOR_DATA;
                end if;
            
            when WAITING_FOR_DATA =>
                r.occupied_slots(cr.next_free_slot) := '1';
                r.records_index         := cr.packet_number;
                r.slot                  := cr.next_free_slot;
                r.recv_records_din.slot := cr.next_free_slot;
                r.checksum              := PACKET_IN;
                if PACKET_IN_WR_EN='1' then
                    if PACKET_IN=DATA_MAGIC then
                        r.state := GETTING_DATA_PACKET_NUMBER;
                    elsif PACKET_IN=ACK_MAGIC then
                        r.state := GETTING_ACK_PACKET_NUMBER;
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
                r.bytes_left_counter        := ("0" & uns(PACKET_IN))-1;
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
                if PACKET_IN_WR_EN='1' then
                    if
                        cr.checksum=PACKET_IN and
                        not recv_records_dout.is_buffered and
                        is_number_acceptable
                    then
                        for i in BUFFERED_PACKETS-1 downto 0 loop
                            if cr.occupied_slots(i)='0' then
                                r.next_free_slot        := i;
                                r.buf_wr_addr           := stdulv(i, SLOT_BITS) & x"00";
                            end if;
                        end loop;
                        r.meta_wr_en                := '1';
                        r.got_first_packet          := true;
                        r.recv_records_wr_en        := '1';
                        r.pending_ack_to_send       := '1';
                        r.pending_ack_packet_number := cr.packet_number;
                    end if;
                    r.state := WAITING_FOR_DATA;
                end if;
            
            when GETTING_ACK_PACKET_NUMBER =>
                r.packet_number := uns(PACKET_IN);
                r.records_index := uns(PACKET_IN);
                if PACKET_IN_WR_EN='1' then
                    r.checksum  := cr.checksum+PACKET_IN;
                    r.state     := COMPARING_ACK_CHECKSUM;
                end if;
            
            when COMPARING_ACK_CHECKSUM =>
                if PACKET_IN_WR_EN='1' then
                    if
                        cr.checksum=PACKET_IN and
                        SEND_RECORDS_DOUT.is_buffered
                    then
                        r.pending_received_acks(SEND_RECORDS_DOUT.slot) := '1';
                    end if;
                    r.state     := WAITING_FOR_DATA;
                end if;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        
        next_reg   <= r;
    end process;
    
    stm_sync_proc : process(RST, CLK)
    begin
        if RST='1' then
            cur_reg         <= reg_type_def;
            cur_readout_reg <= readout_reg_type_def;
        elsif rising_edge(CLK) then
            cur_reg         <= next_reg;
            cur_readout_reg <= next_readout_reg;
        end if;
    end process;
    
end rtl;

