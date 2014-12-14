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
        FIRST_PROFILE   : natural := 0;
        LAST_PROFILE    : natural := VIDEO_PROFILE_COUNT-1;
        PROFILE_BITS    : natural := log2(VIDEO_PROFILE_COUNT);
        X_BITS          : natural := 12;
        Y_BITS          : natural := 12
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
    signal X            : std_ulogic_vector(X_BITS-1 downto 0);
    signal Y            : std_ulogic_vector(Y_BITS-1 downto 0);
    signal RGB_ENABLE   : std_ulogic;
    signal RGB_X        : std_ulogic_vector(X_BITS-1 downto 0);
    signal RGB_Y        : std_ulogic_vector(Y_BITS-1 downto 0);
    
    constant CLK_IN_period      : time := 50 ns; -- 20 MHz
    constant CLK_IN_period_real : real := real(CLK_IN_period / 1 ps) / real(1 ns / 1 ps);
    
    signal analyzer_pos_vsync   : std_ulogic := '0';
    signal analyzer_pos_hsync   : std_ulogic := '0';
    signal analyzer_width       : std_ulogic_vector(10 downto 0) := (others => '0');
    signal analyzer_height      : std_ulogic_vector(10 downto 0) := (others => '0');
    signal analyzer_interlaced  : std_ulogic := '0';
    signal analyzer_valid       : std_ulogic := '0';
    
    signal start_ver_test       : boolean := false;
    signal start_hor_test       : boolean := false;
    signal finished_ver_test    : boolean := false;
    signal finished_hor_test    : boolean := false;
    signal vp                   : video_profile_type;
    
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
            X           => X,
            Y           => Y,
            RGB_ENABLE  => RGB_ENABLE,
            RGB_X       => RGB_X,
            RGB_Y       => RGB_Y
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
    
    vp  <= video_profiles(int(PROFILE));
    
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
        
        wait until falling_edge(POS_VSYNC);
        wait for 1 us;
        
        for profile_i in FIRST_PROFILE to LAST_PROFILE loop
            report "Setting profile " & natural'image(profile_i);
            PROFILE <= stdulv(profile_i, PROFILE_BITS);
            
            start_ver_test  <= true;
            start_hor_test  <= true;
            wait until falling_edge(CLK_IN);
            start_ver_test  <= false;
            start_hor_test  <= false;
            
            wait until finished_ver_test and finished_hor_test;
            wait until analyzer_valid='0';
            wait until analyzer_valid='1';
            wait for 1 us;
        end loop;
        
        wait for 100 ns;
        report "NONE. All tests completed successfully"
            severity FAILURE;
    end process;
    
    horizontal_test_proc : process
        type state_type is (
            HSYNC,
            H_FRONT_PORCH,
            RGB,
            H_BACK_PORCH
        );
        variable cycle_count    : natural;
        variable state          : state_type;
    begin
        wait until start_hor_test;
        finished_hor_test   <= false;
        
        report "Starting horizontal test";
        cycle_count := 0;
        state       := HSYNC;
        
        wait until rising_edge(POS_VSYNC);
        assert rising_edge(POS_HSYNC)
            report "Initial vertical sync not simultaneous with horizontal sync!"
            severity FAILURE;
        
        while not finished_ver_test loop
            
            wait until rising_edge(CLK_OUT);
            
            assert not (POS_HSYNC='1' and RGB_ENABLE='1')
                report "Horizontal sync during RGB period!"
                severity FAILURE;
            
            case state is
                
                when HSYNC =>
                    assert RGB_ENABLE='0'
                        report "RGB period during horizontal sync!"
                        severity FAILURE;
                    if POS_HSYNC='0' then
                        -- transition to horizontal front porch
                        assert cycle_count=vp.h_sync_cycles
                            report "Horizontal sync cycle count doesn't match!"
                            severity FAILURE;
                        cycle_count := 1; -- this was the first front porch cycle
                        state       := H_FRONT_PORCH;
                    else
                        -- vertical sync period
                        cycle_count := cycle_count+1;
                    end if;
                
                when H_FRONT_PORCH =>
                    if RGB_ENABLE='1' then
                        -- transition to active RGB lines
                        assert cycle_count=vp.h_front_porch+vp.left_border
                            report "Horizontal front porch doesn't match!"
                            severity FAILURE;
                        cycle_count := 1; -- this was the first RGB cycle
                        state       := RGB;
                    elsif POS_HSYNC='1' then
                        -- vertical blank period
                        assert cycle_count=vp.h_front_porch+vp.left_border+vp.width+vp.right_border+vp.h_back_porch
                            report "Vertical blank line cycle count doesn't match!"
                            severity FAILURE;
                        cycle_count := 1; -- this was the first hsync cycle
                        state       := HSYNC;
                    else
                        -- horizontal front porch
                        cycle_count := cycle_count+1;
                    end if;
                
                when RGB =>
                    if RGB_ENABLE='0' then
                        -- transition to horizonal back porch
                        assert cycle_count=vp.width
                            report "Width doesn't match!"
                            severity FAILURE;
                        cycle_count := 1; -- this was the first back porch cycle
                        state       := H_BACK_PORCH;
                    else
                        -- RGB period
                        cycle_count := cycle_count+1;
                    end if;
                
                when H_BACK_PORCH =>
                    assert RGB_ENABLE='0'
                        report "No horizontal sync between two RGB periods!"
                        severity FAILURE;
                    if POS_HSYNC='1' then
                        -- transition to horizontal sync
                        assert cycle_count=vp.right_border+vp.h_back_porch
                            report "Horizontal back porch doesn't match!"
                            severity FAILURE;
                        cycle_count := 1;  -- this was the first hsync cycle
                        state       := HSYNC;
                    else
                        cycle_count := cycle_count+1;
                    end if;
                
            end case;
            
        end loop;
        
        finished_hor_test   <= true;
        report "Horizontal test completed successfully";
    end process;
    
    vertical_test_proc : process
        type state_type is (
            VSYNC,
            V_FRONT_PORCH,
            RGB_HSYNC,
            RGB,
            V_BACK_PORCH
        );
        variable line_count             : natural;
        variable state                  : state_type;
        variable interlaced_other_frame : boolean;
    begin
        wait until start_ver_test;
        finished_ver_test   <= false;
        
        report "Starting vertical test";
        line_count              := 1;
        state                   := VSYNC;
        interlaced_other_frame  := false;
        
        wait until rising_edge(POS_VSYNC);
        
        while not finished_ver_test loop
            
            wait until rising_edge(POS_HSYNC) or rising_edge(RGB_ENABLE);
            
            assert not (POS_HSYNC='1' and RGB_ENABLE='1')
                report "Vertical sync during RGB period!"
                severity FAILURE;
            
            case state is
                
                when VSYNC =>
                    assert RGB_ENABLE='0'
                        report "RGB period during vertical sync!"
                        severity FAILURE;
                    if POS_VSYNC='0' then
                        -- transition to vertical front porch
                        assert line_count=vp.v_sync_lines
                            report "Vertical sync line count doesn't match!"
                            severity FAILURE;
                        line_count  := 0;
                        state       := V_FRONT_PORCH;
                    else
                        -- vertical sync period
                        line_count  := line_count+1;
                    end if;
                
                when V_FRONT_PORCH =>
                    assert POS_VSYNC='0'
                        report "Vertical sync during vertical front porch period!"
                        severity FAILURE;
                    if RGB_ENABLE='1' then
                        -- transition to active RGB lines
                        assert line_count=vp.v_front_porch+vp.top_border
                            report "Vertical front porch doesn't match!"
                            severity FAILURE;
                        line_count  := 1; -- this is the first RGB line
                        state       := RGB_HSYNC;
                    else
                        -- vertical front porch
                        line_count  := line_count+1;
                    end if;
                
                when RGB_HSYNC =>
                    if POS_HSYNC='1' then
                        state   := RGB;
                    end if;
                
                when RGB =>
                    if RGB_ENABLE='1' then
                        line_count  := line_count+1;
                        state       := RGB_HSYNC;
                    else
                        -- first line of vertical back porch
                        assert line_count=vp.height
                            report "Height doesn't match!"
                            severity FAILURE;
                        line_count  := 1; -- this was the first blanking line
                        state       := V_BACK_PORCH;
                    end if;
                
                when V_BACK_PORCH =>
                    assert RGB_ENABLE='0'
                        report "RGB period during vertical back porch!"
                        severity FAILURE;
                    if POS_VSYNC='1' then
                        -- transition to vertical sync
                        if not vp.interlaced or interlaced_other_frame then
                            assert line_count+1=vp.v_back_porch+vp.bottom_border
                                report "Vertical back porch doesn't match!"
                                severity FAILURE;
                            finished_ver_test   <= true;
                        else
                            assert line_count+1=vp.v_back_porch+vp.bottom_border+1
                                report "Vertical back porch doesn't match!"
                                severity FAILURE;
                            -- for interlacing, test both half-frames
                            interlaced_other_frame  := not interlaced_other_frame;
                            line_count              := 1; -- this is the first vsync line
                            state                   := VSYNC;
                        end if;
                    else
                        line_count  := line_count+1;
                    end if;
                
            end case;
            
        end loop;
        
        finished_ver_test   <= true;
        report "Vertical test completed successfully";
    end process;
    
END;
