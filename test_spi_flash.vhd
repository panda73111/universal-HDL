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
        INIT_FILE_0_PATH    : string := "";
        INIT_FILE_0_ADDR    : std_ulogic_vector(23 downto 0) := x"000000";
        INIT_FILE_1_PATH    : string := "";
        INIT_FILE_1_ADDR    : std_ulogic_vector(23 downto 0) := x"000000";
        INIT_FILE_2_PATH    : string := "";
        INIT_FILE_2_ADDR    : std_ulogic_vector(23 downto 0) := x"000000";
        INIT_FILE_3_PATH    : string := "";
        INIT_FILE_3_ADDR    : std_ulogic_vector(23 downto 0) := x"000000";
        INIT_FILE_4_PATH    : string := "";
        INIT_FILE_4_ADDR    : std_ulogic_vector(23 downto 0) := x"000000";
        BUFFER_SIZE         : positive := 256;
        ERASE_TIME          : time := 2 ms; -- more realistic erase time: 800 ms. Ain't nobody got time for that...
        PROGRAM_TIME        : time := 800 us;
        VERBOSE             : boolean := false
    );
    port (
        MISO    : in std_ulogic;
        MOSI    : out std_ulogic := '0';
        C       : in std_ulogic;
        SN      : in std_ulogic
    );
end test_spi_flash;

architecture behavioral of test_spi_flash is

    constant INIT_FILE_COUNT    : positive := 5;

    type init_file_paths_type is
        array(0 to INIT_FILE_COUNT) of
        string;
    constant INIT_FILE_PATHS    : init_file_paths_type := (
        INIT_FILE_0_PATH,
        INIT_FILE_1_PATH,
        INIT_FILE_2_PATH,
        INIT_FILE_3_PATH,
        INIT_FILE_4_PATH
    );

    type init_file_addrs_type is
        array(0 to INIT_FILE_COUNT) of
        std_ulogic_vector(23 downto 0);
    constant INIT_FILE_ADDRS    : init_file_addrs_type := (
        INIT_FILE_0_ADDR,
        INIT_FILE_1_ADDR,
        INIT_FILE_2_ADDR,
        INIT_FILE_3_ADDR,
        INIT_FILE_4_ADDR
    );

    type buffer_type is
        array(0 to BUFFER_SIZE-1) of
        std_ulogic_vector(7 downto 0);
    signal buf  : buffer_type := (others => x"00");

    function addr_to_init_file_index(
        addr : std_ulogic_vector(23 downto 0)
    ) return integer is
        variable highest_matching_address   : std_ulogic_vector(23 downto 0);
        variable highest_matching_index     : integer;
    begin
        highest_matching_index  := -1;

        -- search for at least one init address below or at the given one
        for i in 0 to INIT_FILE_COUNT loop
            if addr >= INIT_FILE_ADDRS(i) then
                highest_matching_index      := i;
                highest_matching_address    := INIT_FILE_ADDRS(i);
                exit;
            end if;
        end loop;

        if highest_matching_index=-1 then
            -- no init file for the given address
            return -1;
        end if;

        -- search the highest address below or at the given one
        for i in 0 to INIT_FILE_COUNT loop
            if
                INIT_FILE_ADDRS(i) > highest_matching_address and
                addr >= INIT_FILE_ADDRS(i)
            then
                highest_matching_index      := i;
                highest_matching_address    := INIT_FILE_ADDRS(i);
            end if;
        end loop;

        return highest_matching_index;
    end function;

    procedure fill_buffer(
            signal buf          : out buffer_type;
            variable start_addr : in std_ulogic_vector(23 downto 0)
    ) is
        variable init_file_index    : integer;
        variable init_file_path     : string;
        variable bytes_to_skip      : natural;
        file f                      : TEXT;
        variable l                  : line;
        variable char               : character;
        variable val                : std_ulogic_vector(3 downto 0);
        variable buf_i              : natural range 0 to buffer_type'length-1;
        variable good               : boolean;
        variable byte_complete      : boolean;
    begin
        init_file_index  := addr_to_init_file_index(start_addr);
        if init_file_index=-1 then
            for i in 0 to buffer_type'length-1 loop
                buf(i)  <= x"00";
            end loop;
            return;
        end if;

        init_file_path  := INIT_FILE_PATHS(init_file_index);

        assert not VERBOSE
            report "Opening file: " & init_file_path
            severity NOTE;

        bytes_to_skip   := int(start_addr-INIT_FILE_ADDRS(init_file_index));
        buf_i           := 0;
        byte_complete   := false;

        file_open(f, init_file_path, read_mode);
        file_loop : while not endfile(f) loop
            readline(f, l);
            read(l, char, good);
            while good loop
                val := hex_to_stdulv(char);
                if byte_complete then
                    buf(buf_i)(3 downto 0)  <= val;

                    if bytes_to_skip=0 then
                        buf_i   := buf_i+1;
                    else
                        bytes_to_skip   := bytes_to_skip-1;
                    end if;
                else
                    buf(buf_i)(7 downto 4)  <= val;
                end if;

                exit file_loop when buf_i=buffer_type'length;

                byte_complete   := not byte_complete;
                read(l, char, good);
            end loop;
        end loop;

        assert not VERBOSE
            report "Closing file: " & init_file_path
            severity NOTE;

        file_close(f);

        if buf_i!=buffer_type'length then
            -- fill the rest with zeros
            for i in buf_i to buffer_type'length-1 loop
                buf(i)  <= x"00";
            end loop;
        end if;

    end procedure;

begin

    spi_flash_sim_proc : process
        subtype cmd_type is std_ulogic_vector(7 downto 0);
        constant CMD_WRITE_ENABLE           : cmd_type := x"06";
        constant CMD_SECTOR_ERASE           : cmd_type := x"D8";
        constant CMD_READ_DATA_BYTES        : cmd_type := x"03";
        constant CMD_PAGE_PROGRAM           : cmd_type := x"02";
        constant CMD_READ_STATUS_REGISTER   : cmd_type := x"05";

        variable buffer_start_addr  : std_ulogic_vector(23 downto 0);
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
        begin
            bit_loop : for i in 7 downto 1 loop
                wait until falling_edge(C) or SN='1';
                exit bit_loop when SN='1';
                MOSI    <= flash_mem(int(flash_addr))(i);
                wait until rising_edge(C) or SN='1';
                exit bit_loop when SN='1';
            end loop;
            if SN='0' then
                wait until falling_edge(C) or SN='1';
                MOSI    <= flash_mem(int(flash_addr))(0);
            end if;
        end procedure;
    begin
        buffer_start_addr   := x"000000";
        fill_buffer(buf, buffer_start_addr);

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
                                assert not VERBOSE
                                    report "Reading byte: 0x" & hstr(flash_mem(int(flash_addr))) & " at 0x" & hstr(flash_addr, false)
                                    severity NOTE;
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
                                assert not VERBOSE
                                    report "Writing byte: 0x" & hstr(flash_data_byte) & " at 0x" & hstr(flash_addr, false)
                                    severity NOTE;
                                flash_mem(int(flash_addr))  <= flash_data_byte;
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
