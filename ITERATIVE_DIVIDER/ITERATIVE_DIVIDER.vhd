----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    17:39:05 12/30/2014 
-- Module Name:    ITERATIVE_DIVIDER - rtl 
-- Project Name:   ITERATIVE_DIVIDER
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  http://www.lothar-miller.de/s9y/archives/29-Division-in-VHDL.html
-- Additional Comments:
--  In case of DIVISOR=0:        3 cycles (with ERROR='1')
--  In case of DIVISOR>DIVIDEND: 3 cycles (with QUOTIENT=0, REMAINDER=DIVISOR)
--  Else:                        [WIDTH]+5 cycles
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity ITERATIVE_DIVIDER is
    generic (
        WIDTH   : positive range 4 to 64 := 8
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        START   : in std_ulogic;
        
        DIVIDEND    : in std_ulogic_vector(WIDTH-1 downto 0);
        DIVISOR     : in std_ulogic_vector(WIDTH-1 downto 0);
        
        BUSY    : out std_ulogic;
        VALID   : out std_ulogic;
        ERROR   : out std_ulogic;
        
        QUOTIENT    : out std_ulogic_vector(WIDTH-1 downto 0);
        REMAINDER   : out std_ulogic_vector(WIDTH-1 downto 0)
    );  
end ITERATIVE_DIVIDER;
    
architecture rtl of ITERATIVE_DIVIDER is
    
    type state_type is (
        WAITING_FOR_START,
        CHECKING_DIVISOR,
        SHIFTING,
        SUBTRACTING,
        FINISHING,
        DIVISION_BY_ZERO
    );
    
    type reg_type is record
        state       : state_type;
        valid       : std_ulogic;
        error       : std_ulogic;
        divisor     : unsigned(WIDTH-1 downto 0);
        dividend    : unsigned(WIDTH-1 downto 0);
        quotient    : unsigned(WIDTH-1 downto 0);
        remainder   : unsigned(WIDTH-1 downto 0);
        bits        : natural range 0 to WIDTH;
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => WAITING_FOR_START,
        valid       => '0',
        error       => '0',
        divisor     => (others => '0'),
        dividend    => (others => '0'),
        quotient    => (others => '0'),
        remainder   => (others => '0'),
        bits        => WIDTH
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    signal shifted_remainder    : unsigned(WIDTH-1 downto 0) := (others => '0');
    signal shifted_dividend     : unsigned(WIDTH-1 downto 0) := (others => '0');
    signal difference           : unsigned(WIDTH-1 downto 0) := (others => '0');
    
begin
    
    BUSY    <= '0' when cur_reg.state=WAITING_FOR_START else '1';
    VALID   <= cur_reg.valid;
    ERROR   <= cur_reg.error;
    
    QUOTIENT    <= stdulv(cur_reg.quotient);
    REMAINDER   <= stdulv(cur_reg.remainder);
    
    shifted_remainder   <= cur_reg.remainder(WIDTH-2 downto 0) & cur_reg.dividend(WIDTH-1);
    shifted_dividend    <= cur_reg.dividend(WIDTH-2 downto 0) & '0';
    difference          <= shifted_remainder-cur_reg.divisor;
    
    stm_proc : process(RST, cur_reg, START, DIVIDEND, DIVISOR,
        shifted_remainder, shifted_dividend, difference)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r       := cr;
        r.valid := '0';
        r.error := '0';
        
        case cr.state is
            
            when WAITING_FOR_START =>
                if START='1' then
                    r.state := CHECKING_DIVISOR;
                end if;
            
            when CHECKING_DIVISOR =>
                r.divisor   := uns(DIVISOR);
                r.dividend  := uns(DIVIDEND);
                r.quotient  := (others => '0');
                r.remainder := (others => '0');
                r.bits      := WIDTH;
                
                r.state := SHIFTING;
                if DIVISOR=(DIVISOR'range => '0') then
                    r.state := DIVISION_BY_ZERO;
                end if;
                if DIVISOR > DIVIDEND then
                    -- quotient is less than 1
                    r.remainder := uns(DIVIDEND);
                    r.state     := FINISHING;
                end if;
            
            when SHIFTING =>
                if shifted_remainder < cr.divisor then
                    r.bits      := cr.bits-1;
                    r.remainder := shifted_remainder;
                    r.dividend  := shifted_dividend;
                else
                    r.state := SUBTRACTING;
                end if;
            
            when SUBTRACTING =>
                if cr.bits=0 then
                    r.state := FINISHING;
                else
                    r.remainder := shifted_remainder;
                    r.dividend  := shifted_dividend;
                    if difference(WIDTH-1)='1' then
                        r.quotient  := cr.quotient(WIDTH-2 downto 0) & '0';
                    else
                        r.quotient  := cr.quotient(WIDTH-2 downto 0) & '1';
                        r.remainder := difference;
                    end if;
                    r.bits  := cr.bits-1;
                end if;
            
            when FINISHING =>
                r.valid     := '1';
                r.state     := WAITING_FOR_START;
            
            when DIVISION_BY_ZERO =>
                r.error := '1';
                r.state := WAITING_FOR_START;
            
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

