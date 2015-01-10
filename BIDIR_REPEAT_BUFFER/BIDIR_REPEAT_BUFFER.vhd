----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    08:47:55 11/13/2014 
-- Module Name:    BIDIR_REPEAT_BUFFER - Behavioral 
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--  Bidirectional buffer working as a repeater, including debounce logic
--  for weak pullups/pulldowns, so that after releasing the signal, the
--  input buffer doesn't read the own pulled signal level and deadlocks
-- Additional Comments: 
--  generics:
--   PULL               : "UP"/"DOWN", sets the signal level when floating
--   DEBOUNCE_CYCLES    : how many clock cycles the buffer waits until re-reading
--  ports:
--   CLK    : input clock
--   P0_IN  : first port input
--   P0_OUT : first port output
--   P1_IN  : second port input
--   P1_OUT : second port output
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity BIDIR_REPEAT_BUFFER is
    generic (
        PULL            : string := "UP";
        DEBOUNCE_CYCLES : natural := 5
    );
    port (
        CLK : in std_ulogic;
        
        P0_IN   : in std_ulogic;
        P0_OUT  : out std_ulogic := 'Z';
        P1_IN   : in std_ulogic;
        P1_OUT  : out std_ulogic := 'Z'
    );
end BIDIR_REPEAT_BUFFER;

architecture Behavioral of BIDIR_REPEAT_BUFFER is
    
    constant FLOATING_LEVEL : std_ulogic := sel(PULL="UP", '1', '0');
    constant DRIVING_LEVEL  : std_ulogic := not FLOATING_LEVEL;
    constant CYCLE_BITS     : natural := log2(DEBOUNCE_CYCLES)+1;
    
    type state_type is (
        FLOATING,
        P0_DRIVING,
        P1_DRIVING,
        DEBOUNCING
    );
    
    type reg_type is record
        state       : state_type;
        p0_out      : std_ulogic;
        p1_out      : std_ulogic;
        cycle_cnt   : unsigned(CYCLE_BITS-1 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => FLOATING,
        p0_out      => 'Z',
        p1_out      => 'Z',
        cycle_cnt   => (others => '0')
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
begin
    
    P0_OUT  <= DRIVING_LEVEL when cur_reg.p0_out=DRIVING_LEVEL else 'Z';
    P1_OUT  <= DRIVING_LEVEL when cur_reg.p1_out=DRIVING_LEVEL else 'Z';
    
    stm_proc : process(cur_reg, P0_IN, P1_IN)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        case cr.state is
            
            when FLOATING =>
                r.p0_out    := FLOATING_LEVEL;
                r.p1_out    := FLOATING_LEVEL;
                r.cycle_cnt := uns(DEBOUNCE_CYCLES-2, CYCLE_BITS);
                if P0_IN=DRIVING_LEVEL then
                    r.state := P0_DRIVING;
                end if;
                if P1_IN=DRIVING_LEVEL then
                    r.state := P1_DRIVING;
                end if;
            
            when P0_DRIVING =>
                r.p0_out    := FLOATING_LEVEL;
                r.p1_out    := DRIVING_LEVEL;
                if P0_IN=FLOATING_LEVEL then
                    r.state     := DEBOUNCING;
                end if;
            
            when P1_DRIVING =>
                r.p0_out    := DRIVING_LEVEL;
                r.p1_out    := FLOATING_LEVEL;
                if P1_IN=FLOATING_LEVEL then
                    r.state     := DEBOUNCING;
                end if;
            
            when DEBOUNCING =>
                r.p0_out    := FLOATING_LEVEL;
                r.p1_out    := FLOATING_LEVEL;
                r.cycle_cnt := cr.cycle_cnt-1;
                if cr.cycle_cnt(reg_type.cycle_cnt'high)='1' then
                    r.state := FLOATING;
                end if;
            
        end case;
        
        next_reg    <= r;
    end process;
    
    stm_sync_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end Behavioral;