--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   23:36:00 09/11/2014
-- Module Name:   UART_RECEIVER_tb.vhd
-- Project Name:  UART_RECEIVER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: UART_RECEIVER
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.txt_util.all;
 
ENTITY UART_SENDER_tb IS
END UART_SENDER_tb;
 
ARCHITECTURE behavior OF UART_SENDER_tb IS 
    
    type douts_type is array(0 to 1) of std_ulogic_vector(7 downto 0);
    
    -- Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal RXD      : std_ulogic_vector(1 downto 0) := "00";
    
    -- Outputs
    signal DOUT     : douts_type;
    signal VALID    : std_ulogic_vector(1 downto 0);
    
    signal ERROR    : std_ulogic_vector(1 downto 0);
    signal BUSY     : std_ulogic_vector(1 downto 0);
    
    -- clock period definitions
    constant CLK_PERIOD         : time := 100 ns;
    constant CLK_PERIOD_REAL    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
    type baud_rates_type is array(0 to 1) of natural;
    constant BAUD_RATES : baud_rates_type := (115200, 9600);
    
    constant NONE   : natural := 0;
    constant EVEN   : natural := 1;
    constant ODD    : natural := 2;
    type parity_bit_types_type is array(0 to 1) of natural range 0 to 2;
    constant PARITY_BIT_TYPES   : parity_bit_types_type := (1, 2);
    
    signal tests_finished   : std_ulogic_vector(1 downto 0) := "00";
    
BEGIN
    
    UART_SENDERs_gen : for i in 0 to 1 generate
        
        UART_RECEIVERs_inst : entity work.UART_RECEIVER
        generic map (
            CLK_IN_PERIOD   => CLK_PERIOD_REAL,
            BAUD_RATE       => BAUD_RATES(i),
            PARITY_BIT_TYPE => PARITY_BIT_TYPES(i)
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            RXD     => RXD(I),
            
            DOUT    => DOUT(I),
            VALID   => VALID(I),
            
            ERROR   => ERROR(I),
            BUSY    => BUSY(I)
        );
        
    end generate;
    
    -- clock generation
    CLK <= not CLK after CLK_PERIOD / 2;
    
    stimulus_procs_gen : for i in 0 to 1 generate
        
        stimulate_uart_proc : process
            constant BIT_PERIOD : real := 1_000_000_000.0 / real(BAUD_RATES(i));
            constant BIT_TIME   : time := bit_period * 1 ns;
            alias par_t is PARITY_BIT_TYPES(i);
            variable data   : std_ulogic_vector(7 downto 0);
            variable parity : std_ulogic;
        begin
            wait for 200 ns;
            wait for CLK_PERIOD*10;
            wait until rising_edge(CLK);
            
            RXD(i)  <= '1';
            wait until rising_edge(CLK);
            
            for j in character'pos('a') to character'pos('z') loop
                -- start bit
                RXD(i)  <= '0';
                wait for BIT_TIME;
                -- data bits
                data    := stdulv(j, 8);
                parity  := '0';
                for k in 0 to 7 loop
                    RXD(i)  <= data(k);
                    if data(k)='1' then
                        parity  := not parity;
                    end if;
                    wait for BIT_TIME;
                end loop;
                -- parity bit
                if par_t=EVEN then
                    RXD(i)  <= parity;
                    wait for BIT_TIME;
                elsif par_t=ODD then
                    RXD(i)  <= not parity;
                    wait for BIT_TIME;
                end if;
                -- stop bit
                RXD(i)  <= '1';
                wait for BIT_TIME;
            end loop;
            
            wait for BIT_TIME;
            tests_finished(i)   <= '1';
            wait;
        end process;
        
    end generate;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for CLK_PERIOD*10;
        wait until rising_edge(CLK);
        
        -- insert stimulus here
        
        wait until tests_finished="11" and BUSY="00";
        wait for 10 us;
        report "NONE. All tests completed."
            severity FAILURE;
    end process;

END;
