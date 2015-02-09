----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    10:15:34 02/02/2015 
-- Module Name:    RUDP_LAYER - rtl 
-- Project Name:   RUDP_LAYER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  Simple reliable data transfer protocol using acknowledgement and re-sending
--  of packets. The payload length is up to 256 bytes. The integrity is ensured
--  by including checksums at the end of each packet. Out-of-order sending is
--  supported.
--  
--  data packet format:                       acknowledge packet format:
--       7      0                                  7      0
--      +--------+                                +--------+
--    0 |01100101| data packet magic number     0 |01100110| acknowledge packet magic number
--      +--------+                                +--------+
--    1 | number | packet ID                    1 | number | ID of the acknowledged packet
--      +--------+                                +--------+
--    2 | length | payload length               2 |checksum|
--      +--------+                                +--------+
--    3 |        |
--         data                               resend demand packet format:
--  n-1 |        |                                 7      0
--      +--------+                                +--------+
--    n |checksum|                              0 |01100111| resend demand packet magic number
--      +--------+                                +--------+
--                                              1 | number | ID of the packet to be resent
--                                                +--------+
--                                              2 |checksum|
--                                                +--------+
-- Additional Comments:
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity TRANSPORT_LAYER is
    generic (
        TIMEOUT_CYCLES      : positive := 50000; -- 1 ms
        BUFFERED_PACKETS    : positive := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PACKET_IN       : in std_ulogic_vector(7 downto 0);
        PACKET_IN_WR_EN : in std_ulogic;
        
        PACKET_OUT          : out std_ulogic_vector(7 downto 0) := x"00";
        PACKET_OUT_VALID    : out std_ulogic := '0';
        
        DIN         : in std_ulogic_vector(7 downto 0);
        DIN_WR_EN   : in std_ulogic;
        SEND        : in std_ulogic;
        
        DOUT        : out std_ulogic_vector(7 downto 0) := x"00";
        DOUT_VALID  : out std_ulogic := '0';
        
        BUSY    : out std_ulogic := '0'
    );
end TRANSPORT_LAYER;

architecture rtl of TRANSPORT_LAYER is
    
    constant DATA_MAGIC     : std_ulogic_vector(7 downto 0) := x"65";
    constant ACK_MAGIC      : std_ulogic_vector(7 downto 0) := x"66";
    constant RESEND_MAGIC   : std_ulogic_vector(7 downto 0) := x"67";
    
    constant BUF_INDEX_BITS : natural := log2(BUFFERED_PACKETS);
    constant TIMEOUT_BITS   : natural := log2(TIMEOUT_CYCLES);
    
    --- packet records, accessed by both state machines ---
    
    type packet_record_type is record
        is_buffered : boolean;
        buf_index   : std_ulogic_vector(BUF_INDEX_BITS-1 downto 0);
    end record;
    
    constant packet_record_type_def : packet_record_type := (
        is_buffered => false,
        buf_index   => (others => '0')
    );
    
    type packet_records_type is
        array(0 to 255) of
        packet_record_type;
    
    constant packet_records_type_def    : packet_records_type := (
        others => packet_record_type_def
    );
    
    signal packet_records       : packet_records_type := packet_records_type_def;
    signal send_records_dout    : packet_record_type := packet_record_type_def;
    signal recv_records_dout    : packet_record_type := packet_record_type_def;
    
    --- timeout records ---
    
    type timeout_record_type is record
        is_active       : boolean;
        timeout         : unsigned(TIMEOUT_BITS downto 0);
        send_buf_addr   : std_ulogic_vector(BUF_INDEX_BITS+2 downto 0);
    end record;
    
    type timeout_records_type is
        array(0 to BUFFERED_PACKETS-1) of
        timeout_record_type;
    
    constant timeout_def    :
        unsigned(TIMEOUT_BITS downto 0) :=
        uns(TIMEOUT_CYCLES-1, timeout_record_type.buf_p'length);
    
    constant timeout_records_type_def   : timeout_records_type := (
        others => (
            is_active       => false,
            timeout         => TIMEOUT_DEF,
            send_buf_addr   => (others => '0')
        )
    );
    
    signal timeout_records  : timeout_records_type := timeout_records_type_def;
    signal pending_timeouts : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    signal timeout_ack      : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    
    signal sender_busy, receiver_busy   : std_ulogic := '0';
    
begin
    
    PACKET_OUT          <= cur_reg.packet_out;
    PACKET_OUT_VALID    <= cur_reg.packet_out_valid;
    
    BUSY    <= '1' when cur_send_reg.state=WAITING_FOR_DATA else '0';
    
    TRANSPORT_LAYER_SENDER_inst : entity work.TRANSPORT_LAYER_SENDER
        generic map (
            BUFFERED_PACKETS    => BUFFERED_PACKETS,
            DATA_MAGIC          => DATA_MAGIC,
            ACK_MAGIC           => ACK_MAGIC,
            RESEND_MAGIC        => RESEND_MAGIC
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_OUT          => PACKET_OUT,
            PACKET_OUT_VALID    => PACKET_OUT_VALID,
            
            DIN         => DIN,
            DIN_WR_EN   => DIN_WR_EN,
            SEND        => SEND,
            
            PENDING_TIMEOUTS    => pending_timeouts,
            TIMEOUT_ACK         => timeout_ack,
            TIMEOUT_START       => timeout_start,
            
            BUSY    => sender_busy
        );
    
    TRANSPORT_LAYER_RECEIVER_inst : entity work.TRANSPORT_LAYER_RECEIVER
        generic map (
            BUFFERED_PACKETS    => BUFFERED_PACKETS,
            DATA_MAGIC          => DATA_MAGIC,
            ACK_MAGIC           => ACK_MAGIC,
            RESEND_MAGIC        => RESEND_MAGIC
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_IN       => PACKET_IN,
            PACKET_IN_WR_EN => PACKET_IN_WR_EN,
            
            DOUT        => DOUT,
            DOUT_VALID  => DOUT_VALID,
            
            BUSY    => receiver_busy
        );
    
    packet_records_proc : process(RST, CLK)
    begin
        if RST='1' then
            packet_records  <= packet_records_type_def;
        elsif rising_edge(CLK) then
            send_records_dout   <= packet_records(int(cur_send_reg.records_index));
            recv_records_dout   <= packet_records(int(cur_recv_reg.records_index));
            
            if cur_send_reg.records_wr_en='1' then
                packet_records(int(cur_send_reg.records_index)) <= cur_send_reg.records_din;
            end if;
            
            if cur_recv_reg.records_wr_en='1' then
                packet_records(int(cur_send_reg.records_index)) <= cur_recv_reg.records_din;
            end if;
        end if;
    end process;
    
    timeout_proc : process(RST, CLK)
        constant timeout_high   : natural := timeout_records_type.timeout'high;
    begin
        if RST='1' then
            timeout_records     <= timeout_records_type_def;
            pending_timeouts    <= (others => '0');
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
                    end if;
                end if;
                
                if timeout_ack(i)='1' then
                    -- packet of which the acknowledge timed out was resent
                    pending_timeouts(i) <= '0';
                end if;
                
                if timeout_start(i)='1' then
                    timeout_records(i).is_active    <= true;
                end if;
            end loop;
        end if;
    end process;
    
end rtl;
