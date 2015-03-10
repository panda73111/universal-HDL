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
use work.TRANSPORT_LAYER_PKG.all;
use work.help_funcs.all;

entity TRANSPORT_LAYER_SENDER is
    generic (
        TIMEOUT_CYCLES      : positive := 5_000_000; -- 100 ms
        MAX_TIMEOUT_RESENDS : positive := 10
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PACKET_OUT          : out std_ulogic_vector(7 downto 0) := x"00";
        PACKET_OUT_VALID    : out std_ulogic := '0';
        PACKET_OUT_END      : out std_ulogic := '0';
        
        DIN         : in std_ulogic_vector(7 downto 0);
        DIN_WR_EN   : in std_ulogic;
        SEND_PACKET : in std_ulogic;
        
        PENDING_RESEND_REQUESTS : in std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        RESEND_REQUEST_ACK      : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        
        PENDING_RECEIVED_ACKS   : in std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        ACK_RECEIVED_ACK        : out std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
        
        PENDING_ACK_TO_SEND         : in std_ulogic;
        PENDING_ACK_PACKET_NUMBER   : in std_ulogic_vector(7 downto 0);
        ACK_SENT                    : out std_ulogic := '0';
        
        SEND_RECORDS_INDEX  : in std_ulogic_vector(7 downto 0);
        SEND_RECORDS_DOUT   : out packet_record_type := packet_record_type_def;
        
        BUSY    : out std_ulogic := '1'
    );
end TRANSPORT_LAYER_SENDER;

architecture rtl of TRANSPORT_LAYER_SENDER is
    
    constant BUF_INDEX_BITS : natural := log2(BUFFERED_PACKETS);
    
    --- main state machine ---
    
    type state_type is (
        CLEARING_RECORDS,
        WAITING_FOR_DATA,
        SENDING_DATA_PACKET_MAGIC,
        SENDING_DATA_PACKET_NUMBER,
        SENDING_DATA_PACKET_LENGTH,
        SENDING_DATA_PACKET_PAYLOAD,
        SENDING_DATA_PACKET_CHECKSUM,
        EVALUATING_TIMED_OUT_PACKET_ADDR,
        EVALUATING_REQUESTED_TO_RESEND_PACKET_ADDR,
        RESENDING_DATA_PACKET_MAGIC,
        RESENDING_DATA_PACKET_NUMBER,
        RESENDING_DATA_PACKET_LENGTH,
        RESENDING_DATA_PACKET_PAYLOAD,
        RESENDING_CHECKSUM,
        REMOVING_PACKET_FROM_BUFFER,
        REMOVING_PACKET_FROM_RECORDS,
        SENDING_ACK_PACKET_MAGIC,
        SENDING_ACK_PACKET_NUMBER,
        SENDING_ACK_PACKET_CHECKSUM
    );
    
    type reg_type is record
        state                   : state_type;
        packet_out              : std_ulogic_vector(7 downto 0);
        packet_out_valid        : std_ulogic;
        packet_length           : unsigned(7 downto 0);
        packet_index            : unsigned(BUF_INDEX_BITS-1 downto 0);
        bytes_left_counter      : unsigned(8 downto 0);
        next_packet_number      : unsigned(7 downto 0);
        checksum                : std_ulogic_vector(7 downto 0);
        occupied_slots          : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        next_free_slot          : unsigned(BUF_INDEX_BITS-1 downto 0);
        --- resend request and acknowledge handling ---
        resend_request_ack      : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        ack_received_ack        : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        ack_sent                : std_ulogic;
        --- packet buffer ---
        buf_wr_addr             : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        buf_rd_addr             : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        --- timeout ---
        timeout_ack             : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        timeout_start           : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        timeout_rst             : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        --- global packet records ---
        send_records_index      : unsigned(7 downto 0);
        send_records_din        : packet_record_type;
        send_records_wr_en      : std_ulogic;
        --- packet meta information records ---
        meta_din                : packet_meta_record_type;
        meta_wr_en              : std_ulogic;
    end record;
    
    constant reg_type_def   : reg_type := (
        state                   => CLEARING_RECORDS,
        packet_out              => x"00",
        packet_out_valid        => '0',
        packet_length           => x"00",
        packet_index            => (others => '0'),
        bytes_left_counter      => (others => '0'),
        next_packet_number      => x"00",
        checksum                => x"00",
        occupied_slots          => (others => '0'),
        next_free_slot          => (others => '0'),
        --- resend request and acknowledge handling ---
        resend_request_ack      => (others => '0'),
        ack_received_ack        => (others => '0'),
        ack_sent                => '0',
        --- packet buffer ---
        buf_wr_addr             => (others => '0'),
        buf_rd_addr             => (others => '0'),
        --- timeout ---
        timeout_ack             => (others => '0'),
        timeout_start           => (others => '0'),
        timeout_rst             => (others => '0'),
        --- global packet records ---
        send_records_index      => x"00",
        send_records_din        => packet_record_type_def,
        send_records_wr_en      => '0',
        --- packet meta information records ---
        meta_din                => packet_meta_record_type_def,
        meta_wr_en              => '0'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal buf_dout : std_ulogic_vector(7 downto 0) := x"00";
    
    --- timeout records ---
    
    constant TIMEOUT_BITS   : natural := log2(TIMEOUT_CYCLES);
    
    type timeout_record_type is record
        is_active   : boolean;
        timeout     : unsigned(TIMEOUT_BITS downto 0);
        buf_addr    : std_ulogic_vector(BUF_INDEX_BITS+2 downto 0);
    end record;
    
    type timeout_records_type is
        array(0 to BUFFERED_PACKETS-1) of
        timeout_record_type;
    
    constant timeout_def    :
        unsigned(TIMEOUT_BITS downto 0) :=
        uns(TIMEOUT_CYCLES-1, TIMEOUT_BITS+1);
    
    constant timeout_records_type_def   : timeout_records_type := (
        others => (
            is_active   => false,
            timeout     => timeout_def,
            buf_addr    => (others => '0')
        )
    );
    
    type timeout_resend_counters_type is
        array(0 to BUFFERED_PACKETS-1) of
        unsigned(log2(MAX_TIMEOUT_RESENDS) downto 0);
    
    constant timeout_resend_counter_def :
        unsigned(log2(MAX_TIMEOUT_RESENDS) downto 0) :=
        uns(MAX_TIMEOUT_RESENDS-1, log2(MAX_TIMEOUT_RESENDS)+1);
    
    signal timeout_resend_counters  : timeout_resend_counters_type := (
        others => timeout_resend_counter_def
    );
    
    signal timeout_records  : timeout_records_type := timeout_records_type_def;
    signal pending_timeouts : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    signal send_packet_records  : packet_records_type := packet_records_type_def;
    
    signal packet_meta_records  : packet_meta_records_type := packet_meta_records_type_def;
    signal meta_dout            : packet_meta_record_type := packet_meta_record_type_def;
    
    signal packet_out_valid_q   : std_ulogic := '0';
    
begin
    
    PACKET_OUT          <= cur_reg.packet_out;
    PACKET_OUT_VALID    <= cur_reg.packet_out_valid;
    
    RESEND_REQUEST_ACK  <= cur_reg.resend_request_ack;
    ACK_RECEIVED_ACK    <= cur_reg.ack_received_ack;
    
    ACK_SENT    <= cur_reg.ack_sent;
    
    BUSY    <= '1' when cur_reg.state/=WAITING_FOR_DATA else '0';
    
    send_buf_DUAL_PORT_RAM_inst : entity work.DUAL_PORT_RAM
        generic map (
            WIDTH       => 8,
            DEPTH       => BUFFERED_PACKETS*256,
            WRITE_FIRST => false
        )
        port map (
            CLK => CLK,
            
            RD_ADDR => cur_reg.buf_rd_addr,
            WR_ADDR => cur_reg.buf_wr_addr,
            WR_EN   => DIN_WR_EN,
            DIN     => DIN,
            
            DOUT    => buf_dout
        );
    
    packet_out_end_proc : process(RST, CLK)
    begin
        if RST='1' then
            packet_out_valid_q  <= '0';
            PACKET_OUT_END      <= '0';
        elsif rising_edge(CLK) then
            packet_out_valid_q  <= cur_reg.packet_out_valid;
            PACKET_OUT_END      <= packet_out_valid_q and not cur_reg.packet_out_valid;
        end if;
    end process;
    
    send_records_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            SEND_RECORDS_DOUT   <= vector_to_packet_record_type(send_packet_records(int(SEND_RECORDS_INDEX)));
            if cur_reg.send_records_wr_en='1' then
                send_packet_records(int(cur_reg.send_records_index)) <= packet_record_type_to_vector(cur_reg.send_records_din);
            end if;
        end if;
    end process;
    
    timeout_proc : process(RST, CLK)
        constant timeout_high   : natural := timeout_record_type.timeout'high;
    begin
        if RST='1' then
            timeout_records         <= timeout_records_type_def;
            pending_timeouts        <= (others => '0');
            timeout_resend_counters <= (others => timeout_resend_counter_def);
        elsif rising_edge(CLK) then
            for i in 0 to BUFFERED_PACKETS-1 loop
                if timeout_records(i).is_active then
                    -- waiting for acknowledge of packet at send buffer position [i]
                    timeout_records(i).timeout  <= timeout_records(i).timeout-1;
                    if timeout_records(i).timeout(timeout_high)='1' then
                        -- packet at send buffer position [i] timed out
                        pending_timeouts(i)             <= '1';
                        timeout_records(i).timeout      <= timeout_def;
                        timeout_records(i).is_active    <= false;
                        timeout_resend_counters(i)      <= timeout_resend_counters(i)-1;
                    end if;
                end if;
                
                if cur_reg.timeout_rst(i)='1' then
                    pending_timeouts(i)             <= '0';
                    timeout_records(i).timeout      <= timeout_def;
                    timeout_records(i).is_active    <= false;
                    timeout_resend_counters(i)      <= timeout_resend_counter_def;
                end if;
                
                if cur_reg.timeout_ack(i)='1' then
                    -- packet of which the acknowledge wasn't received in time was resent
                    pending_timeouts(i) <= '0';
                end if;
                
                if
                    cur_reg.timeout_start(i)='1' and
                    timeout_resend_counters(i)(timeout_resend_counters(i)'high)='0'
                then
                    timeout_records(i).is_active    <= true;
                end if;
            end loop;
        end if;
    end process;
    
    meta_proc : process(RST, CLK)
    begin
        if RST='1' then
            packet_meta_records <= packet_meta_records_type_def;
        elsif rising_edge(CLK) then
            meta_dout   <= packet_meta_records(int(next_reg.packet_index));
            if cur_reg.meta_wr_en='1' then
                packet_meta_records(int(cur_reg.packet_index))  <= cur_reg.meta_din;
            end if;
        end if;
    end process;
    
    stm_proc : process(RST, cur_reg, buf_dout, meta_dout, pending_timeouts,
        PENDING_RESEND_REQUESTS, PENDING_RECEIVED_ACKS, PENDING_ACK_TO_SEND,
        SEND_PACKET, DIN_WR_EN, PENDING_ACK_PACKET_NUMBER)
        alias cr is cur_reg;
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
            d           : in unsigned(7 downto 0);
            next_state  : in state_type;
            change_cond : in boolean
        ) is
        begin
            send_packet_byte(stdulv(d), next_state, true);
        end procedure;
        
        procedure send_packet_byte(
            d           : in std_ulogic_vector(7 downto 0);
            next_state  : in state_type
        ) is
        begin
            send_packet_byte(d, next_state, true);
        end procedure;
        
        procedure send_packet_byte(
            d           : in unsigned(7 downto 0);
            next_state  : in state_type
        ) is
        begin
            send_packet_byte(d, next_state, true);
        end procedure;
    begin
        r   := cr;
        
        r.send_records_wr_en    := '0';
        r.packet_out_valid      := '0';
        r.timeout_ack           := (others => '0');
        r.timeout_start         := (others => '0');
        r.timeout_rst           := (others => '0');
        r.resend_request_ack    := (others => '0');
        r.ack_received_ack      := (others => '0');
        r.ack_sent              := '0';
        r.meta_wr_en            := '0';
        
        if DIN_WR_EN='1' then
            r.packet_length := cr.packet_length+1;
            r.buf_wr_addr   := cr.buf_wr_addr+1;
        end if;
        
        case cr.state is
            
            when CLEARING_RECORDS =>
                r.send_records_index    := cr.send_records_index+1;
                r.send_records_din      := packet_record_type_def;
                r.send_records_wr_en    := '1';
                if cr.send_records_index=uns(255, 8) then
                    r.state := WAITING_FOR_DATA;
                end if;
            
            when WAITING_FOR_DATA =>
                r.occupied_slots(int(cr.next_free_slot))    := '1';
                r.buf_rd_addr           := stdulv(cr.next_free_slot) & x"00";
                r.send_records_index    := cr.next_packet_number;
                if pending_timeouts/=(pending_timeouts'range => '0') then
                    r.state := EVALUATING_TIMED_OUT_PACKET_ADDR;
                end if;
                if PENDING_RESEND_REQUESTS/=(PENDING_RESEND_REQUESTS'range => '0') then
                    r.state := EVALUATING_REQUESTED_TO_RESEND_PACKET_ADDR;
                end if;
                if PENDING_RECEIVED_ACKS/=(PENDING_RECEIVED_ACKS'range => '0') then
                    r.state := REMOVING_PACKET_FROM_BUFFER;
                end if;
                if PENDING_ACK_TO_SEND='1' then
                    r.state := SENDING_ACK_PACKET_MAGIC;
                end if;
                if SEND_PACKET='1' and cr.packet_length/=uns(0, 8) then
                    r.state := SENDING_DATA_PACKET_MAGIC;
                end if;
            
            when SENDING_DATA_PACKET_MAGIC =>
                r.checksum                  := DATA_MAGIC;
                r.packet_index              := cr.next_free_slot;
                r.packet_length             := x"00";
                r.meta_din.packet_number    := cr.next_packet_number;
                r.meta_din.packet_length    := cr.packet_length;
                r.send_records_index        := cr.next_packet_number;
                r.send_records_wr_en        := '1';
                r.send_records_din          := (
                    is_buffered => true,
                    buf_index   => cr.next_free_slot
                );
                for i in BUFFERED_PACKETS-1 downto 0 loop
                    if cr.occupied_slots(i)='0' then
                        r.next_free_slot    := uns(i, BUF_INDEX_BITS);
                        r.buf_wr_addr       := stdulv(i, BUF_INDEX_BITS) & x"00";
                    end if;
                end loop;
                send_packet_byte(DATA_MAGIC, SENDING_DATA_PACKET_NUMBER);
            
            when SENDING_DATA_PACKET_NUMBER =>
                r.checksum  := cr.checksum+cr.next_packet_number;
                send_packet_byte(cr.next_packet_number, SENDING_DATA_PACKET_LENGTH);
            
            when SENDING_DATA_PACKET_LENGTH =>
                r.buf_rd_addr           := cr.buf_rd_addr+1;
                r.bytes_left_counter    := ("0" & cr.meta_din.packet_length)-2;
                r.checksum              := cr.checksum+cr.meta_din.packet_length;
                send_packet_byte(stdulv(cr.meta_din.packet_length), SENDING_DATA_PACKET_PAYLOAD);
            
            when SENDING_DATA_PACKET_PAYLOAD =>
                r.buf_rd_addr           := cr.buf_rd_addr+1;
                r.bytes_left_counter    := cr.bytes_left_counter-1;
                r.checksum              := cr.checksum+buf_dout;
                send_packet_byte(buf_dout, SENDING_DATA_PACKET_CHECKSUM, cr.bytes_left_counter(8)='1');
            
            when SENDING_DATA_PACKET_CHECKSUM =>
                r.timeout_start(int(cr.packet_index))   := '1';
                r.next_packet_number                    := cr.next_packet_number+1;
                r.meta_din.checksum                     := cr.checksum;
                r.meta_wr_en                            := '1';
                send_packet_byte(cr.checksum, WAITING_FOR_DATA);
            
            when EVALUATING_TIMED_OUT_PACKET_ADDR =>
                for i in BUFFERED_PACKETS-1 downto 0 loop
                    if pending_timeouts(i)='1' then
                        r.packet_index  := uns(i, BUF_INDEX_BITS);
                        r.buf_rd_addr   := stdulv(i, BUF_INDEX_BITS) & x"00";
                        r.timeout_ack   := (i => '1', others => '0');
                    end if;
                end loop;
                r.state := RESENDING_DATA_PACKET_MAGIC;
            
            when EVALUATING_REQUESTED_TO_RESEND_PACKET_ADDR =>
                for i in BUFFERED_PACKETS-1 downto 0 loop
                    if PENDING_RESEND_REQUESTS(i)='1' then
                        r.packet_index          := uns(i, BUF_INDEX_BITS);
                        r.buf_rd_addr           := stdulv(i, BUF_INDEX_BITS) & x"00";
                        r.timeout_rst           := (i => '1', others => '0');
                        r.resend_request_ack    := (i => '1', others => '0');
                    end if;
                end loop;
                r.state := RESENDING_DATA_PACKET_MAGIC;
            
            when RESENDING_DATA_PACKET_MAGIC =>
                send_packet_byte(DATA_MAGIC, RESENDING_DATA_PACKET_NUMBER);
            
            when RESENDING_DATA_PACKET_NUMBER =>
                send_packet_byte(meta_dout.packet_number, RESENDING_DATA_PACKET_LENGTH);
            
            when RESENDING_DATA_PACKET_LENGTH =>
                r.buf_rd_addr           := cr.buf_rd_addr+1;
                r.bytes_left_counter    := "0" & (meta_dout.packet_length-2);
                send_packet_byte(meta_dout.packet_length, RESENDING_DATA_PACKET_PAYLOAD);
            
            when RESENDING_DATA_PACKET_PAYLOAD =>
                r.buf_rd_addr           := cr.buf_rd_addr+1;
                r.bytes_left_counter    := cr.bytes_left_counter-1;
                send_packet_byte(buf_dout, RESENDING_CHECKSUM, cr.bytes_left_counter(8)='1');
            
            when RESENDING_CHECKSUM =>
                r.timeout_start(int(cr.packet_index))   := '1';
                send_packet_byte(meta_dout.checksum, WAITING_FOR_DATA);
            
            when REMOVING_PACKET_FROM_BUFFER =>
                r.meta_din  := packet_meta_record_type_def;
                for i in BUFFERED_PACKETS-1 downto 0 loop
                    if PENDING_RECEIVED_ACKS(i)='1' then
                        r.packet_index      := uns(i, BUF_INDEX_BITS);
                        r.occupied_slots(i) := '0';
                        r.meta_wr_en        := '1';
                        r.ack_received_ack  := (i => '1', others => '0');
                        r.timeout_rst       := (i => '1', others => '0');
                    end if;
                end loop;
                r.state := REMOVING_PACKET_FROM_RECORDS;
            
            when REMOVING_PACKET_FROM_RECORDS =>
                r.send_records_index    := meta_dout.packet_number;
                r.send_records_wr_en    := '1';
                r.send_records_din      := packet_record_type_def;
                r.state                 := WAITING_FOR_DATA;
            
            when SENDING_ACK_PACKET_MAGIC =>
                r.ack_sent  := '1';
                r.checksum  := ACK_MAGIC;
                send_packet_byte(ACK_MAGIC, SENDING_ACK_PACKET_NUMBER);
            
            when SENDING_ACK_PACKET_NUMBER =>
                r.checksum  := cr.checksum+PENDING_ACK_PACKET_NUMBER;
                send_packet_byte(PENDING_ACK_PACKET_NUMBER, SENDING_ACK_PACKET_CHECKSUM);
            
            when SENDING_ACK_PACKET_CHECKSUM =>
                send_packet_byte(cr.checksum, WAITING_FOR_DATA);
            
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

