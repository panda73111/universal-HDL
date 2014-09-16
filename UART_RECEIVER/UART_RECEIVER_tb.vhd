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
    signal clk      : std_ulogic := '0';
    signal rst      : std_ulogic := '0';
    signal rxd      : std_ulogic_vector(1 downto 0) := "00";
    signal rd_en    : std_ulogic_vector(1 downto 0) := "00";
    
    -- Outputs
    signal dout     : douts_type;
    signal valid    : std_ulogic_vector(1 downto 0);
    signal full     : std_ulogic_vector(1 downto 0);
    signal error    : std_ulogic_vector(1 downto 0);
    signal busy     : std_ulogic_vector(1 downto 0);
    
    -- clock period definitions
    constant clk_period         : time := 10 ns;
    constant clk_period_real    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
    type baud_rates_type is array(0 to 1) of natural;
    constant baud_rates : baud_rates_type := (115200, 9600);
    
    constant NONE   : natural := 0;
    constant EVEN   : natural := 1;
    constant ODD    : natural := 2;
    type parity_bit_types_type is array(0 to 1) of natural range 0 to 2;
    constant parity_bit_types   : parity_bit_types_type := (1, 2);
    
    signal tests_finished   : std_ulogic_vector(1 downto 0) := "00";
    
BEGIN
    
    UART_SENDERs_gen : for i in 0 to 1 generate
        
        UART_RECEIVERs_inst : entity work.UART_RECEIVER
        generic map (
            CLK_IN_PERIOD   => clk_period_real,
            BAUD_RATE       => baud_rates(i),
            PARITY_BIT_TYPE => parity_bit_types(i)
        )
        port map (
            CLK => clk,
            RST => rst,
            
            RXD     => rxd(i),
            RD_EN   => rd_en(i),
            
            DOUT    => dout(i),
            VALID   => valid(i),
            FULL    => full(i),
            ERROR   => error(i),
            BUSY    => busy(i)
        );
        
    end generate;
    
    -- clock generation
    clk <= not clk after clk_period / 2;
    
    stimulus_procs_gen : for i in 0 to 1 generate
        
        stimulate_uart_proc : process
            constant bit_period : real := 1_000_000_000.0 / real(baud_rates(i));
            constant bit_time   : time := bit_period * 1 ns;
            alias par_t is parity_bit_types(i);
            variable data   : std_ulogic_vector(7 downto 0);
            variable parity : std_ulogic;
        begin
            wait for 200 ns;
            wait for clk_period*10;
            wait until rising_edge(clk);
            
            rxd(i)  <= '1';
            wait until rising_edge(clk);
            
            for j in character'pos('a') to character'pos('z') loop
                -- start bit
                rxd(i)  <= '0';
                wait for bit_time;
                -- data bits
                data    := stdulv(j, 8);
                parity  := '0';
                for k in 0 to 7 loop
                    rxd(i)  <= data(k);
                    if data(k)='1' then
                        parity  := not parity;
                    end if;
                    wait for bit_time;
                end loop;
                -- parity bit
                if par_t=EVEN then
                    rxd(i)  <= parity;
                    wait for bit_time;
                elsif par_t=ODD then
                    rxd(i)  <= not parity;
                    wait for bit_time;
                end if;
                -- stop bit
                rxd(i)  <= '1';
                wait for bit_time;
            end loop;
            
            wait for bit_time;
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
        wait for clk_period*10;
        wait until rising_edge(clk);
        
        -- insert stimulus here
        
        wait until tests_finished="11" and busy="00";
        wait for 10 us;
        report "NONE. All tests completed." severity failure;
    end process;

END;
