--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   16:39:40 2/15/2015
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
    
    signal RECORDS_DOUT : packet_record_type := packet_record_type_def;
    
    -- Outputs
    signal PACKET_OUT       : std_ulogic_vector(7 downto 0);
    signal PACKET_OUT_VALID : std_ulogic;
    
    signal RESEND_REQUEST_ACK   : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    signal ACK_ACK              : std_ulogic_vector(BUFFERED_PACKETS-1 downto 0);
    
    signal RECORDS_INDEX    : std_ulogic_vector(7 downto 0);
    signal RECORDS_DIN      : packet_record_type;
    signal RECORDS_WR_EN    : std_ulogic;
    
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
            
            RECORDS_INDEX   => RECORDS_INDEX,
            RECORDS_DOUT    => RECORDS_DOUT,
            RECORDS_DIN     => RECORDS_DIN,
            RECORDS_WR_EN   => RECORDS_WR_EN,
            
            BUSY    => BUSY
        );
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    -- Stimulus process
    stim_proc: process
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK);
        
        -- test 1: send a 128 byte packet
        
        for byte_i in 0 to 127 loop
            DIN         <= stdulv(byte_i, 8);
            DIN_WR_EN   <= '1';
            wait until rising_edge(CLK);
        end loop;
        DIN_WR_EN   <= '0';
        SEND        <= '1';
        wait until rising_edge(CLK);
        SEND    <= '0';
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        
        -- test 2: resend the previous packet by resend request
        
        PENDING_RESEND_REQUESTS(0)  <= '1';
        wait until rising_edge(CLK) and RESEND_REQUEST_ACK(0)='1';
        PENDING_RESEND_REQUESTS(0)  <= '0';
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        
        -- test 3: resend the previous packet by timeout
        
        wait until rising_edge(CLK) and BUSY='1';
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        
        -- test 4: acknowledge the previous packet
        
        PENDING_ACKS(0) <= '1';
        wait until rising_edge(CLK) and ACK_ACK(0)='1';
        PENDING_ACKS(0) <= '0';
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
    end process;
    
END;
