----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    14:18:44 12/01/2014 
-- Module Name:    IPROG_RECONF_test - rtl 
-- Tool versions:  Xilinx ISE 14.7
-- Description: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity IPROG_RECONF_test is
    generic (
        BITFILE_SELECT      : natural range 0 to 1 := 1;
        BITFILE_ADDR_0      : std_ulogic_vector(23 downto 0) := x"000000";
        BITFILE_ADDR_1      : std_ulogic_vector(23 downto 0) := x"060000";
        CYCLES_TO_REPROG    : natural := 50_000_000 * 5 -- 5 sec
    );
    port (
        CLK20   : in std_ulogic;
        
        PMOD0   : out std_ulogic_vector(3 downto 0) := "0000"
    );
end IPROG_RECONF_test;

architecture rtl of IPROG_RECONF_test is
    
    type bitfile_addrs_type is array(0 to 1) of
        std_ulogic_vector(23 downto 0);
    
    constant bitfile_addrs  : bitfile_addrs_type := (
        BITFILE_ADDR_0,
        BITFILE_ADDR_1
    );
    
    signal cycle_cnt    : natural range 0 to CYCLES_TO_REPROG-1 := 0;
    signal iprog_en     : std_ulogic := '0';
    
begin
    
    PMOD0(BITFILE_SELECT)   <= '1';
    
    count_proc : process(CLK20)
    begin
        if rising_edge(CLK20) then
            iprog_en    <= '0';
            cycle_cnt   <= cycle_cnt+1;
            if cycle_cnt=CYCLES_TO_REPROG-1 then
                iprog_en    <= '1';
                cycle_cnt   <= 0;
            end if;
        end if;
    end process;
    
    IPROG_RECONF_inst : entity work.IPROG_RECONF
        generic map (
            START_ADDR      => bitfile_addrs(1-BITFILE_SELECT),
            FALLBACK_ADDR   => bitfile_addrs(BITFILE_SELECT)
        )
        port map (
            CLK => CLK20,
            
            EN  => iprog_en
        );
    
end rtl;
