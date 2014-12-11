----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    11:39:45 12/11/2014 
-- Module Name:    VIDEO_TIMING_GEN - rtl 
-- Project Name:   TEST_FRAME_GEN
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;
use work.video_profiles.all;

entity VIDEO_TIMING_GEN is
    generic (
        CLK_IN_PERIOD           : real;
        CLK_IN_TO_CLK10_MULT    : natural := 1;
        CLK_IN_TO_CLK10_DIV     : natural := 2;
        PROFILE_BITS            : natural := log2(VIDEO_PROFILE_COUNT);
        X_BITS                  : natural := 11;
        Y_BITS                  : natural := 11
    );
    port (
        CLK_IN  : in std_ulogic;
        RST     : in std_ulogic;
        
        PROFILE : in std_ulogic_vector(PROFILE_BITS-1 downto 0);
        
        CLK_OUT : out std_ulogic := '0';
        
        POS_VSYNC   : out std_ulogic := '0';
        POS_HSYNC   : out std_ulogic := '0';
        VSYNC       : out std_ulogic := '0';
        HSYNC       : out std_ulogic := '0';
        RGB_ENABLE  : out std_ulogic := '0';
        X           : out std_ulogic_vector(X_BITS-1 downto 0) := (others => '0');
        Y           : out std_ulogic_vector(Y_BITS-1 downto 0) := (others => '0')
    );
end VIDEO_TIMING_GEN;

architecture rtl of VIDEO_TIMING_GEN is
    
    type state_type is (
        HOR_SYNC,
        HOR_FRONT_PORCH,
        LEFT_BORDER,
        PIXEL,
        RIGHT_BORDER,
        HOR_BACK_PORCH
    );
    
    type reg_type is record
        state           : state_type;
        x               : natural range 0 to 2**X_BITS-1;
        y               : natural range 0 to 2**Y_BITS-1;
        ver_rgb_enable  : std_ulogic;
        hor_rgb_enable  : std_ulogic;
        pos_vsync       : std_ulogic;
        pos_hsync       : std_ulogic;
        other_frame     : boolean;
    end record;
    
    constant reg_type_def   : reg_type := (
        state           => HOR_SYNC,
        x               => 0,
        y               => 0,
        ver_rgb_enable  => '0',
        hor_rgb_enable  => '0',
        pos_vsync       => '0',
        pos_hsync       => '0',
        other_frame     => false
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal pix_clk  : std_ulogic := '0';
    
    signal vp               : video_profile_type;
    signal total_ver_lines  : natural range 0 to 2**(Y_BITS+1)-1;
    signal total_hor_pixels : natural range 0 to 2**(X_BITS+1)-1;
    signal clk_locked       : std_ulogic := '0';
    
    signal cur_profile  : std_ulogic_vector(PROFILE_BITS-1 downto 0) := (others => '0');
    signal profile_set  : boolean := false;
    signal reprog_en    : std_ulogic := '0';
    signal rst_stm      : std_ulogic := '1';
    
begin
    
    CLK_OUT <= pix_clk;
    
    POS_VSYNC   <= cur_reg.pos_vsync;
    POS_HSYNC   <= cur_reg.pos_hsync;
    VSYNC       <= cur_reg.pos_vsync xor sel(vp.negative_vsync, '1', '0');
    HSYNC       <= cur_reg.pos_hsync xor sel(vp.negative_hsync, '1', '0');
    RGB_ENABLE  <= cur_reg.ver_rgb_enable and cur_reg.hor_rgb_enable;
    
    vp  <= video_profiles(int(PROFILE));
    
    total_ver_lines     <= vp.v_sync_lines + vp.v_front_porch + vp.top_border + vp.height +
                            vp.bottom_border + vp.v_back_porch + sel(vp.interlaced, 1, 0);
    
    total_hor_pixels    <= vp.h_sync_cycles + vp.h_front_porch + vp.left_border + vp.width +
                            vp.right_border + vp.h_back_porch;
    
    CLK_MAN_inst : entity work.CLK_MAN
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            MULTIPLIER      => 2,
            DIVISOR         => 2
        )
        port map (
            CLK_IN  => CLK_IN,
            RST     => RST,
            
            REPROG_MULT => stdulv(vp.clk10_mult*CLK_IN_TO_CLK10_MULT, 8),
            REPROG_DIV  => stdulv(vp.clk10_div*CLK_IN_TO_CLK10_DIV, 8),
            REPROG_EN   => reprog_en,
            
            CLK_OUT => pix_clk,
            LOCKED  => clk_locked
        );
    
    dcm_reprog_proc : process(RST, CLK_IN)
    begin
        if RST='1' then
            cur_profile <= (others => '0');
            profile_set <= false;
            reprog_en   <= '0';
            rst_stm     <= '1';
        elsif rising_edge(CLK_IN) then
            rst_stm     <= '0';
            reprog_en   <= '0';
            if PROFILE/=cur_profile then
                profile_set <= false;
            end if;
            if
                not profile_set and
                clk_locked='1'
            then
                reprog_en   <= '1';
                cur_profile <= PROFILE;
                profile_set <= true;
                rst_stm     <= '1';
            end if;
        end if;
    end process;
    
    stm_proc : process(rst_stm, cur_reg, vp, PROFILE)
        alias cr is cur_reg;
        alias x is cr.x;
        alias y is cr.y;
        variable r  : reg_type := reg_type_def;
    begin
        r                   := cr;
        r.pos_hsync         := '0';
        r.hor_rgb_enable    := '0';
        r.x                 := cr.x+1;
        
        if
            not vp.interlaced or
            not cr.other_frame or
            x=total_hor_pixels/2
        then
            if y=0 then
                -- vsync period
                r.pos_vsync := '1';
            end if;
            if y=vp.v_sync_lines then
                r.pos_vsync := '0';
            end if;
        end if;
        
        if y=vp.v_sync_lines+vp.v_front_porch+vp.top_border then
            r.ver_rgb_enable    := '1';
        end if;
        if y=vp.v_sync_lines+vp.v_front_porch+vp.top_border+vp.height then
            r.ver_rgb_enable    := '0';
        end if;
        
        case cr.state is
            
            when HOR_SYNC =>
                r.pos_hsync := '1';
                if x=vp.h_sync_cycles-1 then
                    r.state := HOR_FRONT_PORCH;
                end if;
            
            when HOR_FRONT_PORCH =>
                if x=vp.h_sync_cycles+vp.h_front_porch-1 then
                    r.state := LEFT_BORDER;
                    if vp.left_border=0 then
                        r.state := PIXEL;
                    end if;
                end if;
            
            when LEFT_BORDER =>
                if x=vp.h_sync_cycles+vp.h_front_porch+vp.left_border-1 then
                    r.state := PIXEL;
                end if;
            
            when PIXEL =>
                r.hor_rgb_enable    := '1';
                if x=vp.h_sync_cycles+vp.h_front_porch+vp.left_border+vp.width-1 then
                    r.state := RIGHT_BORDER;
                    if vp.right_border=0 then
                        r.state := HOR_BACK_PORCH;
                    end if;
                end if;
            
            when RIGHT_BORDER =>
                if x=vp.h_sync_cycles+vp.h_front_porch+vp.left_border+vp.width+vp.right_border-1 then
                    r.state := HOR_BACK_PORCH;
                end if;
            
            when HOR_BACK_PORCH =>
                if x=total_hor_pixels-1 then
                    -- line switch
                    r.x := 0;
                    r.y := y+1;
                    if
                        vp.interlaced and
                        not cr.other_frame and
                        y=vp.v_sync_lines+vp.v_front_porch-1
                    then
                        -- skip the additional interlacing
                        -- blank line in even frames
                        r.y := y+2;
                    end if;
                    if cr.y=total_ver_lines-1 then
                        -- frame switch
                        r.y             := 0;
                        r.other_frame   := not cr.other_frame;
                    end if;
                    r.state := HOR_SYNC;
                end if;
            
        end case;
        
        if rst_stm='1' then
            r   := reg_type_def;
        end if;
        
        next_reg    <= r;
    end process;
    
    stm_sync_proc : process(rst_stm, pix_clk)
    begin
        if rst_stm='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(pix_clk) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;