
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

package help_funcs is

    function maximum(l, r : natural) return natural;
    function minimum(l, r : natural) return natural;
    function "+"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
    function "+"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector;
    function "+"(l : std_ulogic_vector; r : std_ulogic) return std_ulogic_vector;
    function "+"(u : unsigned; v : std_ulogic_vector) return unsigned;
    function "+"(u : unsigned; v : std_ulogic) return unsigned;
    function "+"(vl, vr : std_ulogic_vector) return std_ulogic_vector;
    function "+"(l : signed; r : std_ulogic) return signed;
    function "-"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
    function "-"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector;
    function "-"(l : std_ulogic_vector; r : std_ulogic) return std_ulogic_vector;
    function "-"(u : unsigned; v : std_ulogic_vector) return unsigned;
    function "-"(u : unsigned; v : std_ulogic) return unsigned;
    function "-"(vl, vr : std_ulogic_vector) return std_ulogic_vector;
    function "-"(l : signed; r : std_ulogic) return signed;
    function "*"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
    function "*"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector;
    function "*"(u : unsigned; v : std_ulogic_vector) return unsigned;
    function "*"(vl, vr : std_ulogic_vector) return std_ulogic_vector;
    function "="(v : std_ulogic_vector; n : natural) return boolean;
    function "="(n : natural; v : std_ulogic_vector) return boolean;
    function "="(u : unsigned; v : std_ulogic_vector) return boolean;
    function "/="(v : std_ulogic_vector; n : natural) return boolean;
    function "/="(n : natural; v : std_ulogic_vector) return boolean;
    function "/="(u : unsigned; v : std_ulogic_vector) return boolean;
    function ">"(v : std_ulogic_vector; n : natural) return boolean;
    function ">"(u : unsigned; n : natural) return boolean;
    function ">"(n : natural; v : std_ulogic_vector) return boolean;
    function ">"(u : unsigned; v : std_ulogic_vector) return boolean;
    function ">"(v : std_ulogic_vector; u : unsigned) return boolean;
    function ">"(vl, vr : std_ulogic_vector) return boolean;
    function "<"(v : std_ulogic_vector; n : natural) return boolean;
    function "<"(u : unsigned; n : natural) return boolean;
    function "<"(n : natural; v : std_ulogic_vector) return boolean;
    function "<"(u : unsigned; v : std_ulogic_vector) return boolean;
    function "<"(v : std_ulogic_vector; u : unsigned) return boolean;
    function "<"(vl, vr : std_ulogic_vector) return boolean;
    function ">="(v : std_ulogic_vector; n : natural) return boolean;
    function ">="(u : unsigned; n : natural) return boolean;
    function ">="(n : natural; v : std_ulogic_vector) return boolean;
    function ">="(u : unsigned; v : std_ulogic_vector) return boolean;
    function ">="(v : std_ulogic_vector; u : unsigned) return boolean;
    function ">="(vl, vr : std_ulogic_vector) return boolean;
    function "<="(v : std_ulogic_vector; n : natural) return boolean;
    function "<="(u : unsigned; n : natural) return boolean;
    function "<="(n : natural; v : std_ulogic_vector) return boolean;
    function "<="(u : unsigned; v : std_ulogic_vector) return boolean;
    function "<="(v : std_ulogic_vector; u : unsigned) return boolean;
    function "<="(vl, vr : std_ulogic_vector) return boolean;
    function "&"(ul, ur : unsigned) return unsigned;
    function "mod"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
    function int(v : std_ulogic_vector) return integer;
    function int(u : unsigned) return integer;
    function int(s : signed) return integer;
    function int(c : character) return integer;
    function uns(v : std_ulogic_vector) return unsigned;
    function uns(n, l : natural) return unsigned;
    function sig(n : integer; l : natural) return signed;
    function stdul(v : std_logic) return std_ulogic;
    function stdlv(v : std_ulogic_vector) return std_logic_vector;
    function stdulv(v : std_logic_vector) return std_ulogic_vector;
    function stdulv(n, l : natural) return std_ulogic_vector;
    function stdulv(u : unsigned) return std_ulogic_vector;
    function stdulv(c : character) return std_ulogic_vector; -- ASCII to 8 bit binary
    function log2(val: natural) return natural;
    function sel(c : boolean; r1, r2 : natural) return natural;
    function sel(c : boolean; r1, r2 : std_ulogic) return std_ulogic;
    function arith_mean(vl, vr : std_ulogic_vector) return std_ulogic_vector;

end help_funcs;

package body help_funcs is
    
    function maximum(l, r : natural) return natural is
    begin
        if l > r then
            return l;
        end if;
        return r;
    end function;
    
    function minimum(l, r : natural) return natural is
    begin
        if l < r then
            return l;
        end if;
        return r;
    end function;
    
    
    ----------------
    --- Addition ---
    ----------------
    
    function "+"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
    begin
        return std_ulogic_vector(uns(v) + uns(n, v'length));
    end function;
    
    function "+"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector is
    begin
        return stdulv(uns(v) + u);
    end function;
    
    function "+"(l : std_ulogic_vector; r : std_ulogic) return std_ulogic_vector is
        variable t  : std_ulogic_vector(l'range);
    begin
        t   := (l'low => r, others => '0');
        return l + t;
    end function;
    
    function "+"(u : unsigned; v : std_ulogic_vector) return unsigned is
    begin
        return u + uns(v);
    end function;
    
    function "+"(u : unsigned; v : std_ulogic) return unsigned is
        variable t  : std_ulogic_vector(u'range);
    begin
        t   := (u'low => v, others => '0');
        return u + uns(t);
    end function;
    
    function "+"(vl, vr : std_ulogic_vector) return std_ulogic_vector is
    begin
        return stdulv(uns(vl) + uns(vr));
    end function;
    
    function "+"(l : signed; r : std_ulogic) return signed is
        variable t  : signed(l'range);
    begin
        t   := (l'low => r, others => '0');
        return l + t;
    end function;
    
    
    -------------------
    --- Subtraction ---
    -------------------
    
    function "-"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
    begin
        return std_ulogic_vector(uns(v) - uns(n, v'length));
    end function;
    
    function "-"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector is
    begin
        return stdulv(uns(v) - u);
    end function;
    
    function "-"(l : std_ulogic_vector; r : std_ulogic) return std_ulogic_vector is
        variable t  : std_ulogic_vector(l'range);
    begin
        t   := (l'low => r, others => '0');
        return l - t;
    end function;
    
    function "-"(u : unsigned; v : std_ulogic_vector) return unsigned is
    begin
        return u - uns(v);
    end function;
    
    function "-"(u : unsigned; v : std_ulogic) return unsigned is
        variable t : std_ulogic_vector(u'range);
    begin
        t   := (u'low => v, others => '0');
        return u - uns(t);
    end function;
    
    function "-"(vl, vr : std_ulogic_vector) return std_ulogic_vector is
    begin
        return stdulv(uns(vl) - uns(vr));
    end function;
    
    function "-"(l : signed; r : std_ulogic) return signed is
        variable t  : signed(l'range);
    begin
        t   := (l'low => r, others => '0');
        return l - t;
    end function;
    
    
    ----------------------
    --- Multiplication ---
    ----------------------
    
    function "*"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
    begin
        return std_ulogic_vector(uns(v) * to_unsigned(n, v'length));
    end function;
    
    function "*"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector is
    begin
        return stdulv(uns(v) * u);
    end function;
    
    function "*"(u : unsigned; v : std_ulogic_vector) return unsigned is
    begin
        return u * uns(v);
    end function;
    
    function "*"(vl, vr : std_ulogic_vector) return std_ulogic_vector is
    begin
        return stdulv(uns(vl) * uns(vr));
    end function;
    
    
    ------------------
    --- Comparison ---
    ------------------
    
    function "="(v : std_ulogic_vector; n : natural) return boolean is
    begin
        return uns(v) = to_unsigned(n, v'length);
    end function;
    
    function "="(n : natural; v : std_ulogic_vector) return boolean is
    begin
        return uns(v) = to_unsigned(n, v'length);
    end function;
    
    function "="(u : unsigned; v : std_ulogic_vector) return boolean is
    begin
        return u = uns(v);
    end function;
    
    function "/="(v : std_ulogic_vector; n : natural) return boolean is
    begin
        return uns(v) /= to_unsigned(n, v'length);
    end function;
    
    function "/="(n : natural; v : std_ulogic_vector) return boolean is
    begin
        return uns(v) /= to_unsigned(n, v'length);
    end function;
    
    function "/="(u : unsigned; v : std_ulogic_vector) return boolean is
    begin
        return u /= uns(v);
    end function;
    
    function ">"(v : std_ulogic_vector; n : natural) return boolean is
    begin
        return uns(v) > to_unsigned(n, v'length);
    end function;
    
    function ">"(u : unsigned; n : natural) return boolean is
    begin
        return u > to_unsigned(n, u'length);
    end function;
    
    function ">"(n : natural; v : std_ulogic_vector) return boolean is
    begin
        return uns(v) > to_unsigned(n, v'length);
    end function;
    
    function ">"(u : unsigned; v : std_ulogic_vector) return boolean is
    begin
        return u > uns(v);
    end function;
    
    function ">"(v : std_ulogic_vector; u : unsigned) return boolean is
    begin
        return uns(v) > u;
    end function;
    
    function ">"(vl, vr : std_ulogic_vector) return boolean is
    begin
        return uns(vl) > uns(vr);
    end function;
    
    function "<"(v : std_ulogic_vector; n : natural) return boolean is
    begin
        return uns(v) < to_unsigned(n, v'length);
    end function;
    
    function "<"(u : unsigned; n : natural) return boolean is
    begin
        return u < to_unsigned(n, u'length);
    end function;
    
    function "<"(n : natural; v : std_ulogic_vector) return boolean is
    begin
        return uns(v) < to_unsigned(n, v'length);
    end function;
    
    function "<"(u : unsigned; v : std_ulogic_vector) return boolean is
    begin
        return u < uns(v);
    end function;
    
    function "<"(v : std_ulogic_vector; u : unsigned) return boolean is
    begin
        return uns(v) < u;
    end function;
    
    function "<"(vl, vr : std_ulogic_vector) return boolean is
    begin
        return uns(vl) < uns(vr);
    end function;
    
    function ">="(v : std_ulogic_vector; n : natural) return boolean is
    begin
        return uns(v) >= to_unsigned(n, v'length);
    end function;
    
    function ">="(u : unsigned; n : natural) return boolean is
    begin
        return u >= to_unsigned(n, u'length);
    end function;
    
    function ">="(n : natural; v : std_ulogic_vector) return boolean is
    begin
        return uns(v) >= to_unsigned(n, v'length);
    end function;
    
    function ">="(u : unsigned; v : std_ulogic_vector) return boolean is
    begin
        return u >= uns(v);
    end function;
    
    function ">="(v : std_ulogic_vector; u : unsigned) return boolean is
    begin
        return uns(v) >= u;
    end function;
    
    function ">="(vl, vr : std_ulogic_vector) return boolean is
    begin
        return uns(vl) >= uns(vr);
    end function;
    
    function "<="(v : std_ulogic_vector; n : natural) return boolean is
    begin
        return uns(v) <= to_unsigned(n, v'length);
    end function;
    
    function "<="(u : unsigned; n : natural) return boolean is
    begin
        return u <= to_unsigned(n, u'length);
    end function;
    
    function "<="(n : natural; v : std_ulogic_vector) return boolean is
    begin
        return uns(v) <= to_unsigned(n, v'length);
    end function;
    
    function "<="(u : unsigned; v : std_ulogic_vector) return boolean is
    begin
        return u <= uns(v);
    end function;
    
    function "<="(v : std_ulogic_vector; u : unsigned) return boolean is
    begin
        return uns(v) <= u;
    end function;
    
    function "<="(vl, vr : std_ulogic_vector) return boolean is
    begin
        return uns(vl) <= uns(vr);
    end function;
    
    
    ---------------------
    --- Concatenation ---
    ---------------------
    
    function "&"(ul, ur : unsigned) return unsigned is
    begin
        return uns(std_ulogic_vector(ul) & std_ulogic_vector(ur));
    end function;
    
    function "&"(ul, ur : unsigned) return std_ulogic_vector is
    begin
        return std_ulogic_vector(ul) & std_ulogic_vector(ur);
    end function;
    
    
    --------------
    --- Modulo ---
    --------------
    
    function "mod"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
    begin
        return stdulv(int(v) mod n, v'length);
    end function;
    
    
    ------------------
    --- Conversion ---
    ------------------
    
    function int(v : std_ulogic_vector) return integer is
    begin
        return to_integer(unsigned(v));
    end function;
    
    function int(u : unsigned) return integer is
    begin
        return to_integer(u);
    end function;
    
    function int(s : signed) return integer is
    begin
        return to_integer(s);
    end function;
    
    function int(c : character) return integer is
    begin
        return character'pos(c);
    end function;
    
    function uns(v : std_ulogic_vector) return unsigned is
    begin
        return unsigned(v);
    end function;
    
    function uns(n, l : natural) return unsigned is
    begin
        return uns(stdulv(n, l));
    end function;
    
    function sig(n : integer; l : natural) return signed is
    begin
        return to_signed(n, l);
    end function;
    
    function stdlv(v : std_ulogic_vector) return std_logic_vector is
    begin
        return std_logic_vector(v);
    end function;
    
    function stdul(v : std_logic) return std_ulogic is
    begin
        return std_ulogic(v);
    end function;
    
    function stdulv(v : std_logic_vector) return std_ulogic_vector is
    begin
        return std_ulogic_vector(v);
    end function;

    function stdulv(n, l : natural) return std_ulogic_vector is
    begin
        return std_ulogic_vector(to_unsigned(n, l));
    end function;

    function stdulv(u : unsigned) return std_ulogic_vector is
    begin
        return std_ulogic_vector(u);
    end function;

    function stdulv(c : character) return std_ulogic_vector is
    begin
        return stdulv(character'pos(c), 8);
    end function;

    function log2(val: natural) return natural is
        variable res : natural;
    begin
        for i in 0 to 31 loop
            if (val <= (2**i)) then
                res := i;
                exit;
            end if;
        end loop;
        return res;
    end function;

    function sel(c : boolean; r1, r2 : natural) return natural is
    begin
        if c then
            return r1;
        end if;
        return r2;
    end function;
    
    function sel(c : boolean; r1, r2 : std_ulogic) return std_ulogic is
    begin
        if c then
            return r1;
        end if;
        return r2;
    end function;
    
    function arith_mean(vl, vr : std_ulogic_vector) return std_ulogic_vector is
        constant bits   : integer := maximum(vl'length, vr'length);
        variable ul, ur : unsigned(bits downto 0);
        variable sum    : std_ulogic_vector(bits downto 0);
    begin
        ul  := resize(uns(vl), bits+1);
        ur  := resize(uns(vr), bits+1);
        sum := stdulv(ul+ur);
        return sum(bits downto 1); -- divide by 2
    end arith_mean;

end help_funcs;
