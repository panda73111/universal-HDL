--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   15:32:35 09/16/2016
-- Module Name:   I2C_MASTER_tb.vhd
-- Project Name:  I2C_MASTER
-- Tool versions: Xilinx ISE 14.7
-- Description:
--  
-- VHDL Test Bench Created by ISE for module: I2C_MASTER
--  
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.txt_util.all;

ENTITY I2C_MASTER_tb IS
END I2C_MASTER_tb;

ARCHITECTURE behavior OF I2C_MASTER_tb IS
    
    -- Inputs
    signal RST : std_ulogic := '1';
    signal CLK : std_ulogic := '0';
    
    signal SDA_IN  : std_ulogic := '1';
    signal SCL_IN  : std_ulogic := '1';
    
    signal ADDR    : std_ulogic_vector(6 downto 0) := "0000000";
    signal DIN     : std_ulogic_vector(7 downto 0) := x"00";
    signal RD_EN   : std_ulogic := '0';
    signal WR_EN   : std_ulogic := '0';
    
    -- Outputs
    signal SDA_OUT : std_ulogic;
    signal SCL_OUT : std_ulogic;
    
    signal DOUT        : std_ulogic_vector(7 downto 0);
    signal DOUT_VALID  : std_ulogic;
    signal BUSY        : std_ulogic;
    signal ERROR       : std_ulogic;
    
    constant CLK_PERIOD      : time := 20 ns; -- 50 MHz
    constant CLK_PERIOD_REAL : real := real(CLK_PERIOD / 1 ps) / real(1 ns / 1 ps);
    
BEGIN
    
    CLK <= not CLK after CLK_PERIOD/2;
    
    I2C_MASTER_inst : entity work.I2C_MASTER
        generic map (
            CLK_IN_PERIOD   => CLK_PERIOD_REAL
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            SDA_IN  => SDA_IN,
            SCL_IN  => SCL_IN,
            SDA_OUT => SDA_OUT,
            SCL_OUT => SCL_OUT,
            
            ADDR    => ADDR,
            DIN     => DIN,
            RD_EN   => RD_EN,
            WR_EN   => WR_EN,
            
            DOUT        => DOUT,
            DOUT_VALID  => DOUT_VALID,
            BUSY        => BUSY,
            ERROR       => ERROR
        );
    
    stim_proc: process
    begin
        
        -- hold reset state for 100 ns.
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for CLK_PERIOD*10;
        wait until rising_edge(CLK);
        
        ADDR    <= "0000000";
        RD_EN   <= '1';
        wait until rising_edge(CLK) and BUSY='1';
        RD_EN   <= '0';
        wait until rising_edge(CLK) and BUSY='0';
        
        wait for 100 ns;
        assert false
            severity FAILURE;
        
    end process;
    
END;
