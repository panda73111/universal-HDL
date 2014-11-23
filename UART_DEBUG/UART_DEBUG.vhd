----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    19:02:16 09/18/2014 
-- Module Name:    UART_DEBUG - rtl 
-- Project Name:   Pipistrello-HDMI-Tests
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

entity UART_DEBUG is
    generic (
        CLK_IN_PERIOD   : real;
        STR_LEN         : positive := 128;
        PRINT_CRLF      : boolean := true
    );
    port (
        CLK : in std_ulogic;
        RST : in std_ulogic;
        
        MSG     : in string(1 to STR_LEN);
        WR_EN   : in std_ulogic;
        CTS     : in std_ulogic;
        
        BUSY    : out std_ulogic := '0';
        FULL    : out std_ulogic := '0';
        TXD     : out std_ulogic := '1'
    );
end UART_DEBUG;

architecture rtl of UART_DEBUG is
    type state_type is (
        IDLE,
        PRINT_MSG_LETTER,
        PRINT_CR,
        PRINT_LF
    );
    signal state        : state_type := IDLE;
    signal sender_din   : std_ulogic_vector(7 downto 0) := x"00";
    signal sender_wr_en : std_ulogic := '0';
    signal sender_full  : std_ulogic := '0';
    signal sender_busy  : std_ulogic := '0';
    signal char_index   : natural range 1 to STR_LEN := 1;
begin
    
    BUSY    <= '0' when state=IDLE and sender_busy='0' else '1';
    FULL    <= sender_full;
    
    UART_SENDER_inst : entity work.UART_SENDER
        generic map (
            CLK_IN_PERIOD   => CLK_IN_PERIOD
        )
        port map (
            CLK => CLK,
            RST => RST,
            
            DIN     => sender_din,
            WR_EN   => sender_wr_en,
            CTS     => CTS,
            
            TXD     => TXD,
            FULL    => sender_full,
            BUSY    => sender_busy
        );
    
    process(RST, CLK)
    begin
        if RST='1' then
            state           <= IDLE;
            sender_wr_en    <= '0';
            char_index      <= 1;
        elsif rising_edge(CLK) then
            sender_wr_en    <= '0';
            case state is
                
                when IDLE =>
                    char_index  <= 1;
                    if WR_EN='1' then
                        if MSG(1)/=NUL then
                            state   <= PRINT_MSG_LETTER;
                        elsif PRINT_CRLF then
                            state   <= PRINT_CR;
                        end if;
                    end if;
                
                when PRINT_MSG_LETTER =>
                    if sender_full='0' then
                        sender_wr_en    <= '1';
                        sender_din      <= stdulv(MSG(char_index));
                        char_index      <= char_index+1;
                        if
                            char_index=STR_LEN or
                            MSG(char_index+1)=NUL
                        then
                            state   <= IDLE;
                            if PRINT_CRLF then
                                state   <= PRINT_CR;
                            end if;
                        end if;
                    end if;
                
                when PRINT_CR =>
                    if sender_full='0' then
                        sender_wr_en    <= '1';
                        sender_din      <= stdulv(CR);
                        state           <= PRINT_LF;
                    end if;
                
                when PRINT_LF =>
                    if sender_full='0' then
                        sender_wr_en    <= '1';
                        sender_din      <= stdulv(LF);
                        state           <= IDLE;
                    end if;
                
            end case;
        end if;
    end process;
    
end rtl;

