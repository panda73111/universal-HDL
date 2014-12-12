--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   15:27:10 12/11/2014
-- Module Name:   VIDEO_TIMING_GEN_tb.vhd
-- Project Name:  VIDEO_TIMING_GEN
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: VIDEO_TIMING_GEN
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.video_profiles.all;

ENTITY VIDEO_TIMING_GEN_tb IS
    generic (
        PROFILE_BITS    : natural := log2(VIDEO_PROFILE_COUNT);
        X_BITS          : natural := 11;
        Y_BITS          : natural := 11
    );
END VIDEO_TIMING_GEN_tb;

ARCHITECTURE rtl OF VIDEO_TIMING_GEN_tb IS

    -- Inputs
    signal CLK_IN   : std_ulogic := '0';
    signal RST      : std_ulogic := '0';
    
    signal PROFILE  : std_ulogic_vector(PROFILE_BITS-1 downto 0) := (others => '0');
    
    -- Outputs
    signal CLK_OUT  : std_ulogic;
    
    signal POS_VSYNC    : std_ulogic;
    signal POS_HSYNC    : std_ulogic;
    signal VSYNC        : std_ulogic;
    signal HSYNC        : std_ulogic;
    signal RGB_ENABLE   : std_ulogic;
    signal X            : std_ulogic_vector(X_BITS-1 downto 0);
    signal Y            : std_ulogic_vector(Y_BITS-1 downto 0);
    
    constant FRAME_COUNT    : natural := 4;
    
    constant CLK_IN_period      : time := 50 ns; -- 20 MHz
    constant CLK_IN_period_real : real := real(CLK_IN_period / 1 ps) / real(1 ns / 1 ps);
    
    signal analyzer_pos_vsync   : std_ulogic := '0';
    signal analyzer_pos_hsync   : std_ulogic := '0';
    signal analyzer_width       : std_ulogic_vector(10 downto 0) := (others => '0');
    signal analyzer_height      : std_ulogic_vector(10 downto 0) := (others => '0');
    signal analyzer_interlaced  : std_ulogic := '0';
    signal analyzer_valid       : std_ulogic := '0';
    
BEGIN
    
    VIDEO_TIMING_GEN_inst : entity work.VIDEO_TIMING_GEN
        generic map (
            CLK_IN_PERIOD           => clk_in_period_real,
            CLK_IN_TO_CLK10_MULT    => 1,
            CLK_IN_TO_CLK10_DIV     => 2,
            PROFILE_BITS            => PROFILE_BITS,
            X_BITS                  => X_BITS,
            Y_BITS                  => Y_BITS
        )
        port map (
            CLK_IN  => CLK_IN,
            RST     => RST,
            
            PROFILE => PROFILE,
            
            CLK_OUT => CLK_OUT,
            
            POS_VSYNC   => POS_VSYNC,
            POS_HSYNC   => POS_HSYNC,
            VSYNC       => VSYNC,
            HSYNC       => HSYNC,
            RGB_ENABLE  => RGB_ENABLE,
            X           => X,
            Y           => Y
        );
    
    VIDEO_ANALYZER_inst : entity work.VIDEO_ANALYZER
        port map (
            CLK => CLK_OUT,
            RST => RST,
            
            START       => POS_VSYNC,
            VSYNC       => VSYNC,
            HSYNC       => HSYNC,
            RGB_VALID   => RGB_ENABLE,
            
            POSITIVE_VSYNC  => analyzer_pos_vsync,
            POSITIVE_HSYNC  => analyzer_pos_hsync,
            WIDTH           => analyzer_width,
            HEIGHT          => analyzer_height,
            INTERLACED      => analyzer_interlaced,
            VALID           => analyzer_valid
        );
    
    CLK_IN  <= not CLK_IN after CLK_IN_period/2;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        RST <= '1';
        wait for 1 us;
        RST <= '0';
        wait for 100 ns;
        wait until rising_edge(CLK_IN);
        
        -- insert stimulus here
        
        for profile_i in 0 to VIDEO_PROFILE_COUNT-1 loop
            report "Setting profile " & natural'image(profile_i);
            PROFILE <= stdulv(profile_i, PROFILE_BITS);
            
            for frame_i in 0 to FRAME_COUNT-1 loop
                wait until POS_VSYNC='1';
                wait until POS_VSYNC='0';
            end loop;
            wait for 100 ns;
        end loop;
        
        wait for 100 ns;
        report "NONE. All tests completed successfully"
            severity FAILURE;
    end process;

END;
