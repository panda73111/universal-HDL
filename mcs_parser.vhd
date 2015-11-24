library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.help_funcs.all;
use work.txt_util.all;

package mcs_parser is

    shared variable addr_offset : std_ulogic_vector(31 downto 0) := x"00000000";
    shared variable bytes_left  : natural := 0;
    shared variable l           : line := null;
    shared variable line_num    : natural := 0;
    shared variable checksum    : std_ulogic_vector(7 downto 0) := x"00";

    procedure mcs_init;

    procedure mcs_read_byte(
        file f  : TEXT;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean
    );

end package;

package body mcs_parser is

    procedure mcs_init is
    begin
        addr_offset := x"00000000";
        bytes_left  := 0;
        l           := null;
        line_num    := 0;
        checksum    := x"00";
    end procedure;

    procedure mcs_read_byte(
        file f  : TEXT;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean
    ) is
        variable char               : character;
        variable hex                : string(1 to 2);
        variable hex2               : string(1 to 4);
        variable byte_count         : natural;
        variable record_type        : natural;
        variable good               : boolean;
        variable temp               : std_ulogic_vector(7 downto 0);
        variable temp2              : std_ulogic_vector(15 downto 0);
        variable checksum_in_file   : std_ulogic_vector(7 downto 0);
    begin
        address := addr_offset;

        if bytes_left>0 then
            read(l, hex, good);
            if not good then
                valid       := false;
                bytes_left  := 0;
                return;
            end if;
            valid       := true;
            temp        := hex_to_stdulv(hex);
            data        := temp;
            addr_offset := addr_offset+1;
            bytes_left  := bytes_left-1;
            checksum    := checksum+temp;

            if bytes_left=0 then
                read(l, hex, good);
                if not good then valid := false; return; end if;
                checksum_in_file    := hex_to_stdulv(hex);
                checksum            := (not checksum)+1;
                assert checksum=checksum_in_file
                    report "Checksum error in .mcs file, line " & str(line_num)
                    severity FAILURE;
            end if;

            return;
        end if;

        while true loop

            checksum    := x"00";
            char        := nul;
            while char/=':' loop
                readline(f, l);
                line_num    := line_num+1;
                read(l, char, good);
                if not good then valid := false; return; end if;
            end loop;

            read(l, hex, good);
            if not good then valid := false; return; end if;
            byte_count  := int(hex_to_stdulv(hex));
            checksum    := checksum+byte_count;

            read(l, hex2, good);
            if not good then valid := false; return; end if;
            temp2                   := hex_to_stdulv(hex2);
            address(15 downto 0)    := temp2;
            checksum                := checksum+temp2(15 downto 8);
            checksum                := checksum+temp2(7 downto 0);

            read(l, hex, good);
            if not good then valid := false; return; end if;
            record_type := int(hex_to_stdulv(hex));
            checksum    := checksum+record_type;

            case record_type is

                when 0 => -- data
                    read(l, hex, good);
                    if not good then valid := false; return; end if;
                    valid       := true;
                    temp        := hex_to_stdulv(hex);
                    data        := temp;
                    addr_offset := addr_offset+1;
                    bytes_left  := byte_count-1;
                    checksum    := checksum+temp;
                    report "data byte: " & hstr(temp) severity NOTE;
                    if bytes_left>0 then
                        return;
                    end if;

                when 1 => -- end of file
                    valid   := false;

                when 2 => -- extended segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 3 => -- start segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 4 => -- extended linear address
                    read(l, hex2, good);
                    if not good then valid := false; return; end if;
                    temp2       := hex_to_stdulv(hex2);
                    addr_offset := temp2 & x"0000";
                    checksum    := checksum+temp2(15 downto 8);
                    checksum    := checksum+temp2(7 downto 0);

                when 5 => -- start linear address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when others =>
                    report "Uknown record type in .mcs file, line " & str(line_num)
                        severity FAILURE;
            end case;

            read(l, hex, good);
            if not good then valid := false; return; end if;
            checksum_in_file    := hex_to_stdulv(hex);
            checksum            := (not checksum)+1;
            assert checksum=checksum_in_file
                report "Checksum error in .mcs file, line " & str(line_num)
                severity FAILURE;

        end loop;

    end procedure;

end;
