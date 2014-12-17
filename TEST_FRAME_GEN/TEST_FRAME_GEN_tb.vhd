--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   22:26:10 12/17/2014
-- Module Name:   TEST_FRAME_GEN_tb.vhd
-- Project Name:  TEST_FRAME_GEN
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: TEST_FRAME_GEN
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.video_profiles.all;

ENTITY TEST_FRAME_GEN_tb IS
    generic (
        FIRST_PROFILE   : natural := 0;
        LAST_PROFILE    : natural := VIDEO_PROFILE_COUNT-1;
        FRAME_COUNT     : natural := 3;
        FRAME_STEP      : natural := 1;
        R_BITS          : natural range 1 to 12 := 8;
        G_BITS          : natural range 1 to 12 := 8;
        B_BITS          : natural range 1 to 12 := 8;
        PROFILE_BITS    : natural := log2(VIDEO_PROFILE_COUNT);
        X_BITS          : natural := 12;
        Y_BITS          : natural := 12
    );
END TEST_FRAME_GEN_tb;

ARCHITECTURE rtl OF TEST_FRAME_GEN_tb IS

    -- Inputs
    signal CLK_IN   : std_ulogic := '0';
    signal RST      : std_ulogic := '0';
    
    signal PROFILE  : std_ulogic_vector(PROFILE_BITS-1 downto 0) := (others => '0');
    
    -- Outputs
    signal CLK_OUT  : std_ulogic;
    
    signal HSYNC        : std_ulogic;
    signal VSYNC        : std_ulogic;
    signal RGB_ENABLE   : std_ulogic;
    signal R            : std_ulogic_vector(R_BITS-1 downto 0);
    signal G            : std_ulogic_vector(G_BITS-1 downto 0);
    signal B            : std_ulogic_vector(B_BITS-1 downto 0);
    
    constant CLK_IN_period      : time := 50 ns; -- 20 MHz
    constant CLK_IN_period_real : real := real(CLK_IN_period / 1 ps) / real(1 ns / 1 ps);
    
BEGIN
    
    TEST_FRAME_GEN_inst : entity work.TEST_FRAME_GEN
        generic map (
            CLK_IN_PERIOD           => clk_in_period_real,
            FRAME_STEP              => FRAME_STEP,
            CLK_IN_TO_CLK10_MULT    => 1,
            CLK_IN_TO_CLK10_DIV     => 2,
            R_BITS                  => R_BITS,
            G_BITS                  => G_BITS,
            B_BITS                  => B_BITS,
            PROFILE_BITS            => PROFILE_BITS,
            X_BITS                  => X_BITS,
            Y_BITS                  => Y_BITS
        )
        port map (
            CLK_IN  => CLK_IN,
            RST     => RST,
            
            PROFILE => PROFILE,
            
            CLK_OUT => CLK_OUT,
            
            HSYNC       => HSYNC,
            VSYNC       => VSYNC,
            RGB_ENABLE  => RGB_ENABLE,
            R           => R,
            G           => G,
            B           => B
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
        
        for profile_i in FIRST_PROFILE to LAST_PROFILE loop
            report "Setting profile " & natural'image(profile_i);
            PROFILE <= stdulv(profile_i, PROFILE_BITS);
            
            for frame_i in 0 to FRAME_COUNT-1 loop
                wait until VSYNC'event;
                wait until VSYNC'event;
            end loop;
        end loop;
        
        wait for 100 ns;
        report "NONE. All tests completed successfully"
            severity FAILURE;
    end process;
    
END;
