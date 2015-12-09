library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.help_funcs.all;
use work.txt_util.all;
use work.linked_list.all;

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
        valid   : out boolean;
        verbose : in boolean
    );

    procedure mcs_read_byte(
        list    : inout ll_item_pointer_type;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean;
        verbose : in boolean
    );
    
    procedure mcs_write_byte(
        list    : inout ll_item_pointer_type;
        address : in std_ulogic_vector(31 downto 0);
        data    : in std_ulogic_vector(7 downto 0);
        verbose : in boolean
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
        list    : inout ll_item_pointer_type;
        file f  : TEXT;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean;
        verbose : in boolean
    ) is
        constant file_mode          : boolean := list=null;
        
        variable p                  : ll_item_pointer_type;
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
        p       := list;
        address := addr_offset;
        
        if
            (file_mode and endfile(f)) or
            (not file_mode and list=null)
        then
            valid   := false;
            return;
        end if;

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
            
            assert not verbose
                report "data byte: " & hstr(temp)
                severity NOTE;

            if bytes_left=0 then
                read(l, hex, good);
                if not good then valid := false; return; end if;
                checksum_in_file    := hex_to_stdulv(hex);
                checksum            := (not checksum)+1;
                
                assert not verbose
                    report "checksum, got: " & hstr(checksum_in_file) & " expected: " & hstr(checksum)
                    severity NOTE;
                
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
                if file_mode then
                    readline(f, l);
                else
                    l   := p.data;
                    p   := p.next_item;
                end if;
                
                line_num    := line_num+1;
                read(l, char, good);
                if not good then valid := false; return; end if;
            end loop;

            read(l, hex, good);
            if not good then valid := false; return; end if;
            byte_count  := int(hex_to_stdulv(hex));
            checksum    := checksum+byte_count;
            
            assert not verbose
                report "byte count: " & str(byte_count)
                severity NOTE;

            read(l, hex2, good);
            if not good then valid := false; return; end if;
            temp2                   := hex_to_stdulv(hex2);
            address(15 downto 0)    := temp2;
            checksum                := checksum+temp2(15 downto 8);
            checksum                := checksum+temp2(7 downto 0);
            
            assert not verbose
                report "address: 0x" & hstr(temp2)
                severity NOTE;

            read(l, hex, good);
            if not good then valid := false; return; end if;
            record_type := int(hex_to_stdulv(hex));
            checksum    := checksum+record_type;
            
            assert not verbose
                report "record type: " & str(record_type)
                severity NOTE;

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
                    
                    assert not verbose
                        report "data byte: " & hstr(temp)
                        severity NOTE;
                    
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
                    address     := addr_offset;
                    checksum    := checksum+temp2(15 downto 8);
                    checksum    := checksum+temp2(7 downto 0);
                    
                    assert not verbose
                        report "address offset: " & hstr(temp2)
                        severity NOTE;

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
            
            assert not verbose
                report "checksum, got: " & hstr(checksum_in_file) & " expected: " & hstr(checksum)
                severity NOTE;
            
            assert checksum=checksum_in_file
                report "Checksum error in .mcs file, line " & str(line_num)
                severity FAILURE;
                
            if endfile(f) then
                return;
            end if;

        end loop;

    end procedure;

    procedure mcs_read_byte(
        file f  : TEXT;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean;
        verbose : in boolean
    ) is
    begin
        mcs_read_byte(null, f, address, data, valid, verbose);
    end procedure;

    procedure mcs_read_byte(
        list    : inout ll_item_pointer_type;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean;
        verbose : in boolean
    ) is
        file f  : TEXT;
    begin
        mcs_read_byte(list, f, address, data, valid, verbose);
    end procedure;
    
    function generate_mcs_data_line(
        address : std_ulogic_vector(15 downto 0);
        data    : std_ulogic_vector
    ) return string is
        variable mcs_line   : line;
        variable byte_count : natural range 0 to 255;
        variable checksum   : std_ulogic_vector(7 downto 0);
    begin
        mcs_line    := null;
        
        assert (data'length mod 8)=0
            report "Whole bytes expected"
            severity FAILURE;
        
        byte_count  := data'length/8;
        
        assert byte_count<=255
            report "Too many bytes for one data line"
            severity FAILURE;
        
        checksum    := stdulv(byte_count, 8)+
            address(15 downto 8)+
            address(7 downto 0);
        
        for i in 1 to byte_count loop
            checksum    := checksum+data(i*8-1 downto (i-1)*8);
        end loop;
        checksum    := (not checksum)+1;
        
        write(mcs_line, ":");
        write(mcs_line, hstr(stdulv(byte_count, 8)));
        write(mcs_line, hstr(address, false));
        write(mcs_line, hstr(x"00")); -- record type
        write(mcs_line, hstr(data, false));
        write(mcs_line, hstr(checksum));
        return mcs_line.all;
    end function;
    
    function generate_mcs_ext_addr_line(
        address : std_ulogic_vector(15 downto 0)
    ) return string is
        variable mcs_line   : line;
        variable checksum   : std_ulogic_vector(7 downto 0);
    begin
        mcs_line    := null;
        
        checksum    := x"02"
            +address(15 downto 8)
            +address(7 downto 0);
        
        checksum    := (not checksum)+1;
        
        write(mcs_line, ":02000004");
        write(mcs_line, hstr(address, false));
        write(mcs_line, hstr(checksum));
        return mcs_line.all;
    end function;
    
    procedure mcs_write_byte(
        list    : inout ll_item_pointer_type;
        address : in std_ulogic_vector(31 downto 0);
        data    : in std_ulogic_vector(7 downto 0);
        verbose : in boolean
    ) is
        variable p              : ll_item_pointer_type;
        variable item_num       : integer;
        variable list_line      : line;
        variable list_address   : std_ulogic_vector(31 downto 0);
        variable prev_ext_addr  : std_ulogic_vector(15 downto 0);
        variable byte_count     : natural;
        variable record_type    : natural;
        variable mcs_line       : line;
    begin
        p               := list;
        prev_ext_addr   := x"0000";
        item_num        := -1;
        list_address    := x"00000000";
        mcs_line        := null;
        
        if p=null then
            assert not verbose
                report "Empty list, adding an 'end of file' record"
                severity NOTE;
            
            ll_append(list, ":00000001FF");
            p   := list;
        end if;
        
        while p/=null loop
            
            item_num    := item_num+1;
            list_line   := p.data;
            
            if list_line.all(1)/=':' then next; end if;
            
            byte_count                  := int(hex_to_stdulv(list_line.all(2 to 3)));
            list_address(15 downto 0)   := hex_to_stdulv(list_line.all(4 to 7));
            record_type                 := int(hex_to_stdulv(list_line.all(8 to 9)));
            
            case record_type is

                when 0 => -- data
                    null;

                when 1 => -- end of file
                    if prev_ext_addr/=address(31 downto 16) then
                        assert not verbose
                            report "Appending new extended address 0x" & hstr(address(31 downto 16))
                            severity NOTE;
                        
                        ll_insert(list,
                            generate_mcs_ext_addr_line(address(31 downto 16)),
                            item_num);
                        item_num    := item_num+1;
                    end if;
                    
                    assert not verbose
                        report "Appending data 0x" & hstr(data)
                        severity NOTE;
                    
                    ll_insert(list,
                        generate_mcs_data_line(address(15 downto 0), data),
                        item_num);
                    return;

                when 2 => -- extended segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 3 => -- start segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 4 => -- extended linear address
                    list_address    := hex_to_stdulv(list_line.all(10 to 13)) & "0000";
                    if prev_ext_addr=address(31 downto 16) then
                        -- address matches the passed data block
                        assert not verbose
                            report "Appending data 0x" & hstr(data)
                            severity NOTE;
                        
                        ll_insert(list,
                            generate_mcs_data_line(address(15 downto 0), data),
                            item_num);
                        return;
                    end if;
                    prev_ext_addr   := list_address(31 downto 16);

                when 5 => -- start linear address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when others =>
                    report "Uknown record type in list, line " & str(line_num)
                        severity FAILURE;
            end case;
            
            p   := p.next_item;
            
        end loop;
    end procedure;

end;
