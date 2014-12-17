library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;
use work.video_profiles.all;

entity TEST_FRAME_GEN is
    generic (
        CLK_IN_PERIOD           : real;
        FRAME_STEP              : natural := 200;
        ANIMATED                : boolean := false;
        R_BITS                  : natural range 1 to 12 := 8;
        G_BITS                  : natural range 1 to 12 := 8;
        B_BITS                  : natural range 1 to 12 := 8;
        DIF_FRAMES              : natural range 1 to 5 := 5; -- '1' means a white frame only
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
        
        HSYNC       : out std_ulogic := '0';
        VSYNC       : out std_ulogic := '0';
        RGB_ENABLE  : out std_ulogic := '0';
        R           : out std_ulogic_vector(R_BITS-1 downto 0) := (others => '0');
        G           : out std_ulogic_vector(G_BITS-1 downto 0) := (others => '0');
        B           : out std_ulogic_vector(B_BITS-1 downto 0) := (others => '0')
    );
end TEST_FRAME_GEN;

architecture rtl of TEST_FRAME_GEN is
    
    constant MAX_BITS   : natural := max(R_BITS, max(G_BITS, B_BITS));
    constant GRAD_LIMIT : natural := (2**MAX_BITS)-1;
    constant R_LOW      : natural := MAX_BITS-R_BITS;
    constant G_LOW      : natural := MAX_BITS-G_BITS;
    constant B_LOW      : natural := MAX_BITS-B_BITS;
    
    type reg_type is record
        r   : std_ulogic_vector(R_BITS-1 downto 0);
        g   : std_ulogic_vector(R_BITS-1 downto 0);
        b   : std_ulogic_vector(R_BITS-1 downto 0);
    end record;
    
    constant reg_type_def    : reg_type := (
        r   => (others => '0'),
        g   => (others => '0'),
        b   => (others => '0')
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal pix_clk  : std_ulogic := '0';
    
    signal frame_count  : natural := 0;
    signal vp           : video_profile_type;
    
    signal x            : std_ulogic_vector(X_BITS-1 downto 0) := (others => '0');
    signal y            : std_ulogic_vector(Y_BITS-1 downto 0) := (others => '0');
    signal pos_vsync    : std_ulogic := '0';
    signal pos_vsync_q  : std_ulogic := '0';
    signal pos_hsync    : std_ulogic := '0';
    
    signal hsync_out    : std_ulogic := '0';
    signal vsync_out    : std_ulogic := '0';
    signal hsync_q      : std_ulogic := '0';
    signal vsync_q      : std_ulogic := '0';
    
    signal rgb_enable_out   : std_ulogic := '0';
    signal rgb_enable_q     : std_ulogic := '0';
    
begin
    
    CLK_OUT <= pix_clk;
    
    R   <= cur_reg.r;
    G   <= cur_reg.g;
    B   <= cur_reg.b;
    
    HSYNC   <= hsync_q;
    VSYNC   <= vsync_q;
    
    RGB_ENABLE  <= rgb_enable_q;
    
    vp  <= video_profiles(int(PROFILE));
    
    VIDEO_TIMING_GEN_inst : entity work.VIDEO_TIMING_GEN
        generic map (
            CLK_IN_PERIOD           => CLK_IN_PERIOD,
            CLK_IN_TO_CLK10_MULT    => CLK_IN_TO_CLK10_MULT,
            CLK_IN_TO_CLK10_DIV     => CLK_IN_TO_CLK10_DIV,
            PROFILE_BITS            => PROFILE_BITS,
            X_BITS                  => X_BITS,
            Y_BITS                  => Y_BITS
        )
        port map (
            CLK_IN  => CLK_IN,
            RST     => RST,
            
            PROFILE => PROFILE,
            
            CLK_OUT => pix_clk,
            
            POS_VSYNC   => pos_vsync,
            POS_HSYNC   => pos_hsync,
            VSYNC       => vsync_out,
            HSYNC       => hsync_out,
            RGB_ENABLE  => rgb_enable_out,
            RGB_X       => x,
            RGB_Y       => y
        );
    
    stm_proc : process (frame_count, vp, x, y, rgb_enable_out)
        variable x_grad     : unsigned(MAX_BITS downto 0) := (others => '0');
        variable y_grad     : unsigned(MAX_BITS downto 0) := (others => '0');
        variable x_grad_inv : unsigned(MAX_BITS downto 0) := (others => '0');
        variable y_grad_inv : unsigned(MAX_BITS downto 0) := (others => '0');
        variable xy0_grad   : unsigned(MAX_BITS-1 downto 0) := (others => '0');
        variable xy1_grad   : unsigned(MAX_BITS-1 downto 0) := (others => '0');
        variable xy2_grad   : unsigned(MAX_BITS-1 downto 0) := (others => '0');
        variable frame_perc : natural := 0;
    begin
        if vp.width=0 or vp.height=0 or rgb_enable_out='0' then
            x_grad  := (others => '0');
            y_grad  := (others => '0');
        else
            if ANIMATED then
                frame_perc  := (frame_count mod FRAME_STEP) * 100 / FRAME_STEP;
                x_grad      := uns(((nat(x)*1000*frame_perc/100)/vp.width*GRAD_LIMIT)/1000, MAX_BITS+1);
                y_grad      := uns(((nat(y)*1000*frame_perc/100)/vp.height*GRAD_LIMIT)/1000, MAX_BITS+1);
            else
                x_grad  := uns(((nat(x)*1000)/vp.width*GRAD_LIMIT)/1000, MAX_BITS+1);
                y_grad  := uns(((nat(y)*1000)/vp.height*GRAD_LIMIT)/1000, MAX_BITS+1);
            end if;
        end if;
      
        x_grad_inv  := GRAD_LIMIT-x_grad;
        y_grad_inv  := GRAD_LIMIT-y_grad;
        xy0_grad    := resize((x_grad+y_grad)/2, MAX_BITS);
        xy1_grad    := resize((x_grad_inv+y_grad)/2, MAX_BITS);
        xy2_grad    := resize((x_grad+y_grad_inv)/2, MAX_BITS);
        
        case (frame_count / (FRAME_STEP + 1)) mod 5 is
            when 0 =>
                -- full white
                next_reg.r  <= (others => '1');
                next_reg.g  <= (others => '1');
                next_reg.b  <= (others => '1');
            
            when 1 =>
                -- green gradient
                next_reg.r  <= (others => '0');
                next_reg.g  <= stdulv(xy0_grad(MAX_BITS-1 downto G_LOW));
                next_reg.b  <= (others => '0');
            
            when 2 =>
                -- red gradient
                next_reg.r  <= stdulv(xy1_grad(MAX_BITS-1 downto R_LOW));
                next_reg.g  <= (others => '0');
                next_reg.b  <= (others => '0');
            
            when 3 =>
                -- blue gradient
                next_reg.r  <= (others => '0');
                next_reg.g  <= (others => '0');
                next_reg.b  <= stdulv(xy2_grad(MAX_BITS-1 downto B_LOW));
            
            when others =>
                -- mixed color gradients
                next_reg.r  <= stdulv(xy1_grad(MAX_BITS-1 downto R_LOW));
                next_reg.g  <= stdulv(xy0_grad(MAX_BITS-1 downto G_LOW));
                next_reg.b  <= stdulv(xy2_grad(MAX_BITS-1 downto B_LOW));
        
        end case;
    end process;
    
    frame_count_proc : process (RST, pix_clk)
    begin
        if RST='1' then
            frame_count <= 0;
        elsif rising_edge(pix_clk) then
            if pos_vsync_q='0' and pos_vsync='1' then
                -- new frame
                frame_count <= frame_count+1;
                if frame_count>=(FRAME_STEP+1)*DIF_FRAMES-1 then
                    frame_count <= 0;
                end if;
            end if;
            pos_vsync_q     <= pos_vsync;
            hsync_q         <= hsync_out;
            vsync_q         <= vsync_out;
            rgb_enable_q    <= rgb_enable_out;
        end if;
    end process;
    
    stm_sync_proc : process (RST, pix_clk)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(pix_clk) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end rtl;

