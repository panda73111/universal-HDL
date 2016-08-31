----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    17:39:05 12/30/2014 
-- Module Name:    ITERATIVE_DIVIDER - rtl 
-- Project Name:   ITERATIVE_DIVIDER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  Very simple, slow, subtracting divider
--  that needs up to DIVIDEND/DIVISOR+5 cycles
-- Additional Comments:
--  In case of DIVISOR=0:        3 cycles (with ERROR='1')
--  In case of DIVISOR>DIVIDEND: 4 cycles (with RESULT=0)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity ITERATIVE_DIVIDER is
    generic (
        WIDTH   : natural := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        START   : in std_ulogic;
        
        DIVIDEND    : in std_ulogic_vector(WIDTH-1 downto 0);
        DIVISOR     : in std_ulogic_vector(WIDTH-1 downto 0);
        
        VALID   : out std_ulogic;
        ERROR   : out std_ulogic;
        RESULT  : out std_ulogic_vector(WIDTH-1 downto 0)
    );  
end ITERATIVE_DIVIDER;
    
architecture rtl of ITERATIVE_DIVIDER is
    
    type state_type is (
        WAIT_FOR_START,
        CHECK_FOR_DIVISOR_ZERO,
        CHECK_FOR_RESULT_ZERO,
        CALCULATE,
        FINISH,
        DIVISION_BY_ZERO
    );
    
    type reg_type is record
        state       : state_type;
        valid       : std_ulogic;
        error       : std_ulogic;
        remainder   : unsigned(WIDTH-1 downto 0);
        temp        : unsigned(WIDTH-1 downto 0);
        result      : unsigned(WIDTH-1 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => WAIT_FOR_START,
        valid       => '0',
        error       => '0',
        remainder   => (others => '0'),
        temp        => (others => '0'),
        result      => (others => '0')
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    VALID   <= cur_reg.valid;
    ERROR   <= cur_reg.error;
    RESULT  <= stdulv(cur_reg.result);
    
    stm_proc : process(RST, cur_reg, START, DIVIDEND, DIVISOR)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r       := cr;
        r.valid := '0';
        r.error := '0';
        
        case cr.state is
            
            when WAIT_FOR_START =>
                r.remainder := (others => '0');
                r.temp      := (others => '0');
                if START='1' then
                    r.state := CHECK_FOR_DIVISOR_ZERO;
                end if;
            
            when CHECK_FOR_DIVISOR_ZERO =>
                r.state := CHECK_FOR_RESULT_ZERO;
                if DIVISOR=(DIVISOR'range => '0') then
                    r.state := DIVISION_BY_ZERO;
                end if;
            
            when CHECK_FOR_RESULT_ZERO =>
                r.state := CALCULATE;
                if DIVISOR > DIVIDEND then
                    r.state := FINISH;
                end if;
            
            when CALCULATE =>
                if cr.remainder <= DIVIDEND-DIVISOR then
                    r.remainder := cr.remainder+DIVISOR;
                    r.temp      := cr.temp+1;
                else
                    r.state := FINISH;
                end if;
            
            when FINISH =>
                r.valid     := '1';
                r.result    := cr.temp;
                r.state     := WAIT_FOR_START;
            
            when DIVISION_BY_ZERO =>
                r.error := '1';
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

