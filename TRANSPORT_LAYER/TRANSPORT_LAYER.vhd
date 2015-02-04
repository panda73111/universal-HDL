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

entity RUDP_LAYER is
    generic (
        TIMEOUT_CYCLES      : positive := 1024;
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
end RUDP_LAYER;

architecture rtl of RUDP_LAYER is
    
    constant DATA_MAGIC     : std_ulogic_vector(7 downto 0) := x"65";
    constant ACK_MAGIC      : std_ulogic_vector(7 downto 0) := x"66";
    constant RESEND_MAGIC   : std_ulogic_vector(7 downto 0) := x"67";
    
    type send_state_type is (
        WAITING_FOR_DATA
    );
    
    type send_reg_type is record
        state               : send_state_type;
        packet_out          : std_ulogic_vector(7 downto 0);
        packet_out_valid    : std_ulogic;
        send_buf_wr_addr    : std_ulogic_vector(log2(BUFFERED_PACKETS)+2 downto 0);
        send_buf_rd_addr    : std_ulogic_vector(log2(BUFFERED_PACKETS)+2 downto 0);
        rst_checksum        : boolean;
        next_packet_number  : unsigned(7 downto 0);
        timeout             : unsigned(10 downto 0);
    end record;
    
    constant send_reg_type_def   : send_reg_type := (
        state               => WAITING_FOR_DATA,
        packet_out          => x"00",
        packet_out_valid    => '0',
        send_buf_wr_addr    => (others => '0'),
        send_buf_rd_addr    => (others => '0'),
        rst_checksum        => true,
        next_packet_number  => x"00",
        timeout             => (others => '0')
    );
    
    type recv_state_type is (
        WAITING_FOR_DATA
    );
    
    type recv_reg_type is record
        state               : recv_state_type;
        recv_buf_wr_addr    : std_ulogic_vector(log2(BUFFERED_PACKETS)+2 downto 0);
        recv_buf_rd_addr    : std_ulogic_vector(log2(BUFFERED_PACKETS)+2 downto 0);
        recv_buf_rd_en      : std_ulogic;
        next_packet_number  : unsigned(7 downto 0);
    end record;
    
    constant recv_reg_type_def  : recv_state_type := (
        state           => WAITING_FOR_DATA,
        recv_buf_wr_addr    => (others => '0'),
        recv_buf_rd_addr    => (others => '0'),
        next_packet_number  => x"00"
    );
    
    signal cur_send_reg, next_send_reg  : send_reg_type := send_reg_type_def;
    signal cur_recv_reg, next_recv_reg  : recv_reg_type := recv_reg_type_def;
    
    signal send_buf_dout    : std_ulogic_vector(7 downto 0) := x"00";
    signal send_buf_valid   : std_ulogic := '0';
    signal send_buf_valid   : std_ulogic := '0';
    signal send_buf_count   : std_ulogic_vector(7 downto 0) := x"00";
    
    signal recv_buf_dout    : std_ulogic_vector(7 downto 0) := x"00";
    signal recv_buf_valid   : std_ulogic := '0';
    
    signal checksum : std_ulogic_vector(7 downto 0) := x"00";
    
begin
    
    PACKET_OUT          <= cur_reg.packet_out;
    PACKET_OUT_VALID    <= cur_reg.packet_out_valid;
    
    BUSY    <= '1' when cur_reg.state=WAITING_FOR_DATA else '0';
    
    send_buf_DUAL_PORT_RAM_inst : entity work.DUAL_PORT_RAM
        generic map (
            WIDTH   => 8,
            DEPTH   => BUFFERED_PACKETS*256
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            RD_ADDR => cur_send_reg.send_buf_rd_addr,
            WR_ADDR => cur_send_reg.send_buf_wr_addr,
            WR_EN   => DIN_WR_EN,
            DIN     => DIN,
            
            DOUT    => send_buf_dout
        );
    
    receive_buf_DUAL_PORT_RAM_inst : entity work.DUAL_PORT_RAM
        generic map (
            WIDTH   => 8,
            DEPTH   => BUFFERED_PACKETS*256
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            RD_ADDR => cur_recv_reg.recv_buf_rd_addr,
            WR_ADDR => cur_recv_reg.recv_buf_wr_addr,
            WR_EN   => cur_recv_reg.recv_buf_wr_en,
            DIN     => PACKET_IN,
            
            DOUT    => recv_buf_dout
        );
    
    checksum_proc : process(cur_reg.rst_checksum, CLK)
    begin
        if cur_reg.rst_checksum then
            checksum    <= x"00";
        elsif rising_edge(CLK) then
            if cur_reg.packet_out_valid='1' then
                checksum    <= checksum+cur_reg.packet_out;
            end if;
        end if;
    end process;
    
    send_stm_proc : process(RST, cur_send_reg)
        alias cr is cur_send_reg;
        variable r  : send_reg_type := send_reg_type_def;
        
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
        r.rst_checksum      := false;
        
        case cr.state is
            
            when WAITING_FOR_DATA =>
                if SEND='1' and send_buf_empty='0' then
                    r.state := SENDING_DATA_PACKET_MAGIC;
                end if;
            
            when SENDING_DATA_PACKET_MAGIC =>
                send_packet_byte(DATA_MAGIC, SENDING_DATA_PACKET_NUMBER);
            
            when SENDING_DATA_PACKET_NUMBER =>
                send_packet_byte(cr.next_packet_number, SENDING_DATA_PACKET_LENGTH);
            
            when SENDING_DATA_PACKET_LENGTH =>
                r.send_buf_rd_en    := '1';
                send_packet_byte(send_buf_count, SENDING_DATA_PACKET_PAYLOAD);
            
            when SENDING_DATA_PACKET_PAYLOAD =>
                r.send_buf_rd_en    := '1';
                send_packet_byte(send_buf_dout, WAITING_FOR_ACK_MAGIC, send_buf_empty);
            
            when WAITING_FOR_ACK_MAGIC =>
                r.recv_buf_rd_en    := '1';
                if recv_buf_valid='1' then
                    if recv_buf_dout=ACK_MAGIC then
                        r.state := WAITING_FOR_DATA;
                    end if;
                end if;
            
        end case;
        
        if RST='1' then
            r   := send_reg_type_def;
        end if;
        
        next_send_reg   <= r;
    end process;
    
    recv_stm_proc : process(RST, cur_recv_reg)
        alias cr is cur_recv_reg;
        variable r  : recv_reg_type := recv_reg_type_def;
    begin
        r   := cr;
        
        r.recv_buf_wr_en    := '0';
        
        case cr.state is
            
            when WAITING_FOR_DATA =>
                if PACKET_IN_WR_EN='1' then
                    if PACKET_DIN=DATA_MAGIC then
                        r.state := CHECKING_DATA_PACKET_NUMBER;
                    elsif PACKET_DIN=ACK_MAGIC then
                        r.state := CHECKING_ACK_PACKET_NUMBER;
                    elsif PACKET_DIN=RESEND_MAGIC then
                        r.state := CHECKING_RESEND_PACKET_NUMBER;
                    end if;
                end if;
            
            when CHECKING_DATA_PACKET_NUMBER =>
                
            
            when CHECKING_ACK_PACKET_NUMBER =>
                
            
            when CHECKING_RESEND_PACKET_NUMBER =>
                
            
        end case;
        
        if RST='1' then
            r   := recv_reg_type_def;
        end if;
        
        next_recv_reg   <= r;
    end process;
    
    stm_sync_proc : process(RST, CLK)
    begin
        if RST='1' then
            cur_send_reg    <= send_reg_type_def;
            cur_recv_reg    <= recv_reg_type_def;
        elsif rising_edge(CLK) then
            cur_send_reg    <= next_send_reg;
            cur_recv_reg    <= next_recv_reg;
        end if;
    end process;
    
end rtl;
