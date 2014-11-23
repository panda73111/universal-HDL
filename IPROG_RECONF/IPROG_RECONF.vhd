----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    19:22:34 11/23/2014 
-- Module Name:    IPROG_RECONF - rtl 
-- Project Name:   IPROG_RECONF
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--  
-- Additional Comments: 
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;
use work.help_funcs.all;

entity IPROG_RECONF is
    generic (
        START_ADDR      : std_ulogic_vector(23 downto 0);
        FALLBACK_ADDR   : std_ulogic_vector(23 downto 0);
        OPCODE_READ     : std_ulogic_vector(7 downto 0) := x"0B"
    );
    port (
        CLK : in std_ulogic;
        
        EN  : in std_ulogic
    );
end IPROG_RECONF;

architecture rtl of IPROG_RECONF is
    type state_type is (
        IDLE,
        SEND_DUMMY_WORD,
        SEND_SYNC_WORD_1,
        SEND_SYNC_WORD_2,
        SEND_CMD_WRITE1_GEN1,
        SEND_MULTI_ADDR_LOW,
        SEND_CMD_WRITE1_GEN2,
        SEND_MULTI_ADDR_HIGH_OPCODE,
        SEND_CMD_WRITE1_GEN3,
        SEND_FALLBACK_ADDR_LOW,
        SEND_CMD_WRITE1_GEN4,
        SEND_FALLBACK_ADDR_HIGH_OPCODE,
        SEND_CMD_WRITE1_CMD,
        SEND_IPROG_CMD,
        SEND_CMD_NOOP,
        WAIT_FOR_RECONF
    );
    
    type reg_type is record
        state       : state_type;
        icap_i      : std_ulogic_vector(15 downto 0);
        icap_en     : std_ulogic;
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => IDLE,
        icap_i      => x"0000",
        icap_en     => '1'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;    
begin
    
    ICAP_SPARTAN6_inst : ICAP_SPARTAN6
        port map (
            CLK => CLK,
            
            I       => stdlv(cur_reg.icap_i),
            CE      => cur_reg.icap_en,
            WRITE   => '0', -- write mode
            
            O       => open,
            BUSY    => open
        );
    
    stm_proc : process(EN)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        case cr.state is
            
            when IDLE =>
                if EN='1' then
                    r.state := SEND_DUMMY_WORD;
                end if;
            
            when SEND_DUMMY_WORD =>
                r.icap_en   := '0';
                r.icap_i    := x"FFFF";
                r.state     := SEND_SYNC_WORD_1;
            
            when SEND_SYNC_WORD_1 =>
                r.icap_i    := x"AA99";
                r.state     := SEND_SYNC_WORD_2;
            
            when SEND_SYNC_WORD_2 =>
                r.icap_i    := x"5566";
                r.state     := SEND_CMD_WRITE1_GEN1;
            
            when SEND_CMD_WRITE1_GEN1 =>
                r.icap_i    := x"3261";
                r.state     := SEND_MULTI_ADDR_LOW;
            
            when SEND_MULTI_ADDR_LOW =>
                r.icap_i    := START_ADDR(15 downto 0);
                r.state     := SEND_CMD_WRITE1_GEN2;
            
            when SEND_CMD_WRITE1_GEN2 =>
                r.icap_i    := x"3281";
                r.state     := SEND_MULTI_ADDR_HIGH_OPCODE;
            
            when SEND_MULTI_ADDR_HIGH_OPCODE =>
                r.icap_i    := OPCODE_READ & START_ADDR(23 downto 16);
                r.state     := SEND_CMD_WRITE1_GEN3;
            
            when SEND_CMD_WRITE1_GEN3 =>
                r.icap_i    := x"32A1";
                r.state     := SEND_FALLBACK_ADDR_LOW;
            
            when SEND_FALLBACK_ADDR_LOW =>
                r.icap_i    := FALLBACK_ADDR(15 downto 0);
                r.state     := SEND_CMD_WRITE1_GEN4;
            
            when SEND_CMD_WRITE1_GEN4 =>
                r.icap_i    := x"32C1";
                r.state     := SEND_FALLBACK_ADDR_HIGH_OPCODE;
            
            when SEND_FALLBACK_ADDR_HIGH_OPCODE =>
                r.icap_i    := OPCODE_READ & FALLBACK_ADDR(23 downto 16);
                r.state     := SEND_CMD_WRITE1_CMD;
            
            when SEND_CMD_WRITE1_CMD =>
                r.icap_i    := x"30A1";
                r.state     := SEND_IPROG_CMD;
            
            when SEND_IPROG_CMD =>
                r.icap_i    := x"000E";
                r.state     := SEND_CMD_NOOP;
            
            when SEND_CMD_NOOP =>
                r.icap_i    := x"2000";
                r.state     := WAIT_FOR_RECONF;
            
            when WAIT_FOR_RECONF =>
                null;
            
        end case;
        
        next_reg    <= r;
    end process;
    
    stm_sync_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

