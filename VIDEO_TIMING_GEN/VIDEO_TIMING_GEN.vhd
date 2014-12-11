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
        CLK_IN_PERIOD   : real;
        PROFILE_BITS    : natural := log2(VIDEO_PROFILE_COUNT);
        X_BITS          : natural := 11;
        Y_BITS          : natural := 11
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        PROFILE : in std_ulogic_vector(PROFILE_BITS-1 downto 0);
        
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
        PIXEL,
        HOR_BACK_PORCH,
        LINE_SWITCH,
        FRAME_SWITCH
    );
    
    type reg_type is record
        state       : state_type;
        x           : natural range 0 to 2**X_BITS-1;
        y           : natural range 0 to 2**Y_BITS-1;
        rgb_enable  : std_ulogic;
        pos_vsync   : std_ulogic;
        pos_hsync   : std_ulogic;
        other_frame : boolean;
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => HOR_SYNC,
        x           => 0,
        y           => 0,
        rgb_enable  => '0',
        pos_vsync   => '0',
        pos_hsync   => '0',
        other_frame => false
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal vp               : video_profile_type;
    signal total_ver_lines  : natural range 0 to 2**(Y_BITS+1)-1;
    signal total_hor_pixels : natural range 0 to 2**(X_BITS+1)-1;
    
begin
    
    POS_VSYNC   <= cur_reg.pos_vsync;
    POS_HSYNC   <= cur_reg.pos_hsync;
    VSYNC       <= cur_reg.pos_vsync xor sel(vp.negative_vsync, '1', '0');
    HSYNC       <= cur_reg.pos_hsync xor sel(vp.negative_hsync, '1', '0');
    
    vp  <= video_profiles(int(PROFILE));
    
    total_ver_lines     <= vp.v_sync_lines + vp.v_front_porch + vp.top_border + vp.height +
                            vp.bottom_border + vp.v_back_porch;
    
    total_hor_pixels    <= vp.h_sync_cycles + vp.h_front_porch + vp.left_border + vp.width +
                            vp.right_border + vp.h_back_porch;
    
    CLK_MAN_inst : entity work.CLK_MAN
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            MULTIPLIER      => 2,
            DIVISOR         => 2
        )
        port map (
            CLK_IN  => CLK,
            RST     => RST
        );
    
    stm_proc : process(RST, cur_reg, vp)
        alias cr is cur_reg;
        alias x is cr.x;
        alias y is cr.y;
        variable r  : reg_type := reg_type_def;
    begin
        r               := cr;
        r.pos_vsync     := '0';
        r.pos_hsync     := '0';
        r.rgb_enable    := '0';
        r.x             := cr.x+1;
        
        if
            not vp.interlaced or
            not cr.other_frame or
            x >= total_hor_pixels/2
        then
            if y < vp.v_sync_lines then
                -- vsync period
                r.pos_vsync := '1';
            else
                r.pos_vsync := '0';
            end if;
        end if;
        
        case cr.state is
            
            when HOR_SYNC =>
                r.pos_hsync := '1';
                if x=vp.h_sync_cycles-1 then
                    r.state := HOR_FRONT_PORCH;
                end if;
            
            when HOR_FRONT_PORCH =>
                if x=vp.h_sync_cycles+vp.h_front_porch+vp.left_border-1 then
                    r.state := PIXEL;
                end if;
            
            when PIXEL =>
                r.rgb_enable    := '1';
                if x=vp.h_sync_cycles+vp.h_front_porch+vp.left_border+vp.width-1 then
                    r.state := HOR_BACK_PORCH;
                end if;
            
            when HOR_BACK_PORCH =>
                if x=total_hor_pixels-1 then
                    r.state := LINE_SWITCH;
                end if;
            
            when LINE_SWITCH =>
                r.x := 0;
                r.y := y+1;
                if cr.y=total_ver_lines-1 then
                    r.state := FRAME_SWITCH;
                end if;
            
            when FRAME_SWITCH =>
                r.x             := 0;
                r.y             := 0;
                r.other_frame   := not cr.other_frame;
                r.state         := HOR_SYNC;
            
        end case;
        
        if x=total_hor_pixels-2 then
            r.state := LINE_SWITCH;
        end if;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        
        next_reg    <= r;
    end process;
    
    stm_sync_proc : process(RST, CLK)
    begin
        if RST='1' then
            next_reg    <= reg_type_def;
        elsif rising_edge(CLK) then
            next_reg    <= cur_reg;
        end if;
    end process;
    
end rtl;
