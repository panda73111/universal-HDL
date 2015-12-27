library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use work.help_funcs.all;
use work.txt_util.all;

package linked_list is
    
    type ll_item_type;
    type ll_item_pointer_type is access ll_item_type;
    
    type ll_item_type is record
        data        : line;
        prev_item   : ll_item_pointer_type;
        next_item   : ll_item_pointer_type;
    end record;
    
    -- points the list to its last data item
    procedure ll_get_last_item(
        list    : inout ll_item_pointer_type
    );
    
    -- appends a new data item to the given list
    procedure ll_append(
        list    : inout ll_item_pointer_type;
        data    : in string
    );
    
    -- inserts a new data item at the given index or appends it,
    -- if index is greater than the length of the list
    procedure ll_insert(
        list    : inout ll_item_pointer_type;
        data    : in string;
        index   : in natural
    );
    
    -- removes the given data item from the list
    procedure ll_remove(
        item    : inout ll_item_pointer_type
    );
    
    -- removes the given data item from the list
    procedure ll_remove(
        list    : inout ll_item_pointer_type;
        data    : in string
    );
    
    -- removes the data item at the given index from the list
    procedure ll_remove(
        list    : inout ll_item_pointer_type;
        index   : in natural
    );
    
    -- prints the given list
    procedure ll_report(
        list    : inout ll_item_pointer_type
    );

end package;

package body linked_list is
    
    procedure ll_get_last_item(
        list    : inout ll_item_pointer_type
    ) is
    begin
        if list=null then
            return;
        end if;
        
        while list.next_item/=null loop
            list    := list.next_item;
        end loop;
    end procedure;
    
    procedure ll_append(
        list    : inout ll_item_pointer_type;
        data    : in string
    ) is
        variable p      : ll_item_pointer_type;
    begin
        p   := list;
        
        if p=null then
            list        := new ll_item_type;
            list.data   := new string'(data);
            return;
        end if;
        
        ll_get_last_item(p);
        
        p.next_item             := new ll_item_type;
        p.next_item.data        := new string'(data);
        p.next_item.prev_item   := p;
    end procedure;
    
    procedure ll_insert(
        list    : inout ll_item_pointer_type;
        data    : in string;
        index   : in natural
    ) is
        variable p      : ll_item_pointer_type;
        variable item   : ll_item_pointer_type;
    begin
        p   := list;
        
        if p=null then
            list        := new ll_item_type;
            list.data   := new string'(data);
            return;
        end if;
        
        for i in 1 to index loop
            if p.next_item=null then
                -- index is greater than the list size
                ll_append(list, data);
                return;
            end if;
            
            p   := p.next_item;
        end loop;
        
        item            := new ll_item_type;
        item.data       := new string'(data);
        item.prev_item  := p.prev_item;
        item.next_item  := p;
        
        -- close the gap
        
        if p.prev_item/=null then
            p.prev_item.next_item   := item;
        end if;
        
        p.prev_item := item;
        
        if index=0 then
            list    := item;
        end if;
    end procedure;
    
    procedure ll_remove(
        item    : inout ll_item_pointer_type
    ) is
        variable p  : ll_item_pointer_type;
    begin
        p   := item;
        
        if p=null then
            return;
        end if;
        
        -- remove inner item in list, close the gap
        
        if p.prev_item/=null then
            p.prev_item.next_item   := p.next_item;
        end if;
        if p.next_item/=null then
            p.next_item.prev_item   := p.prev_item;
        end if;
        item    := p.next_item;
        
        deallocate(p.data);
        deallocate(p);
    end procedure;
    
    procedure ll_remove(
        list    : inout ll_item_pointer_type;
        data    : in string
    ) is
        variable p  : ll_item_pointer_type;
        variable i  : natural;
    begin
        p   := list;
        i   := 0;
        
        if p=null then
            return;
        end if;
        
        while p.data.all/=data and p.next_item/=null loop
            p   := p.next_item;
            i   := i+1;
        end loop;
        
        if p.data.all/=data then
            return;
        end if;
        
        ll_remove(p);
        if i=0 then
            list    := p;
        end if;
    end procedure;
    
    procedure ll_remove(
        list    : inout ll_item_pointer_type;
        index   : in natural
    ) is
        variable p  : ll_item_pointer_type;
    begin
        p   := list;
        
        if p=null then
            return;
        end if;
        
        for i in 1 to index loop
            if p.next_item=null then
                return;
            end if;
            
            p   := p.next_item;
        end loop;
        
        ll_remove(p);
        if index=0 then
            list    := p;
        end if;
    end procedure;
    
    procedure ll_report(
        list    : inout ll_item_pointer_type
    ) is
        variable p          : ll_item_pointer_type;
        variable i          : natural;
        variable l          : line;
    begin
        if list=null then
            write(l, "[empty list]");
            writeline(OUTPUT, l);
            return;
        end if;
        
        p   := list;
        i   := 0;
        
        while p/=null loop
            write(l, "[" & str(i) & "] " & p.data.all);
            writeline(OUTPUT, l);
            deallocate(l);
            p   := p.next_item;
            i   := i+1;
        end loop;
    end procedure;
    
end;
