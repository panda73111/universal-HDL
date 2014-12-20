
library IEEE;
use IEEE.STD_LOGIC_1164.all;

package video_profiles is
    
    constant VIDEO_PROFILE_COUNT    : natural := 6;
    
    type video_profile_type is record
        width           : natural;
        height          : natural;
        pixel_period    : time;
        clk10_mult      : natural;
        clk10_div       : natural;
        interlaced      : boolean;
        negative_vsync  : boolean;
        negative_hsync  : boolean;
        top_border      : natural; -- lines
        bottom_border   : natural; -- lines
        left_border     : natural; -- pixels
        right_border    : natural; -- pixels
        h_front_porch   : natural; -- pixels
        h_back_porch    : natural; -- pixels
        h_sync_cycles   : natural; -- pixels
        v_front_porch   : natural; -- lines
        v_back_porch    : natural; -- lines
        v_sync_lines    : natural; -- lines
    end record;
    
    type video_profiles_type is
        array(0 to VIDEO_PROFILE_COUNT-1)
        of video_profile_type;
    
    constant VIDEO_PROFILES : video_profiles_type := (
        0 => ( -- 640x480p, 60Hz
            width           => 640,
            height          => 480,
            pixel_period    => 39.7 ns,
            clk10_mult      => 5, -- 25 Mhz
            clk10_div       => 2,
            interlaced      => false,
            negative_vsync  => true,
            negative_hsync  => true,
            top_border      => 8,
            bottom_border   => 8,
            left_border     => 8,
            right_border    => 8,
            h_front_porch   => 8,
            h_back_porch    => 40,
            h_sync_cycles   => 96,
            v_front_porch   => 2,
            v_back_porch    => 25,
            v_sync_lines    => 2
        ),
        1 => ( -- 1024x768p, 75Hz
            width           => 1024,
            height          => 768,
            pixel_period    => 12.7 ns,
            clk10_mult      => 63, -- 78.75 Mhz
            clk10_div       => 8,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            top_border      => 0,
            bottom_border   => 0,
            left_border     => 0,
            right_border    => 0,
            h_front_porch   => 16,
            h_back_porch    => 176,
            h_sync_cycles   => 96,
            v_front_porch   => 1,
            v_back_porch    => 28,
            v_sync_lines    => 3
        ),
        2 => ( -- 1280x720p, 60Hz
            width           => 1280,
            height          => 720,
            pixel_period    => 13.5 ns,
            clk10_mult      => 15, -- 75 Mhz
            clk10_div       => 2,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            top_border      => 0,
            bottom_border   => 0,
            left_border     => 0,
            right_border    => 0,
            h_front_porch   => 110,
            h_back_porch    => 220,
            h_sync_cycles   => 40,
            v_front_porch   => 5,
            v_back_porch    => 20,
            v_sync_lines    => 5
        ),
        3 => ( -- 1920x1080p, 30Hz
            width           => 1920,
            height          => 1080,
            pixel_period    => 13.5 ns,
            clk10_mult      => 15, -- 75 Mhz
            clk10_div       => 2,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            top_border      => 0,
            bottom_border   => 0,
            left_border     => 0,
            right_border    => 0,
            h_front_porch   => 148,
            h_back_porch    => 88,
            h_sync_cycles   => 44,
            v_front_porch   => 36,
            v_back_porch    => 4,
            v_sync_lines    => 5
        ),
        4 => ( -- 1920x1080i, 60Hz
            width           => 1920,
            height          => 540,
            pixel_period    => 13.5 ns,
            clk10_mult      => 15, -- 75 Mhz
            clk10_div       => 2,
            interlaced      => true,
            negative_vsync  => false,
            negative_hsync  => false,
            top_border      => 0,
            bottom_border   => 0,
            left_border     => 0,
            right_border    => 0,
            h_front_porch   => 148,
            h_back_porch    => 88,
            h_sync_cycles   => 44,
            v_front_porch   => 2,
            v_back_porch    => 15,
            v_sync_lines    => 5
        ),
        5 => ( -- 1920x1080p, 60Hz
            width           => 1920,
            height          => 1080,
            pixel_period    => 6.7 ns,
            clk10_mult      => 74, -- 148 Mhz
            clk10_div       => 5,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            top_border      => 0,
            bottom_border   => 0,
            left_border     => 0,
            right_border    => 0,
            h_front_porch   => 148,
            h_back_porch    => 88,
            h_sync_cycles   => 44,
            v_front_porch   => 36,
            v_back_porch    => 4,
            v_sync_lines    => 5
        )
    );
    
end video_profiles;

package body video_profiles is
end video_profiles;
