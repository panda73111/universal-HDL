----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    10:40:26 02/07/2014
-- Module Name:    OSERDES2_CLK_MAN - rtl
-- Description:    Clock manager intended for use with OSERDES2
--
-- Revision: 0
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity OSERDES2_CLK_MAN is
    generic (
        CLK_IN_PERIOD   : real;
        MULTIPLIER      : natural range 1 to 64 := 1;
        PREDIVISOR      : natural range 1 to 52 := 1;
        DIVISOR0        : natural range 1 to 128 := 1;
        DIVISOR1        : natural range 1 to 128 := 1;
        DIVISOR2        : natural range 1 to 128 := 1;
        DIVISOR3        : natural range 1 to 128 := 1;
        DIVISOR4        : natural range 1 to 128 := 1;
        DIVISOR5        : natural range 1 to 128 := 1;
        DATA_CLK_SELECT : natural range 0 to 5:= 0;
        IO_CLK_SELECT   : natural range 0 to 5:= 1
    );
    port (
        CLK_IN          : in  std_ulogic;
        CLK_OUT0        : out std_ulogic := '0';
        CLK_OUT1        : out std_ulogic := '0';
        CLK_OUT2        : out std_ulogic := '0';
        CLK_OUT3        : out std_ulogic := '0';
        CLK_OUT4        : out std_ulogic := '0';
        CLK_OUT5        : out std_ulogic := '0';
        IOCLK_OUT       : out std_ulogic := '0';
        IOCLK_LOCKED    : out std_ulogic := '0';
        SERDESSTROBE    : out std_ulogic := '0'
    );
end OSERDES2_CLK_MAN;

architecture rtl of OSERDES2_CLK_MAN is
    type divs_arr_type is array(0 to 5) of natural;
    constant divisors   : divs_arr_type :=
        (DIVISOR0, DIVISOR1, DIVISOR2,
        DIVISOR3, DIVISOR4, DIVISOR5);
    constant bufpll_divide  : natural := divisors(DATA_CLK_SELECT);
        
    signal clk_in_buf       : std_ulogic := '0';
    signal pll_base_clkfb   : std_ulogic := '0';
    signal pll_base_locked  : std_ulogic := '0';
    signal clk0     : std_ulogic := '0';
    signal clk0_buf : std_ulogic := '0';
    signal clk1     : std_ulogic := '0';
    signal clk1_buf : std_ulogic := '0';
    signal clk2     : std_ulogic := '0';
    signal clk2_buf : std_ulogic := '0';
    signal clk3     : std_ulogic := '0';
    signal clk3_buf : std_ulogic := '0';
    signal clk4     : std_ulogic := '0';
    signal clk4_buf : std_ulogic := '0';
    signal clk5     : std_ulogic := '0';
    signal clk5_buf : std_ulogic := '0';
    signal bufpll_ioclk_in  : std_ulogic := '0';
    signal bufpll_gclk_in   : std_ulogic := '0';
begin
    
    CLK_OUT0    <= clk0_buf;
    CLK_OUT1    <= clk1_buf;
    CLK_OUT2    <= clk2_buf;
    CLK_OUT3    <= clk3_buf;
    CLK_OUT4    <= clk4_buf;
    CLK_OUT5    <= clk5_buf;
    
    BUFIO2_inst : BUFIO2
        port map (
            I               => CLK_IN,
            DIVCLK          => clk_in_buf,
            IOCLK           => open,
            SERDESSTROBE    => open
        );
    
    PLL_BASE_inst : PLL_BASE
        generic map (
            COMPENSATION    => "SYSTEM_SYNCHRONOUS",
            CLK_FEEDBACK    => "CLKFBOUT",
            CLKFBOUT_MULT   => MULTIPLIER,
            DIVCLK_DIVIDE   => PREDIVISOR,
            CLKOUT0_DIVIDE  => DIVISOR0,
            CLKOUT1_DIVIDE  => DIVISOR1,
            CLKOUT2_DIVIDE  => DIVISOR2,
            CLKOUT3_DIVIDE  => DIVISOR3,
            CLKOUT4_DIVIDE  => DIVISOR4,
            CLKOUT5_DIVIDE  => DIVISOR5,
            CLKIN_PERIOD    => CLK_IN_PERIOD
        )
        port map (
            CLKIN       => clk_in_buf,
            CLKFBIN     => pll_base_clkfb,
            RST         => '0',
            CLKOUT0     => clk0,
            CLKOUT1     => clk1,
            CLKOUT2     => clk2,
            CLKOUT3     => clk3,
            CLKOUT4     => clk4,
            CLKOUT5     => clk5,
            CLKFBOUT    => pll_base_clkfb,
            LOCKED      => pll_base_locked
        );
    
    BUFG_CLK0_inst : BUFG port map (I => clk0, O => clk0_buf);
    BUFG_CLK1_inst : BUFG port map (I => clk1, O => clk1_buf);
    BUFG_CLK2_inst : BUFG port map (I => clk2, O => clk2_buf);
    BUFG_CLK3_inst : BUFG port map (I => clk3, O => clk3_buf);
    BUFG_CLK4_inst : BUFG port map (I => clk4, O => clk4_buf);
    BUFG_CLK5_inst : BUFG port map (I => clk5, O => clk5_buf);
    
    with DATA_CLK_SELECT select
        bufpll_gclk_in <=
            clk0_buf when 0,
            clk1_buf when 1,
            clk2_buf when 2,
            clk3_buf when 3,
            clk4_buf when 4,
            clk5_buf when 5,
            'U' when others;
    
    with IO_CLK_SELECT select
        bufpll_ioclk_in <=
            clk0 when 0,
            clk1 when 1,
            clk2 when 2,
            clk3 when 3,
            clk4 when 4,
            clk5 when 5,
            'U' when others;
    
    BUFPLL_inst : BUFPLL
        generic map (
            DIVIDE      => bufpll_divide,
            ENABLE_SYNC => true
        )
        port map (
            GCLK            => bufpll_gclk_in,
            PLLIN           => bufpll_ioclk_in,
            LOCKED          => pll_base_locked,
            LOCK            => IOCLK_LOCKED,
            IOCLK           => IOCLK_OUT,
            SERDESSTROBE    => SERDESSTROBE
        );
    
end rtl;


