library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity test_camera is
    generic (
        WAIT_CYCLES     : natural := 100;
        FRAME_STEP      : natural := 200;
        ANIMATED        : boolean := false;
        FRAME_SIZE_BITS : natural := 11;
        R_BITS          : natural range 1 to 12 := 8;
        G_BITS          : natural range 1 to 12 := 8;
        B_BITS          : natural range 1 to 12 := 8;
        DIF_FRAMES      : natural range 1 to 5 := 5 -- '1' means a white frame only
        );
    port (
        CLK, RST        : in std_ulogic;
        WIDTH, HEIGHT   : in std_ulogic_vector(FRAME_SIZE_BITS-1 downto 0);
        HSYNC           : out std_ulogic := '0';
        VSYNC           : out std_ulogic := '0';
        R               : out std_ulogic_vector(R_BITS-1 downto 0) := (others => '0');
        G               : out std_ulogic_vector(G_BITS-1 downto 0) := (others => '0');
        B               : out std_ulogic_vector(B_BITS-1 downto 0) := (others => '0')
        );
end test_camera;

architecture rtl of test_camera is
    
    constant MAX_BITS   : natural := max(R_BITS, max(G_BITS, B_BITS));
    constant GRAD_LIMIT : natural := (2**MAX_BITS)-1;
    constant R_LOW      : natural := MAX_BITS-R_BITS;
    constant G_LOW      : natural := MAX_BITS-R_BITS;
    constant B_LOW      : natural := MAX_BITS-R_BITS;
    
    type reg_type is record
        x   : natural;
        y   : natural;
        r   : std_ulogic_vector(R_BITS-1 downto 0);
        g   : std_ulogic_vector(R_BITS-1 downto 0);
        b   : std_ulogic_vector(R_BITS-1 downto 0);
    end record;
    
    constant reg_type_def    : reg_type := (
        0, 0, -- x, y
        (others => '0'), -- r
        (others => '0'), -- g
        (others => '0') -- b
        );
    
    signal width_i, height_i    : natural := 0;
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    signal frame_count          : natural := 0;
    signal pause_count          : natural := 0;
    signal pausing              : std_ulogic := '1';
    
    signal vsync_pre, hsync_pre : std_ulogic := '0';
    
begin
    
    R   <= cur_reg.r;
    G   <= cur_reg.g;
    B   <= cur_reg.b;
    
    width_i     <= to_integer(unsigned(WIDTH));
    height_i    <= to_integer(unsigned(HEIGHT));
    
    iterate : process (cur_reg, frame_count, width_i, height_i)
        variable nx         : natural := 0;
        variable ny         : natural := 0;
        variable x_grad     : unsigned(MAX_BITS downto 0) := to_unsigned(0, MAX_BITS+1);
        variable y_grad     : unsigned(MAX_BITS downto 0) := to_unsigned(0, MAX_BITS+1);
        variable x_grad_inv : unsigned(MAX_BITS downto 0) := to_unsigned(0, MAX_BITS+1);
        variable y_grad_inv : unsigned(MAX_BITS downto 0) := to_unsigned(0, MAX_BITS+1);
        variable xy0_grad   : unsigned(MAX_BITS-1 downto 0) := to_unsigned(0, MAX_BITS);
        variable xy1_grad   : unsigned(MAX_BITS-1 downto 0) := to_unsigned(0, MAX_BITS);
        variable xy2_grad   : unsigned(MAX_BITS-1 downto 0) := to_unsigned(0, MAX_BITS);
        variable frame_perc : natural := 0;
    begin
        next_reg    <= reg_type_def;
        
        if width_i/=0 and height_i/=0 then
            
            if cur_reg.x=width_i-1 and cur_reg.y=height_i-1 then
                -- end of frame
                nx  := 0;
                ny  := 0;
            elsif cur_reg.x=width_i-1 then
                -- end of line
                nx  := 0;
                ny  := cur_reg.y+1;
            else
                nx  := cur_reg.x+1;
                ny  := cur_reg.y;
            end if;
            
            next_reg.x  <= nx;
            next_reg.y  <= ny;
            
            if animated then
                frame_perc  := (frame_count mod FRAME_STEP) * 100 / FRAME_STEP;
                --if frame_perc > 100 then frame_perc := 100; end if;
                x_grad  := to_unsigned(((nx*1000*frame_perc/100)/width_i*GRAD_LIMIT)/1000, MAX_BITS+1);
                y_grad  := to_unsigned(((ny*1000*frame_perc/100)/height_i*GRAD_LIMIT)/1000, MAX_BITS+1);
            else
                x_grad  := to_unsigned(((nx*1000)/width_i*GRAD_LIMIT)/1000, MAX_BITS+1);
                y_grad  := to_unsigned(((ny*1000)/height_i*GRAD_LIMIT)/1000, MAX_BITS+1);
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
                    next_reg.g  <= std_ulogic_vector(xy0_grad(MAX_BITS-1 downto G_LOW));
                    next_reg.b  <= (others => '0');
                
                when 2 =>
                    -- red gradient
                    next_reg.r  <= std_ulogic_vector(xy1_grad(MAX_BITS-1 downto R_LOW));
                    next_reg.g  <= (others => '0');
                    next_reg.b  <= (others => '0');
                
                when 3 =>
                    -- blue gradient
                    next_reg.r  <= (others => '0');
                    next_reg.g  <= (others => '0');
                    next_reg.b  <= std_ulogic_vector(xy2_grad(MAX_BITS-1 downto B_LOW));
                
                when others =>
                    -- mixed color gradients
                    next_reg.r  <= std_ulogic_vector(xy1_grad(MAX_BITS-1 downto R_LOW));
                    next_reg.g  <= std_ulogic_vector(xy0_grad(MAX_BITS-1 downto G_LOW));
                    next_reg.b  <= std_ulogic_vector(xy2_grad(MAX_BITS-1 downto B_LOW));
            
            end case;
            
        end if;
    end process;
    
    pause : process (RST, CLK)
    begin
        if RST='1' then
            pausing     <= '1';
            pause_count <= 0;
            frame_count <= 0;
            vsync_pre       <= '0';
            hsync_pre       <= '0';
        elsif rising_edge(CLK) then
            if cur_reg.x=width_i-1 then
                -- end of line
                hsync_pre   <= '0';
                pausing     <= '1';
                if cur_reg.y=height_i-1 then
                    -- end of frame
                    if frame_count>=(FRAME_STEP+1)*DIF_FRAMES-1 then
                        frame_count <= 0;
                    else
                        frame_count <= frame_count+1;
                    end if;
                    vsync_pre   <= '0';
                end if;
            end if;
            if pausing='1' then
                if pause_count=WAIT_CYCLES-1 then
                    pause_count <= 0;
                    pausing     <= '0';
                    vsync_pre   <= '1';
                    hsync_pre   <= '1';
                else
                    pause_count <= pause_count+1;
                end if;
            end if;
        end if;
    end process;
    
    sync : process (RST, CLK)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
            VSYNC   <= '0';
            HSYNC   <= '0';
        elsif rising_edge(clk) then
            if pausing='0' then
                cur_reg <= next_reg;
            end if;
            VSYNC   <= vsync_pre;
            HSYNC   <= hsync_pre;
        end if;
    end process;
    
end rtl;

