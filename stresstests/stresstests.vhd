
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mcs_parser.all;
use work.linked_list.all;
use work.help_funcs.all;
use work.txt_util.all;

entity testbench is
end testbench;

architecture behavior of testbench is 
    
begin
    
    tb : process
        variable list       : ll_item_pointer_type;
        variable address    : std_ulogic_vector(31 downto 0);
        variable data       : std_ulogic_vector(7 downto 0);
        variable valid      : boolean;
    begin
        mcs_init("D:\GitHub\VHDL\pandaLight-HDL\pandaLight-Tests\pandaLight.mcs", list, false);
        --ll_report(list);
        
        for i in 1 to 10 loop
            
            mcs_init;
            
            valid   := true;
            while valid loop
                mcs_read_byte(list, address, data, valid, false);
                --report "address: " & hstr(address) & " data: " & hstr(data);
            end loop;
            
        end loop;
        
        assert false severity FAILURE;
        wait;
    end process;
    
end;
