----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    13:19:55 09/16/2014 
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

entity FLAG_SYNC is
    port (
        CLK_IN  : in std_ulogic;
        CLK_OUT : in std_ulogic;
        
        DIN : in std_ulogic;
        
        DOUT    : out std_ulogic := '0'
    );
end FLAG_SYNC;

architecture rtl of FLAG_SYNC is
    signal toggle_in        : std_ulogic := '0';
    signal toggle_in_sync   : std_ulogic := '0';
    signal q0, q1, q2       : std_ulogic := '0';
begin
    
    DOUT        <= q2 xor q1;
    toggle_in   <= toggle_in_sync xor DIN;
    
--    clk_in_fd   : FD port map (C => CLK_IN,  D => toggle_in, Q => toggle_in_sync);
    
--    clk_out_fd0 : FD port map (C => CLK_OUT, D => q1,        Q => q2);
--    clk_out_fd1 : FD port map (C => CLK_OUT, D => q0,        Q => q1);
--    clk_out_fd2 : FD port map (C => CLK_OUT, D => toggle_in, Q => q0);
    
    sync_in_proc : process(CLK_IN)
    begin
        if rising_edge(CLK_IN) then
            toggle_in_sync  <= toggle_in;
        end if;
    end process;
    
    sync_out_proc : process(CLK_OUT)
    begin
        if rising_edge(CLK_OUT) then
            q2  <= q1;
            q1  <= q0;
            q0  <= toggle_in;
        end if;
    end process;
    
end rtl;

