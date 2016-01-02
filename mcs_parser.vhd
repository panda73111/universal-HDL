library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.help_funcs.all;
use work.txt_util.all;
use work.linked_list.all;

package mcs_parser is
    
    -- the number of bytes that are written into one mcs line
    constant WRITE_RECORD_SIZE  : positive range 1 to 255 := 16;
    constant END_OF_FILE_RECORD : string := ":00000001FF";

    shared variable addr_offset : std_ulogic_vector(31 downto 0) := x"00000000";
    shared variable bytes_left  : natural := 0;
    shared variable item        : ll_item_pointer_type;
    shared variable char_index  : natural := 0;
    shared variable line_num    : natural := 0;
    shared variable checksum    : std_ulogic_vector(7 downto 0) := x"00";

    procedure mcs_init;
    procedure mcs_init(
        filename    : in string;
        list        : inout ll_item_pointer_type;
        verbose     : in boolean
    );

    procedure mcs_read_byte(
        list    : inout ll_item_pointer_type;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean;
        verbose : in boolean
    );
    
    procedure mcs_write(
        list    : inout ll_item_pointer_type;
        address : in std_ulogic_vector(31 downto 0);
        data    : in std_ulogic_vector;
        verbose : in boolean
    );

end package;

package body mcs_parser is

    procedure mcs_init is
    begin
        addr_offset := x"00000000";
        bytes_left  := 0;
        item        := null;
        char_index  := 0;
        line_num    := 1;
        checksum    := x"00";
    end procedure;

    procedure mcs_init(
        filename    : in string;
        list        : inout ll_item_pointer_type;
        verbose     : in boolean
    ) is
        file f      : TEXT;
        variable l  : line;
        variable p  : ll_item_pointer_type;
    begin
        mcs_init;
        
        list    := null;
        p       := null;

        assert not VERBOSE
            report "Opening file: " & filename
            severity NOTE;
        
        file_open(f, filename, READ_MODE);
        
        while not endfile(f) loop
            
            readline(f, l);
            ll_append(p, l.all);
            
            if list=null then
                list    := p;
            end if;
            
            if p.next_item/=null then
                p   := p.next_item;
            end if;
            
        end loop;

        assert not VERBOSE
            report "Closing file: " & filename
            severity NOTE;
        
        file_close(f);
    end procedure;

    procedure mcs_read_byte(
        list    : inout ll_item_pointer_type;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean;
        verbose : in boolean
    ) is
        variable mcs_line           : line;
        variable hex                : string(1 to 2);
        variable hex2               : string(1 to 4);
        variable byte_count         : natural;
        variable record_type        : natural;
        variable temp               : std_ulogic_vector(7 downto 0);
        variable temp2              : std_ulogic_vector(15 downto 0);
        variable checksum_in_file   : std_ulogic_vector(7 downto 0);
    begin
        if item=null then
            item    := list;
        end if;
        
        address := addr_offset;
        
        if list=null then
            assert not verbose
                report "Got an empty list, returning"
                severity NOTE;
            
            valid   := false;
            return;
        end if;

        if bytes_left>0 then
            mcs_line    := item.data;
            if mcs_line.all'length<char_index+1 then
                valid       := false;
                bytes_left  := 0;
                return;
            end if;
            hex         := mcs_line.all(char_index to char_index+1);
            valid       := true;
            temp        := hex_to_stdulv(hex);
            data        := temp;
            addr_offset := addr_offset+1;
            bytes_left  := bytes_left-1;
            checksum    := checksum+temp;
            char_index  := char_index+2;
            
            assert not verbose
                report "data byte: " & hstr(temp)
                severity NOTE;

            if bytes_left=0 then
                if mcs_line.all'length<char_index+1 then valid := false; return; end if;
                
                hex                 := mcs_line.all(char_index to char_index+1);
                checksum_in_file    := hex_to_stdulv(hex);
                checksum            := (not checksum)+1;
                
                assert not verbose
                    report "checksum, got: " & hstr(checksum_in_file) & " expected: " & hstr(checksum)
                    severity NOTE;
                
                assert checksum=checksum_in_file
                    report "Checksum error in .mcs file, line " & str(line_num)
                    severity FAILURE;
                
                item        := item.next_item;
                line_num    := line_num+1;
                
                if item=null then valid := false; end if;
            end if;
            
            return;
        end if;

        while true loop

            mcs_line    := item.data;
            checksum    := x"00";
            while mcs_line.all(1)/=':' loop
                item        := item.next_item;
                mcs_line    := item.data;
                line_num    := line_num+1;
                
                if item=null then valid := false; return; end if;
            end loop;

            if mcs_line.all'length<3 then valid := false; return; end if;
            
            hex         := mcs_line.all(2 to 3);
            byte_count  := int(hex_to_stdulv(hex));
            checksum    := checksum+byte_count;
            
            assert not verbose
                report "byte count: " & str(byte_count)
                severity NOTE;
            
            if mcs_line.all'length<7 then valid := false; return; end if;
            
            hex2                    := mcs_line.all(4 to 7);
            temp2                   := hex_to_stdulv(hex2);
            address(15 downto 0)    := temp2;
            checksum                := checksum+temp2(15 downto 8);
            checksum                := checksum+temp2(7 downto 0);
            
            assert not verbose
                report "address: 0x" & hstr(temp2)
                severity NOTE;

            if mcs_line.all'length<9 then valid := false; return; end if;
            
            hex         := mcs_line.all(8 to 9);
            record_type := int(hex_to_stdulv(hex));
            checksum    := checksum+record_type;
            
            assert not verbose
                report "record type: " & str(record_type)
                severity NOTE;

            case record_type is

                when 0 => -- data
                    if mcs_line.all'length<11 then valid := false; return; end if;
                    
                    hex         := mcs_line.all(10 to 11);
                    valid       := true;
                    temp        := hex_to_stdulv(hex);
                    data        := temp;
                    addr_offset := addr_offset+1;
                    bytes_left  := byte_count-1;
                    checksum    := checksum+temp;
                    char_index  := 12;
                    
                    assert not verbose
                        report "data byte: " & hstr(temp)
                        severity NOTE;
                    
                    if bytes_left>0 then
                        return;
                    end if;

                when 1 => -- end of file
                    valid       := false;
                    char_index  := 10;

                when 2 => -- extended segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 3 => -- start segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 4 => -- extended linear address
                    if mcs_line.all'length<13 then valid := false; return; end if;
                    
                    hex2        := mcs_line.all(10 to 13);
                    temp2       := hex_to_stdulv(hex2);
                    addr_offset := temp2 & x"0000";
                    address     := addr_offset;
                    checksum    := checksum+temp2(15 downto 8);
                    checksum    := checksum+temp2(7 downto 0);
                    char_index  := 14;
                    
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

            if mcs_line.all'length<char_index+1 then valid := false; return; end if;
            
            hex                 := mcs_line.all(char_index to char_index+1);
            checksum_in_file    := hex_to_stdulv(hex);
            checksum            := (not checksum)+1;
            
            assert not verbose
                report "checksum, got: " & hstr(checksum_in_file) & " expected: " & hstr(checksum)
                severity NOTE;
            
            assert checksum=checksum_in_file
                report "Checksum error in .mcs file, line " & str(line_num)
                severity FAILURE;
            
            item        := item.next_item;
            line_num    := line_num+1;
            
            if item=null then valid := false; return; end if;
            
        end loop;

    end procedure;
    
    function generate_mcs_data_line(
        address : std_ulogic_vector(15 downto 0);
        data    : std_ulogic_vector
    ) return string is
        constant COLON      : character := ':';
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
        
        write(mcs_line, COLON);
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
        constant PREFIX     : string := ":02000004";
        variable mcs_line   : line;
        variable checksum   : std_ulogic_vector(7 downto 0);
    begin
        mcs_line    := null;
        
        checksum    := x"06"
            +address(15 downto 8)
            +address(7 downto 0);
        
        checksum    := (not checksum)+1;
        
        write(mcs_line, PREFIX);
        write(mcs_line, hstr(address, false));
        write(mcs_line, hstr(checksum));
        return mcs_line.all;
    end function;
    
    procedure modify_mcs_data_line(
        mcs_line        : inout line;
        data            : in std_ulogic_vector;
        addr_offs       : in natural range 0 to 255
    ) is
        constant COLON                  : character := ':';
        variable mcs_line_byte_count    : positive range 1 to 255;
        variable mcs_line_addr_hex      : string(1 to 4);
        variable data_byte_count        : positive range 1 to 255;
        variable data_before            : line;
        variable data_after             : line;
        variable new_byte_count         : positive range 1 to 255;
        variable checksum               : std_ulogic_vector(7 downto 0);
    begin
        mcs_line_byte_count := int(hex_to_stdulv(mcs_line.all(2 to 3)));
        mcs_line_addr_hex   := mcs_line.all(4 to 7);
        data_byte_count     := data'length/8;
        data_before         := new string'("");
        data_after          := new string'("");
        new_byte_count      := maximum(mcs_line_byte_count, addr_offs+data_byte_count);
        
        if addr_offs>0 then
            data_before := new string'(mcs_line.all(10 to 10+addr_offs*2-1));
        end if;
        
        if addr_offs+data_byte_count<mcs_line_byte_count then
            data_after  := new string'(mcs_line.all(
                10+(addr_offs+data_byte_count)*2 to 10+mcs_line_byte_count*2-1));
        end if;
        
        mcs_line    := null;
        write(mcs_line, COLON);
        write(mcs_line, hstr(stdulv(new_byte_count, 8)));
        write(mcs_line, mcs_line_addr_hex);
        write(mcs_line, hstr(x"00")); -- record type
        write(mcs_line, data_before.all);
        write(mcs_line, hstr(data, false));
        write(mcs_line, data_after.all);
        
        checksum    := x"00";
        for i in 1 to 1+2+1+new_byte_count loop
            checksum    := checksum+hex_to_stdulv(mcs_line.all(i*2 to i*2+1));
        end loop;
        checksum    := (not checksum)+1;
        
        write(mcs_line, hstr(checksum));
    end procedure;
    
    procedure mcs_write(
        list    : inout ll_item_pointer_type;
        address : in std_ulogic_vector(31 downto 0);
        data    : in std_ulogic_vector;
        verbose : in boolean
    ) is
        variable desc_data          : std_ulogic_vector(data'length-1 downto 0);
        variable p                  : ll_item_pointer_type;
        variable item_num           : integer;
        variable list_line          : line;
        variable list_address       : std_ulogic_vector(31 downto 0);
        variable prev_ext_addr      : std_ulogic_vector(15 downto 0);
        variable byte_count         : natural range 0 to 255;
        variable record_type        : natural range 0 to 255;
        variable mcs_line           : line;
        variable addr_offs          : natural range 0 to 255;
        variable data_byte_count    : positive range 1 to 255;
        variable slice_byte_count   : positive range 1 to 255;
    begin
        desc_data       := data;
        p               := list;
        prev_ext_addr   := x"0000";
        item_num        := -1;
        list_address    := x"00000000";
        mcs_line        := null;
        
        if p=null then
            assert not verbose
                report "Empty list, adding an 'end of file' record"
                severity NOTE;
            
            ll_append(list, END_OF_FILE_RECORD);
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
                    if
                        address>=list_address and
                        address<list_address+WRITE_RECORD_SIZE
                    then
                        assert not verbose
                            report "Modifying data at 0x" & hstr(list_address)
                            severity NOTE;
                        
                        addr_offs           := int(address-list_address);
                        data_byte_count     := data'length/8;
                        slice_byte_count    := minimum(data_byte_count, WRITE_RECORD_SIZE-addr_offs);
                        
                        modify_mcs_data_line(p.data,
                            desc_data(desc_data'high downto desc_data'high-slice_byte_count*8+1),
                            addr_offs);
                        
                        -- if data_byte_count>slice_byte_count then
                            -- -- write the rest of the data (the second data slice)
                            -- -- into the next data record
                            -- mcs_write(list, address+slice_byte_count,
                                -- data(data'high-slice_byte_count*8 downto data'low),
                                -- verbose);
                        -- end if;
                        
                        return;
                    end if;

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
                        report "Appending data 0x" & hstr(desc_data)
                        severity NOTE;
                    
                    ll_insert(list,
                        generate_mcs_data_line(address(15 downto 0), desc_data),
                        item_num);
                    return;

                when 2 => -- extended segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 3 => -- start segment address
                    report "Not implemented record type, line " & str(line_num)
                        severity FAILURE;

                when 4 => -- extended linear address
                    list_address    := hex_to_stdulv(list_line.all(10 to 13)) & x"0000";
                    if prev_ext_addr=address(31 downto 16) then
                        -- address matches the passed data block
                        assert not verbose
                            report "Appending data 0x" & hstr(desc_data)
                            severity NOTE;
                        
                        ll_insert(list,
                            generate_mcs_data_line(address(15 downto 0), desc_data),
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
