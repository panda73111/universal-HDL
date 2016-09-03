----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:    09:14:32 01/21/2015
-- Module Name:    test_spi_flash - behavioral
-- Project Name:   test_spi_flash
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.help_funcs.all;
use work.txt_util.all;

entity test_spi_flash is
    generic (
        BYTE_COUNT      : positive := 1024;
        INIT_FILE_PATH  : string := "";
        INIT_FILE_ADDR  : std_ulogic_vector(23 downto 0) := x"000000";
        ERASE_TIME      : time := 2 ms; -- more realistic erase time: 800 ms. Ain't nobody got time for that...
        PROGRAM_TIME    : time := 800 us;
        VERBOSE         : boolean := false
    );
    port (
        MISO    : in std_ulogic;
        MOSI    : out std_ulogic := '0';
        C       : in std_ulogic;
        SN      : in std_ulogic
    );
end test_spi_flash;

architecture behavioral of test_spi_flash is

    constant VERBOSE_MCS_PARSER : boolean := VERBOSE;

    procedure read_flash(
        addr    : in std_ulogic_vector(23 downto 0);
        data    : out std_ulogic_vector(7 downto 0)
    ) is
    begin
        data    := x"00";
        assert not VERBOSE
            report "Reading byte at 0x" & hstr(addr)
            severity NOTE;
    end procedure;

    procedure write_flash(
        addr    : in std_ulogic_vector(23 downto 0);
        data    : in std_ulogic_vector(7 downto 0)
    ) is
    begin
        assert not VERBOSE
            report "Writing byte: 0x" & hstr(data) & " at 0x" & hstr(addr)
            severity NOTE;
    end procedure;

begin

    spi_flash_sim_proc : process
        subtype cmd_type is std_ulogic_vector(7 downto 0);
        constant CMD_WRITE_ENABLE           : cmd_type := x"06";
        constant CMD_SECTOR_ERASE           : cmd_type := x"D8";
        constant CMD_READ_DATA_BYTES        : cmd_type := x"03";
        constant CMD_PAGE_PROGRAM           : cmd_type := x"02";
        constant CMD_READ_STATUS_REGISTER   : cmd_type := x"05";

        variable flash_cmd          : cmd_type;
        variable flash_addr         : std_ulogic_vector(23 downto 0);
        variable flash_data_byte    : std_ulogic_vector(7 downto 0);
        variable flash_status       : std_ulogic_vector(7 downto 0);
        variable erasing            : boolean;
        variable erase_start_time   : time;
        variable programming        : boolean;
        variable program_start_time : time;

        procedure get_cmd is
        begin
            bit_loop : for i in 7 downto 1 loop
                flash_cmd(i)    := MISO;
                wait until rising_edge(C) or SN='1';
                exit bit_loop when SN='1';
            end loop;
            flash_cmd(0)    := MISO;
        end procedure;

        procedure get_addr is
        begin
            bit_loop : for i in 23 downto 1 loop
                flash_addr(i)   := MISO;
                wait until rising_edge(C) or SN='1';
                exit bit_loop when SN='1';
            end loop;
            flash_addr(0)   := MISO;
            flash_addr      := stdulv(int(flash_addr) mod BYTE_COUNT, 24);
        end procedure;

        procedure get_data_byte is
        begin
            bit_loop : for i in 7 downto 1 loop
                flash_data_byte(i)  := MISO;
                wait until rising_edge(C) or SN='1';
                exit bit_loop when SN='1';
            end loop;
            flash_data_byte(0)  := MISO;
        end procedure;

        procedure send_status is
        begin
            bit_loop : for i in 7 downto 1 loop
                wait until falling_edge(C) or SN='1';
                exit bit_loop when SN='1';
                MOSI    <= flash_status(i);
                wait until rising_edge(C) or SN='1';
                exit bit_loop when SN='1';
            end loop;
            if SN='0' then
                wait until falling_edge(C) or SN='1';
                MOSI    <= flash_status(0);
            end if;
        end procedure;

        procedure send_data_byte is
            variable data   : std_ulogic_vector(7 downto 0);
        begin
            read_flash(flash_addr, data);
            bit_loop : for i in 7 downto 1 loop
                wait until falling_edge(C) or SN='1';
                exit bit_loop when SN='1';
                MOSI    <= data(i);
                wait until rising_edge(C) or SN='1';
                exit bit_loop when SN='1';
            end loop;
            if SN='0' then
                wait until falling_edge(C) or SN='1';
                MOSI    <= data(0);
            end if;
        end procedure;
    begin
        flash_status    := x"00";
        main_loop : loop
            wait until rising_edge(C);

            if erasing and now-erase_start_time>=ERASE_TIME then
                erasing         := false;
                flash_status(1) := '0'; -- WEN
                flash_status(0) := '0'; -- WIP
            end if;

            if programming and now-program_start_time>=PROGRAM_TIME then
                programming     := false;
                flash_status(1) := '0'; -- WEN
                flash_status(0) := '0'; -- WIP
            end if;

            if SN='0' then

                get_cmd;
                assert not VERBOSE
                    report "Got command: 0x" & hstr(flash_cmd)
                    severity NOTE;

                case flash_cmd is

                    when CMD_WRITE_ENABLE =>
                        wait until rising_edge(C) or SN='1';
                        if SN='1' then
                            if flash_status(0)='0' then
                                assert not VERBOSE
                                    report "Setting WRITE ENABLE bit"
                                    severity NOTE;
                                flash_status(1) := '1';
                            end if;
                        else
                            wait until SN='1';
                        end if;
                        next main_loop;

                    when CMD_READ_STATUS_REGISTER =>
                        while SN='0' loop
                            assert not VERBOSE
                                report "Sending status"
                                severity NOTE;
                            send_status;
                            if SN='0' then
                                wait until rising_edge(C) or SN='1';
                            end if;
                        end loop;
                        next main_loop;

                    when others =>
                        if
                            flash_cmd/=CMD_READ_DATA_BYTES and
                            flash_cmd/=CMD_SECTOR_ERASE and
                            flash_cmd/=CMD_PAGE_PROGRAM
                        then
                            assert not VERBOSE
                                report "Unknown command: " & hstr(flash_cmd)
                                severity NOTE;
                            if SN='0' then wait until SN='1'; end if;
                            next main_loop;
                        end if;

                end case;

                wait until rising_edge(C) or SN='1';
                next main_loop when SN='1';
                get_addr;
                flash_addr  := flash_addr mod BYTE_COUNT;
                assert not VERBOSE
                    report "Got address: 0x" & hstr(flash_addr, false)
                    severity NOTE;

                case flash_cmd is

                    when CMD_READ_DATA_BYTES =>
                        if flash_status(0)='0' then
                            while SN='0' loop
                                send_data_byte;
                                flash_addr  := (flash_addr+1) mod BYTE_COUNT;
                                if SN='0' then
                                    wait until rising_edge(C) or SN='1';
                                end if;
                            end loop;
                        else
                            if SN='0' then wait until SN='1'; end if;
                        end if;
                        next main_loop;

                    when CMD_SECTOR_ERASE =>
                        wait until rising_edge(C) or SN='1';
                        if SN='1' then
                            if flash_status(1 downto 0)="10" then
                                assert not VERBOSE
                                    report "Erasing sector: 0x" & hstr(flash_addr(23 downto 16) & x"0000", false)
                                    severity NOTE;
                            end if;
                            flash_status(1) := '0';
                        else
                            wait until SN='1';
                            report "Sector erase command not correctly finished!"
                                severity WARNING;
                            next main_loop;
                        end if;
                        erasing             := true;
                        erase_start_time    := now;
                        flash_status(0)     := '1';
                        next main_loop;

                    when CMD_PAGE_PROGRAM =>
                        wait until rising_edge(C) or SN='1';
                        next main_loop when SN='1';
                        while SN='0' loop
                            get_data_byte;
                            if SN='1' then
                                report "Program command not correctly finished!"
                                    severity WARNING;
                                next main_loop;
                            end if;
                            if flash_status(1 downto 0)="10" then
                                write_flash(flash_addr, flash_data_byte);
                                flash_addr(15 downto 0)     := (flash_addr(15 downto 0)+1) mod BYTE_COUNT;
                            end if;
                            wait until rising_edge(C) or SN='1';
                        end loop;
                        flash_status(1)     := '0';
                        programming         := true;
                        program_start_time  := now;
                        flash_status(0)     := '1';
                        next main_loop;

                    when others =>
                        null;

                end case;

            end if;
        end loop;
    end process;

end;
