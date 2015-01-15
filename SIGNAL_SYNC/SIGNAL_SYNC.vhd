----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    09:07:49 09/16/2014 
-- Module Name:    SIGNAL_SYNC - rtl 
-- Project Name:   SIGNAL_SYNC
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity SIGNAL_SYNC is
    generic (
        DEFAULT_VALUE   : std_ulogic := '0'
    );
    port (
        CLK : in std_ulogic;
        
        DIN : in std_ulogic;
        
        DOUT    : out std_ulogic := DEFAULT_VALUE
    );
end SIGNAL_SYNC;

architecture rtl of SIGNAL_SYNC is
    signal q    : std_ulogic := DEFAULT_VALUE;
begin
    
--    clk_out_fd0 : FD port map (C => CLK_OUT, D => q,    Q => DOUT);
--    clk_out_fd1 : FD port map (C => CLK_OUT, D => DIN,  Q => q);
    
    sync_proc : process(CLK)
    begin
        if rising_edge(CLK) then
            DOUT    <= q;
            q       <= DIN;
        end if;
    end process;
    
end rtl;

