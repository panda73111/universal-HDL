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
        WAITING_FOR_DATA
    );
    
    type reg_type is record
        state                   : state_type;
        dout                    : std_ulogic_vector(7 downto 0);
        dout_valid              : std_ulogic;
        next_packet_number      : unsigned(7 downto 0);
        packet_number           : unsigned(7 downto 0);
        checksum                : std_ulogic_vector(7 downto 0);
        occupied_buf_slots      : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        next_free_buf_index     : unsigned(BUF_INDEX_BITS-1 downto 0);
        --- resend request and acknowledge handling ---
        pending_resend_requests : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        pending_acks            : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
        --- packet buffer ---
        buf_wr_addr             : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        buf_rd_addr             : std_ulogic_vector(BUF_INDEX_BITS+7 downto 0);
        --- global packet records ---
        records_index           : unsigned(7 downto 0);
        records_din             : packet_record_type;
        records_wr_en           : std_ulogic;
        --- packet meta information records ---
        meta_din                : packet_meta_record_type;
        meta_wr_en              : std_ulogic;
    end record;
    
    constant reg_type_def  : recv_state_type := (
        state                   => WAITING_FOR_DATA,
        dout                    => x"00",
        dout_valid              => '0',
        next_packet_number      => x"00",
        packet_number           => x"00",
        checksum                => x"00",
        occupied_buf_slots      => (others => '0'),
        next_free_buf_index     => (others => '0'),
        --- resend request and acknowledge handling ---
        resend_request_ack      => (others => '0'),
        ack_ack                 => (others => '0'),
        --- packet buffer ---
        buf_wr_addr             => (others => '0'),
        buf_rd_addr             => (others => '0'),
        --- global packet records ---
        records_index           => x"00",
        records_din             => packet_record_type_def,
        records_wr_en           => '0',
        --- packet meta information records ---
        meta_din                => packet_meta_record_type_def,
        meta_wr_en              => '0'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal buf_dout : std_ulogic_vector(7 downto 0) := x"00";
    
    signal packet_meta_records  : packet_meta_records_type := packet_meta_records_type_def;
    signal meta_dout            : packet_meta_record_type := packet_meta_record_type_def;
    
begin
    
    DOUT        <= cur_reg.dout;
    DOUT_VALID  <= cur_reg.dout_valid;
    
    RECORDS_INDEX   <= stdulv(next_reg.records_index);
    RECORDS_DIN     <= cur_reg.records_din;
    RECORDS_WR_EN   <= cur_reg.records_wr_en;
    
    PENDING_RESEND_REQUESTS <= cur_reg.pending_resend_requests;
    PENDING_ACKS            <= cur_reg.pending_acks;
    
    BUSY    <= '1' when cur_reg.state/=WAITING_FOR_DATA else '0';
    
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
    
    recv_stm_proc : process(RST, cur_recv_reg)
        alias cr is cur_reg;
        variable r  : recv_reg_type := recv_reg_type_def;
    begin
        r   := cr;
        
        r.records_wr_en := '0';
        r.dout_valid    := '0';
        r.meta_wr_en    := '0';
        
        r.pending_acks  := cr.pending_acks and (cr.pending_acks xnor ACK_ACK);
        
        case cr.state is
            
            when WAITING_FOR_DATA =>
                r.checksum  := uns(PACKET_DIN);
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
                r.checksum  := cr.checksum+PACKET_DIN;
            
            when CHECKING_ACK_PACKET_NUMBER =>
                r.packet_number := uns(PACKET_DIN);
                r.checksum      := cr.checksum+PACKET_DIN;
                r.records_index := uns(PACKET_DIN);
                r.state         := COMPARING_ACK_CHECKSUM;
            
            when CHECKING_RESEND_PACKET_NUMBER =>
                r.checksum  := cr.checksum+PACKET_DIN;
            
            when COMPARING_ACK_CHECKSUM =>
                if
                    cr.checksum=PACKET_DIN and
                    RECORDS_DOUT.is_buffered and
                    RECORDS_DOUT.was_sent
                then
                    r.pending_acks(int(RECORDS_DOUT.buf_index)) := '1';
                end if;
                r.state     := WAITING_FOR_DATA;
            
        end case;
        
        if RST='1' then
            r   := recv_reg_type_def;
        end if;
        
        next_recv_reg   <= r;
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

