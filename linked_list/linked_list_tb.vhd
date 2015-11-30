LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.linked_list.all;

entity testbench is
end testbench;

architecture behavior of testbench is 
    
    function ll_equals(
        list    : ll_item_type;
        data0   : string
    ) return boolean is
    begin
        return
            list.prev_item=null and
            list.next_item=null and
            list.data.all=data0;
    end function;
    
    function ll_equals(
        list    : ll_item_type;
        data0   : string;
        data1   : string
    ) return boolean is
    begin
        return
            list.prev_item=null and
            list.next_item/=null and
            list.data.all=data0 and
            list.next_item.prev_item.all=list and
            list.next_item.next_item=null and
            list.next_item.data.all=data1;
    end function;
    
    function ll_equals(
        list    : ll_item_type;
        data0   : string;
        data1   : string;
        data2   : string
    ) return boolean is
    begin
        return
            list.prev_item=null and
            list.next_item/=null and
            list.data.all=data0 and
            list.next_item.prev_item.all=list and
            list.next_item.next_item/=null and
            list.next_item.data.all=data1 and
            list.next_item.next_item.prev_item.all=list.next_item.all and
            list.next_item.next_item.next_item=null and
            list.next_item.next_item.data.all=data2;
    end function;
    
begin
    
    stim_proc : process
        variable list   : ll_item_pointer_type;
    begin
        ll_append(list, "data0");
        assert ll_equals(list.all, "data0")
            report "Test 1 failed"
            severity FAILURE;
        
        report "--- Test 1 --- creating list" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_append(list, "data1");
        assert ll_equals(list.all, "data0", "data1")
            report "Test 2 failed"
            severity FAILURE;
        
        report "--- Test 2 --- appending item" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list);
        assert ll_equals(list.all, "data1")
            report "Test 3 failed"
            severity FAILURE;
        
        report "--- Test 3 --- removing list start" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list, "data1");
        assert list=null
            report "Test 4 failed"
            severity FAILURE;
        
        report "--- Test 4 --- removing item 'data1'" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_insert(list, "data2", 0);
        assert ll_equals(list.all, "data2")
            report "Test 5 failed"
            severity FAILURE;
        
        report "--- Test 5 --- inserting at list start" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_insert(list, "data0", 0);
        assert ll_equals(list.all, "data0", "data2")
            report "Test 6 failed"
            severity FAILURE;
        
        report "--- Test 6 --- inserting at list start" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_insert(list, "data1", 1);
        assert ll_equals(list.all, "data0", "data1", "data2")
            report "Test 7 failed"
            severity FAILURE;
        
        report "--- Test 7 --- inserting into the middle of list" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list, 1);
        assert ll_equals(list.all, "data0", "data2")
            report "Test 8 failed"
            severity FAILURE;
        
        report "--- Test 8 --- removing middle item by index" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list, 1);
        assert ll_equals(list.all, "data0")
            report "Test 9 failed"
            severity FAILURE;
        
        report "--- Test 9 --- removing last item by index" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list, 10);
        assert ll_equals(list.all, "data0")
            report "Test 10 failed"
            severity FAILURE;
        
        report "--- Test 10 --- removing nonexistent item by index" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list, "data1");
        assert ll_equals(list.all, "data0")
            report "Test 11 failed"
            severity FAILURE;
        
        report "--- Test 11 --- removing nonexistent item by name" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_insert(list, "data1", 10);
        assert ll_equals(list.all, "data0", "data1")
            report "Test 12 failed"
            severity FAILURE;
        
        report "--- Test 12 --- inserting at the end of list" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        ll_remove(list, 0);
        assert ll_equals(list.all, "data1")
            report "Test 13 failed"
            severity FAILURE;
        
        report "--- Test 13 --- removing list start by index" severity NOTE;
        ll_report(list);
        
        --------------------------------------
        
        report "NONE. All tests finished successfully."
            severity FAILURE;
        wait;
    end process;
    
end;
