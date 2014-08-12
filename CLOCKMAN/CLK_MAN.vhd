----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    18:07:14 01/25/2014 
-- Design Name:    clkman
-- Module Name:    clkman - rtl
-- Tool versions:  Xilinx ISE 14.7
-- Description:    
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

entity CLK_MAN is
    generic (
        CLK_IN_PERIOD : real;
        MULTIPLIER    : natural range 2 to 256 := 1;
        DIVISOR       : natural range 1 to 256 := 1
    );
    port (
        CLK_IN          : in  std_ulogic;
        
        CLK_OUT         : out std_ulogic := '0';
        CLK_OUT_180     : out std_ulogic := '0';
        
        CLK_IN_STOPPED  : out std_ulogic := '0';
        CLK_OUT_STOPPED : out std_ulogic := '0'
    );
end;

architecture rtl of CLK_MAN is
    signal status   : std_logic_vector(1 downto 0) := "00";
begin

    CLK_IN_STOPPED  <= std_ulogic(status(0));
    CLK_OUT_STOPPED <= std_ulogic(status(1));
    
    inst_dcm_clkgen : DCM_CLKGEN
        generic map (
            CLKIN_PERIOD    => CLK_IN_PERIOD,
            CLKFX_MULTIPLY  => MULTIPLIER,
            CLKFX_DIVIDE    => DIVISOR
            )
        port map (
            CLKIN       => CLK_IN,
            CLKFX       => CLK_OUT,
            CLKFX180    => CLK_OUT_180,
            STATUS      => status
            );

end;

