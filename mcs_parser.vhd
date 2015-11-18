library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

package mcs_parser is
    
    shared variable addr_offset : std_ulogic_vector(15 downto 0) := x"0000";
    
    procedure mcs_read_byte(
        f       : in file;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector(7 downto 0);
        valid   : out boolean
    );
    
end package;

package body mcs_parser is
    
    procedure mcs_read_byte(
        f       : in file;
        address : out std_ulogic_vector(31 downto 0);
        data    : out std_ulogic_vector;
        valid   : out boolean
    ) is
        variable l              : line;
        variable char           : character;
        variable hex            : string(1 to 2);
        variable hex2           : string(1 to 4);
        variable byte_count     : natural;
        variable record_type    : natural;
        variable good           : boolean;
    begin
        address(31 downto 16)   := addr_offset;
        
        while true loop
            
            char = nul;
            while char/=':' loop
                readline(f, l);
                read(l, char, good);
                if not good then valid := false; return; end if;
            end loop;
            
            read(l, hex, good);
            if not good then valid := false; return; end if;
            byte_count  := int(hex_to_stdulv(hex));
            
            read(l, hex2, good);
            if not good then valid := false; return; end if;
            address(15 downto 0)    := hex_to_stdulv(hex2);
            
            read(l, hex, good);
            if not good then valid := false; return; end if;
            record_type := int(hex_to_stdulv(hex));
            
            case record_type is
                
                when 0 => -- data
                    for i in 0 to byte_count-1 loop
                        read(l, hex, good);
                        if not good then valid := false; return; end if;
                        _count  := int(hex_to_stdulv(hex));
                    end loop;
                    
                when 1 => -- end of file
                    good    := false;
                    return;
                    
                when 2 => -- extended segment address
                when 3 => -- start segment address
                when 4 => -- extended linear address
                when 5 => -- start linear address
            end case;
        
        end loop;
        
    end procedure;
    
end;
