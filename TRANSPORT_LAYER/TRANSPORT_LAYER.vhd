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
--  supported, with a packet span of [BUFFERED_PACKETS].
--  
--  data packet format:                       acknowledge packet format:
--       7      0                                  7      0
--      +--------+                                +--------+
--    0 |01100101| data packet magic number     0 |01100110| acknowledge packet magic number
--      +--------+                                +--------+
--    1 | number | packet ID                    1 | number | ID of the acknowledged packet
--      +--------+                                +--------+
--    2 | length | payload length (1 biased)    2 |checksum|
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
--  A packet is sent when 256 bytes were written or less bytes were written and
--  the SEND_PACKET input was set to high. It is not possible to send a packet
--  not containing any data bytes. If an acknowledge for a sent packet is not
--  received within [RESEND_TIMEOUT_CYCLES] cycles, that packet is sent again.
--  This can occur up to [MAX_TIMEOUT_RESENDS] times.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.TRANSPORT_LAYER_PKG.all;
use work.help_funcs.all;

entity TRANSPORT_LAYER is
    generic (
        CLK_IN_PERIOD       : real;
        RESEND_TIMEOUT      : real := 200_000_000.0; -- 200 ms
        MAX_TIMEOUT_RESENDS : positive := 10
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PACKET_IN       : in std_ulogic_vector(7 downto 0);
        PACKET_IN_WR_EN : in std_ulogic;
        
        PACKET_OUT          : out std_ulogic_vector(7 downto 0) := x"00";
        PACKET_OUT_VALID    : out std_ulogic := '0';
        PACKET_OUT_END      : out std_ulogic := '0';
        
        DIN         : in std_ulogic_vector(7 downto 0);
        DIN_WR_EN   : in std_ulogic;
        SEND_PACKET : in std_ulogic;
        
        DOUT        : out std_ulogic_vector(7 downto 0) := x"00";
        DOUT_VALID  : out std_ulogic := '0';
        
        BUSY    : out std_ulogic := '1'
    );
end TRANSPORT_LAYER;

architecture rtl of TRANSPORT_LAYER is
    
    constant RESEND_TIMEOUT_CYCLES  : positive := int(ceil(RESEND_TIMEOUT / CLK_IN_PERIOD));
    
    signal pending_resend_requests  : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    signal resend_request_ack       : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    
    signal pending_received_acks    : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    signal ack_received_ack         : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    
    signal pending_ack_to_send          : std_ulogic := '0';
    signal ack_sent                     : std_ulogic := '0';
    signal pending_ack_packet_number    : std_ulogic_vector(7 downto 0) := x"00";
    
    signal send_records_index   : std_ulogic_vector(7 downto 0) := x"00";
    signal send_records_dout    : packet_record_type := packet_record_type_def;
    
    signal sender_busy, receiver_busy   : std_ulogic := '0';
    
begin
    
    BUSY    <= sender_busy or receiver_busy;
    
    TRANSPORT_LAYER_SENDER_inst : entity work.TRANSPORT_LAYER_SENDER
        generic map (
            RESEND_TIMEOUT_CYCLES   => RESEND_TIMEOUT_CYCLES,
            MAX_TIMEOUT_RESENDS     => MAX_TIMEOUT_RESENDS
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_OUT          => PACKET_OUT,
            PACKET_OUT_VALID    => PACKET_OUT_VALID,
            PACKET_OUT_END      => PACKET_OUT_END,
            
            DIN         => DIN,
            DIN_WR_EN   => DIN_WR_EN,
            SEND_PACKET => SEND_PACKET,
            
            PENDING_RESEND_REQUESTS => pending_resend_requests,
            RESEND_REQUEST_ACK      => resend_request_ack,
            
            PENDING_RECEIVED_ACKS   => pending_received_acks,
            ACK_RECEIVED_ACK        => ack_received_ack,
            
            PENDING_ACK_TO_SEND         => pending_ack_to_send,
            PENDING_ACK_PACKET_NUMBER   => pending_ack_packet_number,
            ACK_SENT                    => ack_sent,
            
            SEND_RECORDS_DOUT   => send_records_dout,
            SEND_RECORDS_INDEX  => send_records_index,
            
            BUSY    => sender_busy
        );
    
    TRANSPORT_LAYER_RECEIVER_inst : entity work.TRANSPORT_LAYER_RECEIVER
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_IN       => PACKET_IN,
            PACKET_IN_WR_EN => PACKET_IN_WR_EN,
            
            DOUT        => DOUT,
            DOUT_VALID  => DOUT_VALID,
            
            PENDING_RESEND_REQUESTS => pending_resend_requests,
            RESEND_REQUEST_ACK      => resend_request_ack,
            
            PENDING_RECEIVED_ACKS   => pending_received_acks,
            ACK_RECEIVED_ACK        => ack_received_ack,
            
            ACK_SENT                    => ack_sent,
            PENDING_ACK_TO_SEND         => pending_ack_to_send,
            PENDING_ACK_PACKET_NUMBER   => pending_ack_packet_number,
            
            SEND_RECORDS_DOUT   => send_records_dout,
            SEND_RECORDS_INDEX  => send_records_index,
            
            BUSY    => receiver_busy
        );
    
end rtl;
