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
use work.TRANSPORT_LAYER_PKG.all;
use work.help_funcs.all;

entity TRANSPORT_LAYER is
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
    
    constant BUF_INDEX_BITS : natural := log2(BUFFERED_PACKETS);
    
    --- packet records, accessed by both state machines ---
    
    signal packet_records       : packet_records_type := packet_records_type_def;
    signal send_records_dout    : packet_record_type := packet_record_type_def;
    signal recv_records_dout    : packet_record_type := packet_record_type_def;
    
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
    
end rtl;
