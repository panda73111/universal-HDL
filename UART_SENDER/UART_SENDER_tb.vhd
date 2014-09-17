--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   16:29:24 09/10/2014
-- Module Name:   UART_SENDER_tb.vhd
-- Project Name:  UART_SENDER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: UART_SENDER
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
    
    -- Inputs
    signal clk      : std_ulogic := '0';
    signal rst      : std_ulogic := '0';
    signal din      : std_ulogic_vector(7 downto 0) := (others => '0');
    signal wr_en    : std_ulogic := '0';
    signal cts      : std_ulogic := '0';
    
    -- Outputs1
    signal txd      : std_ulogic_vector(1 downto 0);
    signal full     : std_ulogic_vector(1 downto 0);
    signal busy     : std_ulogic_vector(1 downto 0);
    
    -- clock period definitions
    constant clk_period         : time := 20 ns;
    constant clk_period_real    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
    constant NONE   : natural := 0;
    constant EVEN   : natural := 1;
    constant ODD    : natural := 2;
    
    type baud_rates_type is array(0 to 1) of natural;
    constant baud_rates : baud_rates_type := (
        115_200, 9_600
    );
    
    type parity_bit_types_type is array(0 to 1) of natural;
    constant parity_bit_types   : parity_bit_types_type := (
        0, 1
    );
    
BEGIN

    UART_SENDER_gen : for i in 0 to 1 generate
        
        UART_SENDER_inst : entity work.UART_SENDER
        generic map (
            CLK_IN_PERIOD   => clk_period_real,
            BAUD_RATE       => baud_rates(i),
            PARITY_BIT_TYPE => parity_bit_types(i)
        )
        port map (
            CLK => clk,
            RST => rst,
            
            DIN     => din,
            WR_EN   => wr_en,
            CTS     => cts,
            
            TXD     => txd(i),
            FULL    => full(i),
            BUSY    => busy(i)
        );
        
    end generate;
    
    -- clock generation
    clk <= not clk after clk_period / 2;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*10;
        wait until rising_edge(clk);
        cts <= '1';
        wait until rising_edge(clk);
        
        -- insert stimulus here 
        
        for single_letters in 0 to 1 loop
            for i in character'pos('A') to character'pos('Z') loop
                wr_en   <= '1';
                din     <= stdulv(i, 8);
                wait until rising_edge(clk);
                wr_en   <= '0';
                if single_letters=1 then
                    wait until busy="00";
                    wait for clk_period*10;
                end if;
            end loop;
            
            if single_letters=0 then
                wait until busy="00";
            end if;
            wait for 10 us;
        end loop;
        
        report "NONE. All tests completed." severity failure;
    end process;

END;
