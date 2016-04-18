--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   15:34:10 03/02/2015
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

ENTITY TRANSPORT_LAYER_tb IS
END TRANSPORT_LAYER_tb;

ARCHITECTURE behavior OF TRANSPORT_LAYER_tb IS 
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal DIN          : std_ulogic_vector(7 downto 0) := x"00";
    signal DIN_WR_EN    : std_ulogic := '0';
    signal SEND_PACKET  : std_ulogic := '0';
    
    signal PACKET_IN        : std_ulogic_vector(7 downto 0) := x"00";
    signal PACKET_IN_WR_EN  : std_ulogic := '0';
    
    -- Outputs
    signal PACKET_OUT       : std_ulogic_vector(7 downto 0);
    signal PACKET_OUT_VALID : std_ulogic;
    signal PACKET_OUT_END   : std_ulogic;
    
    signal DOUT         : std_ulogic_vector(7 downto 0);
    signal DOUT_VALID   : std_ulogic;
    
    signal BUSY : std_ulogic := '0';
    
    -- Clock period definitions
    constant CLK_PERIOD         : time := 10 ns; -- 100 Mhz
    constant CLK_PERIOD_REAL    : real := real(CLK_PERIOD / 1 ps) / real(1 ns / 1 ps);
    
BEGIN
    
    TRANSPORT_LAYER_inst : entity work.TRANSPORT_LAYER
        generic map (
            CLK_IN_PERIOD   => CLK_PERIOD_REAL
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_IN       => PACKET_IN,
            PACKET_IN_WR_EN => PACKET_IN_WR_EN,
            
            PACKET_OUT          => PACKET_OUT,
            PACKET_OUT_VALID    => PACKET_OUT_VALID,
            PACKET_OUT_END      => PACKET_OUT_END,
            
            DIN         => DIN,
            DIN_WR_EN   => DIN_WR_EN,
            SEND_PACKET => SEND_PACKET,
            
            DOUT        => DOUT,
            DOUT_VALID  => DOUT_VALID,
            
            BUSY    => BUSY
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
        
        procedure send_data_packet(
            packet_num      : in natural;
            wait_for_idle   : in boolean;
            set_send_packet : in boolean)
        is
        begin
            DIN_WR_EN   <= '1';
            for byte_i in 0 to 127 loop
                DIN <= stdulv(packet_num mod 8, 3) & stdulv(byte_i mod 32, 5);
                if byte_i=127 and set_send_packet then
                    SEND_PACKET <= '1';
                end if;
                wait until rising_edge(CLK);
            end loop;
            DIN_WR_EN   <= '0';
            SEND_PACKET <= '0';
            if wait_for_idle then
                wait until falling_edge(BUSY);
            end if;
        end procedure;
        
        procedure send_data_packet(
            packet_num  : in natural;
            set_send_packet : in boolean)
        is
        begin
            send_data_packet(packet_num, true, true);
        end procedure;
        
        procedure send_data_packet(packet_num : in natural) is
        begin
            send_data_packet(packet_num, true);
        end procedure;
        
        procedure receive_data_packet(packet_num : in natural) is
            variable checksum   : std_ulogic_vector(7 downto 0) := x"00";
        begin
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
        
        procedure wait_for_readout is
        begin
            if BUSY='0' then
                wait until BUSY='1';
            end if;
            wait until falling_edge(BUSY);
        end procedure;
        
    begin
        RST <= '1';
        wait for 500 ns;
        RST <= '0';
        wait for 500 ns;
        wait until falling_edge(BUSY);
        
        wait for 500 ns;
        
        -- test 1: receive a 128 byte packet
        
        report "Starting test 1";
        receive_data_packet(0);
        wait_for_readout;
        
        wait for 500 ns;
        
        -- test 2: send a packet and receive a resend request packet
        
        report "Starting test 2";
        send_data_packet(0);
        receive_resend_request_packet(0);
        
        wait for 500 ns;
        
        -- test 3: receive an acknowledge packet for packet #0
        
        report "Starting test 3";
        receive_acknowledge_packet(0);
        
        wait for 500 ns;
        
        -- test 4: receive 8 packets in random order
        
        report "Starting test 4";
        receive_data_packet(2);
        receive_data_packet(5);
        receive_data_packet(8);
        receive_data_packet(3);
        receive_data_packet(6);
        receive_data_packet(1);
        receive_data_packet(7);
        receive_data_packet(4);
        for i in 1 to 8 loop
            wait_for_readout;
        end loop;
        
        wait for 500 ns;
        
        -- test 5: receive 8 identical packets
        
        report "Starting test 5";
        for i in 1 to 8 loop
            receive_data_packet(9);
        end loop;
        
        wait for 500 ns;
        
        -- test 6: try sending an empty packet
        
        report "Starting test 6";
        SEND_PACKET <= '1';
        wait until rising_edge(CLK);
        SEND_PACKET <= '0';
        wait until rising_edge(CLK);
        
        wait for 500 ns;
        
        -- test 7: send two 256 byte packets without pause
        
        report "Starting test 7";
        send_data_packet(10, false);
        send_data_packet(11);
        wait until falling_edge(BUSY);
        
        wait for 500 ns;
        
        -- test 8: send 1024 byte without setting SEND_PACKET='1' between each 256 byte block
        
        report "Starting test 8";
        send_data_packet(12, false, false);
        send_data_packet(13, false, false);
        send_data_packet(14, false, false);
        send_data_packet(15, false, false);
        send_data_packet(16, false, false);
        send_data_packet(17, false, false);
        send_data_packet(18, false, false);
        send_data_packet(19);
        wait until falling_edge(BUSY);
        
        wait for 500 ns;
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;

