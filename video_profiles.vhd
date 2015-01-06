
library IEEE;
use IEEE.STD_LOGIC_1164.all;

package video_profiles is
    
    constant VIDEO_PROFILE_COUNT    : natural := 7;
    
    constant VIDEO_PROFILE_320_240p_60      : natural := 0;
    constant VIDEO_PROFILE_640_480p_60      : natural := 1;
    constant VIDEO_PROFILE_1024_768p_75     : natural := 2;
    constant VIDEO_PROFILE_1280_720p_60     : natural := 3;
    constant VIDEO_PROFILE_1920_1080p_30    : natural := 4;
    constant VIDEO_PROFILE_1920_1080i_60    : natural := 5;
    constant VIDEO_PROFILE_1920_1080p_60    : natural := 6;
    
    type video_profile_type is record
        width           : natural;
        height          : natural;
        pixel_period    : time;
        clk10_mult      : natural;
        clk10_div       : natural;
        interlaced      : boolean;
        negative_vsync  : boolean;
        negative_hsync  : boolean;
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
        0 => ( -- 320x240p, 60Hz
            width           => 320,
            height          => 240,
            pixel_period    => 133.3 ns,
            clk10_mult      => 3, -- 7.5 Mhz
            clk10_div       => 4,
            interlaced      => false,
            negative_vsync  => true,
            negative_hsync  => true,
            h_front_porch   => 33,
            h_back_porch    => 69,
            h_sync_cycles   => 31,
            v_front_porch   => 3,
            v_back_porch    => 18,
            v_sync_lines    => 6
        ),
        1 => ( -- 640x480p, 60Hz
            width           => 640,
            height          => 480,
            pixel_period    => 39.7 ns,
            clk10_mult      => 5, -- 25 Mhz
            clk10_div       => 2,
            interlaced      => false,
            negative_vsync  => true,
            negative_hsync  => true,
            h_front_porch   => 10,
            h_back_porch    => 48,
            h_sync_cycles   => 96,
            v_front_porch   => 10,
            v_back_porch    => 33,
            v_sync_lines    => 2
        ),
        2 => ( -- 1024x768p, 75Hz
            width           => 1024,
            height          => 768,
            pixel_period    => 12.7 ns,
            clk10_mult      => 63, -- 78.75 Mhz
            clk10_div       => 8,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            h_front_porch   => 16,
            h_back_porch    => 176,
            h_sync_cycles   => 96,
            v_front_porch   => 1,
            v_back_porch    => 28,
            v_sync_lines    => 3
        ),
        3 => ( -- 1280x720p, 60Hz
            width           => 1280,
            height          => 720,
            pixel_period    => 13.5 ns,
            clk10_mult      => 15, -- 75 Mhz
            clk10_div       => 2,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            h_front_porch   => 110,
            h_back_porch    => 220,
            h_sync_cycles   => 40,
            v_front_porch   => 5,
            v_back_porch    => 20,
            v_sync_lines    => 5
        ),
        4 => ( -- 1920x1080p, 30Hz
            width           => 1920,
            height          => 1080,
            pixel_period    => 13.5 ns,
            clk10_mult      => 15, -- 75 Mhz
            clk10_div       => 2,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
            h_front_porch   => 148,
            h_back_porch    => 88,
            h_sync_cycles   => 44,
            v_front_porch   => 36,
            v_back_porch    => 4,
            v_sync_lines    => 5
        ),
        5 => ( -- 1920x1080i, 60Hz
            width           => 1920,
            height          => 540,
            pixel_period    => 13.5 ns,
            clk10_mult      => 15, -- 75 Mhz
            clk10_div       => 2,
            interlaced      => true,
            negative_vsync  => false,
            negative_hsync  => false,
            h_front_porch   => 148,
            h_back_porch    => 88,
            h_sync_cycles   => 44,
            v_front_porch   => 2,
            v_back_porch    => 15,
            v_sync_lines    => 5
        ),
        6 => ( -- 1920x1080p, 60Hz
            width           => 1920,
            height          => 1080,
            pixel_period    => 6.7 ns,
            clk10_mult      => 74, -- 148 Mhz
            clk10_div       => 5,
            interlaced      => false,
            negative_vsync  => false,
            negative_hsync  => false,
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
