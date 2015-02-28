--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   15:57:16 02/27/2015
-- Module Name:   TRANSPORT_LAYER_SENDER_tb
-- Project Name:  TRANSPORT_LAYER_SENDER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: TRANSPORT_LAYER_SENDER
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.TRANSPORT_LAYER_PKG.all;
use work.help_funcs.all;
use work.txt_util.all;

ENTITY TRANSPORT_LAYER_RECEIVER_tb IS
END TRANSPORT_LAYER_RECEIVER_tb;

ARCHITECTURE behavior OF TRANSPORT_LAYER_RECEIVER_tb IS 
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal PACKET_IN        : std_ulogic_vector(7 downto 0) := x"00";
    signal PACKET_IN_WR_EN  : std_ulogic := '0';
    
    signal RESEND_REQUEST_ACK   : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    signal ACK_ACK              : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    
    signal RECORDS_DOUT : packet_record_type := packet_record_type_def;
    
    -- Outputs
    signal DOUT         : std_ulogic_vector(7 downto 0);
    signal DOUT_VALID   : std_ulogic;
    
    signal PENDING_RESEND_REQUESTS  : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    signal PENDING_ACKS             : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    
    signal RECORDS_INDEX    : std_ulogic_vector(7 downto 0);
    signal RECORDS_DIN      : packet_record_type;
    signal RECORDS_WR_EN    : std_ulogic;
    
    signal BUSY : std_ulogic := '0';
    
    -- Clock period definitions
    constant CLK_PERIOD : time := 10 ns; -- 100 Mhz
    
    signal packet_number    : unsigned(7 downto 0) := x"00";
    
BEGIN
    
    TRANSPORT_LAYER_RECEIVER_inst : entity work.TRANSPORT_LAYER_RECEIVER
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_IN       => PACKET_IN,
            PACKET_IN_WR_EN => PACKET_IN_WR_EN,
            
            DOUT        => DOUT,
            DOUT_VALID  => DOUT_VALID,
            
            RESEND_REQUEST_ACK      => RESEND_REQUEST_ACK,
            PENDING_RESEND_REQUESTS => PENDING_RESEND_REQUESTS,
            
            ACK_ACK         => ACK_ACK,
            PENDING_ACKS    => PENDING_ACKS,
            
            RECORDS_INDEX   => RECORDS_INDEX,
            RECORDS_DOUT    => RECORDS_DOUT,
            RECORDS_DIN     => RECORDS_DIN,
            RECORDS_WR_EN   => RECORDS_WR_EN,
            
            BUSY    => BUSY
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
        
        procedure receive_data_packet(pkt_i : in natural) is
            variable checksum   : std_ulogic_vector(7 downto 0) := x"00";
        begin
            PACKET_IN_WR_EN <= '1';
            -- magic
            PACKET_IN   <= DATA_MAGIC;
            wait until rising_edge(CLK);
            checksum    := PACKET_IN;
            -- packet number
            PACKET_IN   <= stdulv(packet_number);
            wait until rising_edge(CLK);
            checksum    := checksum+PACKET_IN;
            -- packet length
            PACKET_IN   <= stdulv(128, 8);
            wait until rising_edge(CLK);
            checksum    := checksum+PACKET_IN;
            -- data
            for byte_i in 0 to 127 loop
                PACKET_IN   <= stdulv(pkt_i mod 8, 3) & stdulv(byte_i mod 32, 5);
                wait until rising_edge(CLK);
                checksum    := checksum+PACKET_IN;
            end loop;
            -- checksum
            PACKET_IN   <= checksum;
            wait until rising_edge(CLK);
            PACKET_IN_WR_EN <= '0';
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
        procedure receive_resend_request_packet(packet_num : in natural) is
            variable checksum   : std_ulogic_vector(7 downto 0) := x"00";
        begin
            PACKET_IN_WR_EN <= '1';
            -- magic
            PACKET_IN   <= RESEND_MAGIC;
            wait until rising_edge(CLK);
            checksum    := PACKET_IN;
            -- packet number
            PACKET_IN   <= stdulv(packet_num, 8);
            wait until rising_edge(CLK);
            checksum    := checksum+PACKET_IN;
            -- checksum
            PACKET_IN   <= checksum;
            wait until rising_edge(CLK);
            PACKET_IN_WR_EN <= '0';
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
        procedure receive_acknowledge_packet(packet_num : in natural) is
            variable checksum   : std_ulogic_vector(7 downto 0) := x"00";
        begin
            PACKET_IN_WR_EN <= '1';
            -- magic
            PACKET_IN   <= ACK_MAGIC;
            wait until rising_edge(CLK);
            checksum    := PACKET_IN;
            -- packet number
            PACKET_IN   <= stdulv(packet_num, 8);
            wait until rising_edge(CLK);
            checksum    := checksum+PACKET_IN;
            -- checksum
            PACKET_IN   <= checksum;
            wait until rising_edge(CLK);
            PACKET_IN_WR_EN <= '0';
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
        procedure wait_for_readout is
        begin
            if BUSY='0' then
                wait until BUSY='1';
            end if;
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK);
        
        -- test 1: receive a 128 byte packet
        
        report "Starting test 1";
        receive_data_packet(0);
        wait_for_readout;
        
        wait for 100 ns;
        
        -- test 2: receive a resend request packet for packer #0
        
        report "Starting test 2";
        receive_resend_request_packet(0);
        
        wait for 100 ns;
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;
