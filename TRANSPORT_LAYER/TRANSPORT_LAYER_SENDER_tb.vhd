--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   16:39:40 02/15/2015
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

ENTITY TRANSPORT_LAYER_SENDER_tb IS
END TRANSPORT_LAYER_SENDER_tb;

ARCHITECTURE behavior OF TRANSPORT_LAYER_SENDER_tb IS 
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal DIN          : std_ulogic_vector(7 downto 0) := x"00";
    signal DIN_WR_EN    : std_ulogic := '0';
    signal SEND         : std_ulogic := '0';
    
    signal PENDING_RESEND_REQUESTS  : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    signal PENDING_ACKS             : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0) := (others => '0');
    
    signal SEND_RECORDS_INDEX   : std_ulogic_vector(7 downto 0) := x"00";
    
    -- Outputs
    signal PACKET_OUT       : std_ulogic_vector(7 downto 0);
    signal PACKET_OUT_VALID : std_ulogic;
    
    signal RESEND_REQUEST_ACK   : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    signal ACK_ACK              : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    
    signal SEND_RECORDS_DOUT    : packet_record_type;
    
    signal BUSY : std_ulogic := '0';
    
    -- Clock period definitions
    constant CLK_PERIOD : time := 10 ns; -- 100 Mhz
    
BEGIN
    
    TRANSPORT_LAYER_SENDER_inst : entity work.TRANSPORT_LAYER_SENDER
        port map (
            CLK => CLK,
            RST => RST,
            
            PACKET_OUT          => PACKET_OUT,
            PACKET_OUT_VALID    => PACKET_OUT_VALID,
            
            DIN         => DIN,
            DIN_WR_EN   => DIN_WR_EN,
            SEND        => SEND,
            
            PENDING_RESEND_REQUESTS => PENDING_RESEND_REQUESTS,
            RESEND_REQUEST_ACK      => RESEND_REQUEST_ACK,
            
            PENDING_ACKS    => PENDING_ACKS,
            ACK_ACK         => ACK_ACK,
            
            SEND_RECORDS_INDEX  => SEND_RECORDS_INDEX,
            SEND_RECORDS_DOUT   => SEND_RECORDS_DOUT,
            
            BUSY    => BUSY
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
        
        procedure send_packet(pkt_i : in natural) is
        begin
            DIN_WR_EN   <= '1';
            for byte_i in 0 to 127 loop
                DIN         <= stdulv(pkt_i mod 8, 3) & stdulv(byte_i mod 32, 5);
                wait until rising_edge(CLK);
            end loop;
            DIN_WR_EN   <= '0';
            SEND        <= '1';
            wait until rising_edge(CLK);
            SEND    <= '0';
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
        procedure request_resend(buf_i : in natural) is
        begin
            PENDING_RESEND_REQUESTS(buf_i)  <= '1';
            wait until rising_edge(CLK) and RESEND_REQUEST_ACK(buf_i)='1';
            PENDING_RESEND_REQUESTS(buf_i)  <= '0';
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
        procedure acknowledge(buf_i : in natural) is
        begin
            PENDING_ACKS(buf_i) <= '1';
            wait until rising_edge(CLK) and ACK_ACK(buf_i)='1';
            PENDING_ACKS(buf_i) <= '0';
            wait until rising_edge(CLK) and BUSY='0';
        end procedure;
        
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK);
        
        -- test 1: send a 128 byte packet
        
        report "Starting test 1";
        send_packet(0);
        
        wait for 100 ns;
        
        -- test 2: resend the previous packet by resend request
        
        report "Starting test 2";
        request_resend(0);
        
        wait for 100 ns;
        
        -- test 3: resend the previous packet by timeout
        
        report "Starting test 3";
        wait until rising_edge(CLK) and BUSY='1';
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        
        -- test 4: acknowledge the previous packet
        
        report "Starting test 4";
        acknowledge(0);
        
        wait for 100 ns;
        
        -- test 5: fill the packet buffer
        
        report "Starting test 5";
        for packet_i in 0 to 7 loop
            send_packet(packet_i+1);
        end loop;
        
        wait for 100 ns;
        
        -- test 6: request a resend for each packet
        
        report "Starting test 6";
        for packet_i in 0 to 7 loop
            request_resend(packet_i);
        end loop;
        
        wait for 100 ns;
        
        -- test 7: acknowledge all packets
        
        report "Starting test 7";
        for packet_i in 0 to 7 loop
            acknowledge(packet_i);
        end loop;
        
        wait for 100 ns;
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;
