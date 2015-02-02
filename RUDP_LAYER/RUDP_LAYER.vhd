----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    10:15:34 02/02/2015 
-- Module Name:    RUDP_LAYER - rtl 
-- Project Name:   RUDP_LAYER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  
-- Additional Comments:
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RUDP_LAYER is
    generic (
        LARGEST_SENDABLE_SEGMENT    : positive := 128;
        LARGEST_RECEIVABLE_SEGMENT  : positive := 128;
        MAX_UNACK_SEGMENT_COUNT     : positive := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PASSIVE_OPEN    : in std_ulogic;
        ACTIVE_OPEN     : in std_ulogic;
        
        RUDP_IN         : in std_ulogic_vector(7 downto 0);
        RUDP_IN_WR_EN   : in std_ulogic;
        
        RUDP_OUT        : out std_ulogic_vector(7 downto 0) := x"00";
        RUDP_OUT_VALID  : out std_ulogic := '0';
        
        DIN         : in std_ulogic_vector(7 downto 0);
        DIN_WR_EN   : in std_ulogic;
        SEND        : in std_ulogic;
        
        DOUT        : out std_ulogic_vector(7 downto 0) := x"00";
        DOUT_VALID  : out std_ulogic := '0'
    );
end RUDP_LAYER;

architecture rtl of RUDP_LAYER is
    
    type state_type is (
        CLOSED,
        LISTENING,
        SYN_SENT,
        SYN_RECEIVED,
        OPENED,
        WAITING_FOR_CLOSING
    );
    
    type reg_type is record
        state               : state_type;
        rudp_out            : std_ulogic_vector(7 downto 0);
        rudp_out_valid      : std_ulogic;
        next_segment_num    : unsigned(31 downto 0);
        oldest_unack_num    : unsigned(31 downto 0);
        max_unack_count     : unsigned(31 downto 0);
        init_send_num       : unsigned(31 downto 0);
        last_received_num   : unsigned(31 downto 0);
        max_buf_count       : unsigned(31 downto 0);
        init_receive_num    : unsigned(31 downto 0);
        close_timer         : unsigned(31 downto 0);
        cur_segment_num     : unsigned(31 downto 0);
        cur_ack_num         : unsigned(31 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state               => CLOSED,
        next_segment_num    => x"0000_0000",
        oldest_unack_num    => x"0000_0000",
        max_unack_num       => x"0000_0000",
        init_send_num       => x"0000_0000",
        last_received_num   => x"0000_0000",
        max_buf_count       => x"0000_0000",
        init_receive_num    => x"0000_0000",
        close_timer         => x"0000_0000",
        cur_segment_num     => x"0000_0000",
        cur_ack_num         => x"0000_0000"
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    RUDP_OUT        <= cur_reg.rudp_out;
    RUDP_OUT_VALID  <= cur_reg.rudp_out_valid;
    
    stm_proc : process(RST, cur_reg)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        r.udp_out_valid := '0';
        
        case cr.state is
            
            when CLOSED =>
                
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        
        next_reg    <= r;
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
