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
        CLK_IN_PERIOD           : real := 50.0;
        CLK_IN_TO_CLK10_MULT    : natural := 1;
        CLK_IN_TO_CLK10_DIV     : natural := 2;
        PROFILE_BITS            : natural := log2(VIDEO_PROFILE_COUNT);
        X_BITS                  : natural := 12;
        Y_BITS                  : natural := 12
    );
    port (
        CLK_IN  : in std_ulogic;
        RST     : in std_ulogic;
        
        PROFILE : in std_ulogic_vector(PROFILE_BITS-1 downto 0);
        
        CLK_OUT         : out std_ulogic := '0';
        CLK_OUT_LOCKED  : out std_ulogic := '0';
        
        POS_VSYNC   : out std_ulogic := '0';
        POS_HSYNC   : out std_ulogic := '0';
        VSYNC       : out std_ulogic := '0';
        HSYNC       : out std_ulogic := '0';
        X           : out std_ulogic_vector(X_BITS-1 downto 0) := (others => '0');
        Y           : out std_ulogic_vector(Y_BITS-1 downto 0) := (others => '0');
        RGB_ENABLE  : out std_ulogic := '0';
        RGB_X       : out std_ulogic_vector(X_BITS-1 downto 0) := (others => '0');
        RGB_Y       : out std_ulogic_vector(Y_BITS-1 downto 0) := (others => '0')
    );
end VIDEO_TIMING_GEN;

architecture rtl of VIDEO_TIMING_GEN is
    
    type state_type is (
        HOR_SYNC,
        HOR_FRONT_PORCH,
        PIXEL,
        HOR_BACK_PORCH
    );
    
    type reg_type is record
        state               : state_type;
        x                   : natural range 0 to 2**X_BITS-1;
        y                   : natural range 0 to 2**Y_BITS-1;
        ver_rgb_enable      : std_ulogic;
        hor_rgb_enable      : std_ulogic;
        pos_vsync           : std_ulogic;
        pos_hsync           : std_ulogic;
        extra_blank_line    : natural range 0 to 1;
    end record;
    
    constant reg_type_def   : reg_type := (
        state               => HOR_SYNC,
        x                   => 0,
        y                   => 0,
        ver_rgb_enable      => '0',
        hor_rgb_enable      => '0',
        pos_vsync           => '0',
        pos_hsync           => '0',
        extra_blank_line    => 0
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal pix_clk  : std_ulogic := '0';
    
    signal vp               : video_profile_type;
    signal total_ver_lines  : natural range 0 to 2**(Y_BITS+1)-1;
    signal total_hor_pixels : natural range 0 to 2**(X_BITS+1)-1;
    signal clk_locked       : std_ulogic := '0';
    signal x_q              : std_ulogic_vector(X_BITS-1 downto 0) := (others => '0');
    signal y_q              : std_ulogic_vector(Y_BITS-1 downto 0) := (others => '0');
    
    signal cur_profile  : std_ulogic_vector(PROFILE_BITS-1 downto 0) := (others => '0');
    signal profile_set  : boolean := false;
    signal reprog_mult  : std_ulogic_vector(7 downto 0) := x"00";
    signal reprog_div   : std_ulogic_vector(7 downto 0) := x"00";
    signal reprog_en    : std_ulogic := '0';
    signal rst_stm      : std_ulogic := '1';
    
    signal v_sync_end, v_rgb_start, v_rgb_end   : natural range 0 to 2**(Y_BITS+1)-1 := 0;
    signal h_sync_end, h_rgb_start, h_rgb_end   : natural range 0 to 2**(X_BITS+1)-1 := 0;
    
begin
    
    CLK_OUT         <= pix_clk;
    CLK_OUT_LOCKED  <= clk_locked;
    
    POS_VSYNC   <= cur_reg.pos_vsync;
    POS_HSYNC   <= cur_reg.pos_hsync;
    VSYNC       <= cur_reg.pos_vsync xor sel(vp.negative_vsync, '1', '0');
    HSYNC       <= cur_reg.pos_hsync xor sel(vp.negative_hsync, '1', '0');
    X           <= x_q;
    Y           <= y_q;
    RGB_ENABLE  <= cur_reg.ver_rgb_enable and cur_reg.hor_rgb_enable;
    RGB_X       <= x_q-vp.h_sync_cycles-vp.h_front_porch;
    RGB_Y       <= y_q-vp.v_sync_lines-vp.v_front_porch;
    
    vp  <= video_profiles(int(PROFILE));
    
    total_ver_lines     <= vp.v_sync_lines + vp.v_front_porch + vp.height +
                            vp.v_back_porch + cur_reg.extra_blank_line;
    
    total_hor_pixels    <= vp.h_sync_cycles + vp.h_front_porch + vp.width +
                            vp.h_back_porch;
    
    v_sync_end  <= vp.v_sync_lines;
    v_rgb_start <= vp.v_sync_lines+vp.v_front_porch+cur_reg.extra_blank_line;
    v_rgb_end   <= vp.v_sync_lines+vp.v_front_porch+cur_reg.extra_blank_line+vp.height;
    
    h_sync_end  <= vp.h_sync_cycles;
    h_rgb_start <= vp.h_sync_cycles+vp.h_front_porch;
    h_rgb_end   <= vp.h_sync_cycles+vp.h_front_porch+vp.width;
    
    reprog_mult <= stdulv(vp.clk10_mult*CLK_IN_TO_CLK10_MULT, 8);
    reprog_div  <= stdulv(vp.clk10_div*CLK_IN_TO_CLK10_DIV, 8);
    
    rst_stm <= not clk_locked;
    
    CLK_MAN_inst : entity work.CLK_MAN
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD,
            MULTIPLIER      => 2,
            DIVISOR         => 2
        )
        port map (
            CLK_IN  => CLK_IN,
            RST     => RST,
            
            REPROG_MULT => reprog_mult,
            REPROG_DIV  => reprog_div,
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
        elsif rising_edge(CLK_IN) then
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
            end if;
        end if;
    end process;
    
    stm_proc : process(rst_stm, cur_reg, vp, PROFILE, total_hor_pixels, total_ver_lines,
        v_sync_end, v_rgb_start, v_rgb_end, h_sync_end, h_rgb_start, h_rgb_end)
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
            cr.extra_blank_line=0 or
            x=total_hor_pixels/2 -- vsync offset every other interlaced frame
        then
            -- vertical synchronisation
            if y=0 then
                r.pos_vsync := '1';
            end if;
            if y=v_sync_end then
                r.pos_vsync := '0';
            end if;
        end if;
        
        -- vertical RGB enable
        if y=v_rgb_start then
            r.ver_rgb_enable    := '1';
        end if;
        if y=v_rgb_end then
            r.ver_rgb_enable    := '0';
        end if;
        
        case cr.state is
            
            when HOR_SYNC =>
                r.pos_hsync := '1';
                if x=h_sync_end-1 then
                    r.state := HOR_FRONT_PORCH;
                end if;
            
            when HOR_FRONT_PORCH =>
                if x=h_rgb_start-1 then
                    r.state := PIXEL;
                end if;
            
            when PIXEL =>
                r.hor_rgb_enable    := '1';
                if x=h_rgb_end-1 then
                    r.state := HOR_BACK_PORCH;
                end if;
            
            when HOR_BACK_PORCH =>
                if x=total_hor_pixels-1 then
                    -- line switch
                    r.x := 0;
                    r.y := y+1;
                    if cr.y=total_ver_lines-1 then
                        -- frame switch
                        r.y := 0;
                        -- one extra vertical front porch blank line
                        -- every other frame when interlaced
                        r.extra_blank_line  := (cr.extra_blank_line+1) mod 2;
                    end if;
                    r.state := HOR_SYNC;
                end if;
            
        end case;
                
        if not vp.interlaced then
            r.extra_blank_line  := 0;
        end if;
        
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
            x_q     <= stdulv(cur_reg.x, X_BITS);
            y_q     <= stdulv(cur_reg.y, Y_BITS);
        end if;
    end process;
    
end rtl;
