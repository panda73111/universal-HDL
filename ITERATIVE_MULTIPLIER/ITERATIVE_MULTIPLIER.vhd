----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    14:33:55 12/31/2014 
-- Module Name:    ITERATIVE_MULTIPLIER - rtl 
-- Project Name:   ITERATIVE_MULTIPLIER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  Very simple, slow, adding multiplier
--  that needs up to MULTIPLIER+4 cycles
-- Additional Comments:
--  In case of MULTIPLICAND=0 or MULTIPLIER=0: 3 cycles (with RESULT=0)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity ITERATIVE_MULTIPLIER is
    generic (
        WIDTH   : natural := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        START   : in std_ulogic;
        
        MULTIPLICAND    : in std_ulogic_vector(WIDTH-1 downto 0);
        MULTIPLIER      : in std_ulogic_vector(WIDTH-1 downto 0);
        
        VALID   : out std_ulogic;
        RESULT  : out std_ulogic_vector(2*WIDTH-1 downto 0)
    );  
end ITERATIVE_MULTIPLIER;
    
architecture rtl of ITERATIVE_MULTIPLIER is
    
    type state_type is (
        WAIT_FOR_START,
        CHECK_FOR_FACTOR_ZERO,
        CALCULATE,
        FINISH
    );
    
    type reg_type is record
        state       : state_type;
        valid       : std_ulogic;
        remainder   : unsigned(WIDTH-1 downto 0);
        result      : unsigned(2*WIDTH-1 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => WAIT_FOR_START,
        valid       => '0',
        remainder   => (others => '0'),
        result      => (others => '0')
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    VALID   <= cur_reg.valid;
    RESULT  <= stdulv(cur_reg.result);
    
    stm_proc : process(RST, cur_reg, START, MULTIPLICAND, MULTIPLIER)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r       := cr;
        r.valid := '0';
        
        case cr.state is
            
            when WAIT_FOR_START =>
                r.remainder := (others => '0');
                r.result    := (others => '0');
                if START='1' then
                    r.state := CHECK_FOR_FACTOR_ZERO;
                end if;
            
            when CHECK_FOR_FACTOR_ZERO =>
                r.state := CALCULATE;
                if
                    MULTIPLICAND=(MULTIPLICAND'range => '0') or
                    MULTIPLIER=(MULTIPLIER'range => '0')
                then
                    r.state := FINISH;
                end if;
            
            when CALCULATE =>
                if cr.remainder < MULTIPLIER then
                    r.remainder := cr.remainder+1;
                    r.result    := cr.result+MULTIPLICAND;
                else
                    r.state := FINISH;
                end if;
            
            when FINISH =>
                r.valid := '1';
                r.state := WAIT_FOR_START;
            
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

