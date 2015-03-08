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
    constant CLK_PERIOD : time := 10 ns; -- 100 Mhz
    
BEGIN
    
    TRANSPORT_LAYER_inst : entity work.TRANSPORT_LAYER
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
        
        procedure send_packet(packet_num : in natural) is
        begin
            DIN_WR_EN   <= '1';
            for byte_i in 0 to 127 loop
                DIN <= stdulv(packet_num mod 8, 3) & stdulv(byte_i mod 32, 5);
                wait until rising_edge(CLK);
            end loop;
            DIN_WR_EN   <= '0';
            SEND_PACKET <= '1';
            wait until rising_edge(CLK);
            SEND_PACKET <= '0';
            wait until rising_edge(CLK) and BUSY='0';
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
            PACKET_IN   <= stdulv(128, 8);
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
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        
        -- test 1: receive a 128 byte packet
        
        report "Starting test 1";
        receive_data_packet(0);
        wait_for_readout;
        
        wait for 100 ns;
        
        -- test 2: send a packet and receive a resend request packet
        
        report "Starting test 2";
        send_packet(0);
        receive_resend_request_packet(0);
        
        wait for 100 ns;
        
        -- test 3: receive an acknowledge packet for packet #0
        
        report "Starting test 3";
        receive_acknowledge_packet(0);
        
        wait for 100 ns;
        
        -- test 4: receive 8 packets in random order
        
        report "Starting test 4";
        receive_data_packet(2);
        receive_data_packet(5);
        receive_data_packet(8);
        receive_data_packet(3);
        receive_data_packet(6);
        receive_data_packet(4);
        receive_data_packet(7);
        receive_data_packet(1);
        wait_for_readout;
        wait_for_readout;
        wait_for_readout;
        wait_for_readout;
        wait_for_readout;
        wait_for_readout;
        wait_for_readout;
        wait_for_readout;
        
        wait for 100 ns;
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;

