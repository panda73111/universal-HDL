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
    
    signal ACK_RECEIVED_ACK     : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    
    signal ACK_SENT : std_ulogic := '0';
    
    signal SEND_RECORDS_DOUT    : packet_record_type := packet_record_type_def;
    
    -- Outputs
    signal DOUT         : std_ulogic_vector(7 downto 0);
    signal DOUT_VALID   : std_ulogic;
    
    signal PENDING_RECEIVED_ACKS    : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    
    signal PENDING_ACK_TO_SEND          : std_ulogic;
    signal PENDING_ACK_PACKET_NUMBER    : std_ulogic_vector(7 downto 0);
    
    signal SEND_RECORDS_INDEX   : std_ulogic_vector(7 downto 0);
    
    signal BUSY : std_ulogic := '0';
    
    -- Clock period definitions
    constant CLK_PERIOD : time := 10 ns; -- 100 Mhz
    
    -- have one dummy packet in the virtual send buffer
    
    signal send_meta_records    : packet_meta_records_type := (
        0       => (packet_number => x"00", packet_length => x"00"),
        others  => packet_meta_record_type_def
    );
    
    signal send_packet_records  : packet_records_type := (
        0       => (1 downto 0 => '1', others => '0'),
        others  => (others => '0')
    );
    
BEGIN
    
    TRANSPORT_LAYER_RECEIVER_inst : entity work.TRANSPORT_LAYER_RECEIVER
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_IN       => PACKET_IN,
            PACKET_IN_WR_EN => PACKET_IN_WR_EN,
            
            DOUT        => DOUT,
            DOUT_VALID  => DOUT_VALID,
            
            PENDING_RECEIVED_ACKS   => PENDING_RECEIVED_ACKS,
            ACK_RECEIVED_ACK        => ACK_RECEIVED_ACK,
            
            ACK_SENT                    => ACK_SENT,
            PENDING_ACK_TO_SEND         => PENDING_ACK_TO_SEND,
            PENDING_ACK_PACKET_NUMBER   => PENDING_ACK_PACKET_NUMBER,
            
            SEND_RECORDS_DOUT   => SEND_RECORDS_DOUT,
            SEND_RECORDS_INDEX  => SEND_RECORDS_INDEX,
            
            BUSY    => BUSY
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    packet_records_proc : process(RST, CLK)
        variable packet_number  : natural range 0 to 255;
    begin
        if RST='1' then
            ACK_RECEIVED_ACK    <= (others => '0');
        elsif rising_edge(CLK) then
            ACK_RECEIVED_ACK    <= (others => '0');
            for i in BUFFERED_PACKETS-1 downto 0 loop
                if PENDING_RECEIVED_ACKS(i)='1' then
                    -- remove the acknowledged packet from the virtual send buffer
                    packet_number   := int(send_meta_records(i).packet_number);
                    send_packet_records(packet_number)  <= (others => '0');
                    ACK_RECEIVED_ACK(i) <= '1';
                end if;
            end loop;
        end if;
    end process;
    
    -- Stimulus process
    stim_proc: process
        
        procedure receive_data_packet(packet_num : in natural) is
            variable checksum   : std_ulogic_vector(7 downto 0) := x"00";
        begin
            report "Receiving packet " & natural'image(packet_num);
            PACKET_IN_WR_EN <= '1';
            -- magic
            PACKET_IN   <= DATA_MAGIC;
            wait until rising_edge(CLK);
            checksum    := PACKET_IN;
            -- packet number
            PACKET_IN   <= stdulv(packet_num, 8);
            wait until rising_edge(CLK);
            checksum    := checksum+PACKET_IN;
            -- packet length
            PACKET_IN   <= stdulv(127, 8);
            wait until rising_edge(CLK);
            checksum    := checksum+PACKET_IN;
            -- data
            for byte_i in 0 to 127 loop
                PACKET_IN   <= stdulv(packet_num mod 8, 3) & stdulv(byte_i mod 32, 5);
                wait until rising_edge(CLK);
                checksum    := checksum+PACKET_IN;
            end loop;
            -- checksum
            PACKET_IN   <= checksum;
            wait until rising_edge(CLK);
            PACKET_IN_WR_EN <= '0';
            wait until rising_edge(CLK);
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
            wait until rising_edge(CLK);
        end procedure;
        
        procedure wait_until_idle is
        begin
            if BUSY='0' then
                wait until BUSY='1';
            end if;
            wait until rising_edge(CLK) and BUSY='0';
            report "idle";
        end procedure;
        
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK) and BUSY='0';
        
        -- test 1: receive a 128 byte packet
        
        report "Starting test 1";
        receive_data_packet(0);
        wait_until_idle;
        
        wait for 100 ns;
        
        -- test 2: receive an acknowledge packet for packet #0
        
        report "Starting test 2";
        receive_acknowledge_packet(0);
        
        wait for 100 ns;
        
        -- test 3: receive 8 packets in random order
        
        report "Starting test 3";
        receive_data_packet(2);
        receive_data_packet(5);
        receive_data_packet(8);
        receive_data_packet(3);
        receive_data_packet(6);
        receive_data_packet(1);
        receive_data_packet(7);
        receive_data_packet(4);
        for i in 1 to 6 loop
            wait_until_idle;
        end loop;
        
        wait for 100 ns;
        
        -- test 4: receive 8 identical packets
        
        report "Starting test 4";
        for i in 1 to 8 loop
            receive_data_packet(9);
        end loop;
        
        wait for 100 ns;
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;
