--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   23:36:00 09/11/2014
-- Module Name:   UART_RECEIVER_tb.vhd
-- Project Name:  UART_RECEIVER
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: UART_RECEIVER
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.txt_util.all;
 
ENTITY SPI_FLASH_CONTROL_tb IS
END SPI_FLASH_CONTROL_tb;

ARCHITECTURE behavior OF SPI_FLASH_CONTROL_tb IS
    
    -- Inputs
    signal clk      : std_ulogic := '0';
    signal rst      : std_ulogic := '0';
    signal addr     : std_ulogic_vector(23 downto 0) := x"000000";
    signal din      : std_ulogic_vector(7 downto 0) := x"00";
    signal rd_en    : std_ulogic := '0';
    signal wr_en    : std_ulogic := '0';
    signal bulk     : std_ulogic := '0';
    signal miso     : std_ulogic := '0';
    
    -- Outputs
    signal dout    : std_ulogic_vector(7 downto 0);
    signal valid   : std_ulogic;
    signal wr_ack  : std_ulogic;
    signal busy    : std_ulogic;
    signal mosi    : std_ulogic;
    signal c       : std_ulogic;
    signal sn      : std_ulogic;
    
    -- clock period definitions
    constant clk_period         : time := 10 ns;
    constant clk_period_real    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
BEGIN

    SPI_FLASH_CONTROL_inst : entity work.SPI_FLASH_CONTROL
        generic map (
            CLK_IN_PERIOD   => clk_period_real,
            CLK_OUT_MULT    => 2,
            CLK_OUT_DIV     => 4
        )
        port map (
            CLK => clk,
            RST => rst,
            
            ADDR    => addr,
            DIN     => din,
            RD_EN   => rd_en,
            WR_EN   => wr_en,
            MISO    => miso,
            
            DOUT    => dout,
            VALID   => valid,
            WR_ACK  => wr_ack,
            BUSY    => busy,
            MOSI    => mosi,
            C       => c,
            SN      => sn
        );
    
    -- clock generation
    clk <= not clk after clk_period / 2;
    
    spi_flash_sim_proc : process
        subtype cmd_type is std_ulogic_vector(7 downto 0);
        constant CMD_WRITE_ENABLE           : cmd_type := x"06";
        constant CMD_SECTOR_ERASE           : cmd_type := x"D8";
        constant CMD_READ_DATA_BYTES        : cmd_type := x"03";
        constant CMD_PAGE_PROGRAM           : cmd_type := x"02";
        constant CMD_READ_STATUS_REGISTER   : cmd_type := x"05";
        constant RETURN_BYTE        : std_ulogic_vector(7 downto 0) := x"AB";
        variable flash_cmd          : cmd_type;
        variable flash_addr         : std_ulogic_vector(23 downto 0);
        variable flash_data_byte    : std_ulogic_vector(7 downto 0);
        variable flash_status       : std_ulogic_vector(7 downto 0);
        variable erasing            : boolean;
        variable erase_start_time   : time;
        variable programming        : boolean;
        variable program_start_time : time;
        
        procedure get_cmd(variable flash_cmd : out cmd_type) is
        begin
            bit_loop : for i in 7 downto 1 loop
                flash_cmd(i)    := mosi;
                wait until rising_edge(c);
                if sn='1' then exit bit_loop; end if;
            end loop;
            flash_cmd(0)    := mosi;
        end procedure;
        
        procedure get_addr(variable flash_addr : out std_ulogic_vector) is
        begin
            wait until rising_edge(c);
            bit_loop : for i in 23 downto 1 loop
                flash_addr(i)   := mosi;
                wait until rising_edge(c);
                if sn='1' then exit bit_loop; end if;
            end loop;
            flash_addr(0)   := mosi;
        end procedure;
        
        procedure get_data_byte(variable flash_data_byte : out std_ulogic_vector) is
        begin
            wait until rising_edge(c);
            bit_loop : for i in 7 downto 1 loop
                flash_data_byte(i)  := mosi;
                wait until rising_edge(c);
                if sn='1' then exit bit_loop; end if;
            end loop;
            flash_data_byte(0)  := mosi;
        end procedure;
        
        procedure send_status(variable flash_status : in std_ulogic_vector) is
        begin
            bit_loop : for i in 7 downto 0 loop
                wait until falling_edge(c);
                miso    <= flash_status(i);
                if sn='1' then exit bit_loop; end if;
                wait until rising_edge(c);
            end loop;
        end procedure;
        
        procedure send_data_byte is
        begin
            bit_loop : for i in 7 downto 0 loop
                wait until falling_edge(c);
                miso    <= RETURN_BYTE(i);
                wait until rising_edge(c);
                if sn='1' then exit bit_loop; end if;
            end loop;
        end procedure;
    begin
        flash_status    := x"00";
        loop
            wait until rising_edge(c);
            
            if erasing and now-erase_start_time>=2 ms then
                -- more realistic erase time: 800 ms. Nobody got time for that...
                erasing         := false;
                flash_status(0) := '0';
            end if;
            
            if programming and now-program_start_time>=800 us then
                programming     := false;
                flash_status(0) := '0';
            end if;
            
            if sn='0' then
                
                get_cmd(flash_cmd);
                report "Got command: " & hstr(flash_cmd);
                
                case flash_cmd is
                    
                    when CMD_WRITE_ENABLE =>
                        if flash_status(0)='0' then
                            report "Setting WRITE ENABLE bit";
                            flash_status(1) := '1';
                        end if;
                        if sn='0' then wait until sn='1'; end if;
                        next;
                    
                    when CMD_READ_STATUS_REGISTER =>
                        while sn='0' loop
                            report "Sending status";
                            send_status(flash_status);
                        end loop;
                        next;
                    
                    when others =>
                        if
                            flash_cmd/=CMD_READ_DATA_BYTES and
                            flash_cmd/=CMD_SECTOR_ERASE and
                            flash_cmd/=CMD_PAGE_PROGRAM
                        then
                            report "Unknown command: " & hstr(flash_cmd);
                            if sn='0' then wait until sn='1'; end if;
                            next;
                        end if;
                    
                end case;
                
                get_addr(flash_addr);
                report "Got address: " & hstr(flash_addr);
                
                case flash_cmd is
                    
                    when CMD_READ_DATA_BYTES =>
                        if flash_status(0)='0' then
                            while sn='0' loop
                                report "Reading byte: " & hstr(RETURN_BYTE);
                                send_data_byte;
                            end loop;
                        else
                            if sn='0' then wait until sn='1'; end if;
                        end if;
                        next;
                    
                    when CMD_SECTOR_ERASE =>
                        wait until rising_edge(c);
                        if sn='1' then
                            if flash_status(1 downto 0)="10" then
                                report "Erasing sector: " & hstr(flash_addr(23 downto 16) & x"0000");
                            end if;
                            flash_status(1) := '0';
                        else
                            wait until sn='1';
                        end if;
                        erasing             := true;
                        erase_start_time    := now;
                        flash_status(0)     := '1';
                        next;
                    
                    when CMD_PAGE_PROGRAM =>
                        while sn='0' loop
                            get_data_byte(flash_data_byte);
                            if flash_status(1 downto 0)="10" then
                                report "Writing byte: " & hstr(flash_data_byte);
                            end if;
                        end loop;
                        flash_status(1)     := '0';
                        programming         := true;
                        program_start_time  := now;
                        flash_status(0)     := '1';
                        next;
                    
                    when others =>
                        null;
                    
                end case;
                
            end if;
        end loop;
    end process;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*10;
        wait until rising_edge(clk);
        
        -- insert stimulus here
        
        wait until rising_edge(clk) and busy='0';
        
        -- read one byte at address 0xABCDEF
        wait until rising_edge(clk);
        addr    <= x"ABCDEF";
        rd_en   <= '1';
        wait until rising_edge(clk);
        rd_en   <= '0';
        wait until rising_edge(clk);
        
        wait until falling_edge(busy);
        wait for 10 us;
        
        -- write one byte 0x77 at address 0xABCDEF
        wait until rising_edge(clk);
        addr    <= x"ABCDEF";
        din     <= x"77";
        wr_en   <= '1';
        wait until rising_edge(clk);
        wr_en   <= '0';
        wait until rising_edge(clk);
        
        wait until falling_edge(busy);
        wait for 10 us;
        report "NONE. All tests completed." severity failure;
    end process;
    
END;