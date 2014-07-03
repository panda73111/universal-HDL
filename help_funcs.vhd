
library IEEE;
  use IEEE.std_logic_1164.all;
  use IEEE.NUMERIC_STD.ALL;
  
package help_funcs is
  
  function max(l, r : natural) return natural;
  function min(l, r : natural) return natural;
  function "+"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
  function "+"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector;
  function "+"(u : unsigned; v : std_ulogic_vector) return std_ulogic_vector;
  function "+"(vl, vr : std_ulogic_vector) return std_ulogic_vector;
  function "-"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
  function "-"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector;
  function "-"(u : unsigned; v : std_ulogic_vector) return std_ulogic_vector;
  function "-"(vl, vr : std_ulogic_vector) return std_ulogic_vector;
  function "*"(v : std_ulogic_vector; n : natural) return std_ulogic_vector;
  function "*"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector;
  function "*"(u : unsigned; v : std_ulogic_vector) return std_ulogic_vector;
  function "*"(vl, vr : std_ulogic_vector) return std_ulogic_vector;
  function "="(v : std_ulogic_vector; n : natural) return boolean;
  function "="(n : natural; v : std_ulogic_vector) return boolean;
  function "="(u : unsigned; n : natural) return boolean;
  function "="(u : unsigned; v : std_ulogic_vector) return boolean;
  function "/="(v : std_ulogic_vector; n : natural) return boolean;
  function "/="(u : unsigned; n : natural) return boolean;
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
  function "&"(ul, ur : unsigned) return std_ulogic_vector;
  function int(v : std_ulogic_vector) return integer;
  function int(u : unsigned) return integer;
  function uns(v : std_ulogic_vector) return unsigned;
  function uns(n, l : natural) return unsigned;
  function stdulv(n, l : natural) return std_ulogic_vector;
  function stdulv(u : unsigned) return std_ulogic_vector;
  function stdulv(c : character) return std_ulogic_vector; -- ASCII to 8 bit binary
  function log2(val: INTEGER) return natural;
  function sel(c : boolean; r1, r2 : natural) return natural;
  function arith_mean(vl, vr : std_ulogic_vector) return std_ulogic_vector;
  
end help_funcs;

package body help_funcs is
  
  function max(l, r : natural) return natural is
  begin
    if l > r then
      return l;
    else
      return r;
    end if;
  end function;

  function min(l, r : natural) return natural is
  begin
    if l < r then
      return l;
    else
      return r;
    end if;
  end function;
  
  function "+"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
  begin
    return std_ulogic_vector(uns(v) + to_unsigned(n, v'length));
  end function;
  
  function "+"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector is
  begin
    return stdulv(uns(v) + u);
  end function;
  
  function "+"(u : unsigned; v : std_ulogic_vector) return std_ulogic_vector is
  begin
    return stdulv(u + uns(v));
  end function;
  
  function "+"(vl, vr : std_ulogic_vector) return std_ulogic_vector is
  begin
    return stdulv(uns(vl) + uns(vr));
  end function;
  
  function "-"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
  begin
    return std_ulogic_vector(uns(v) - to_unsigned(n, v'length));
  end function;
  
  function "-"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector is
  begin
    return stdulv(uns(v) - u);
  end function;
  
  function "-"(u : unsigned; v : std_ulogic_vector) return std_ulogic_vector is
  begin
    return stdulv(u - uns(v));
  end function;
  
  function "-"(vl, vr : std_ulogic_vector) return std_ulogic_vector is
  begin
    return stdulv(uns(vl) - uns(vr));
  end function;
  
  function "*"(v : std_ulogic_vector; n : natural) return std_ulogic_vector is
  begin
    return std_ulogic_vector(uns(v) * to_unsigned(n, v'length));
  end function;
  
  function "*"(v : std_ulogic_vector; u : unsigned) return std_ulogic_vector is
  begin
    return stdulv(uns(v) * u);
  end function;
  
  function "*"(u : unsigned; v : std_ulogic_vector) return std_ulogic_vector is
  begin
    return stdulv(u * uns(v));
  end function;
  
  function "*"(vl, vr : std_ulogic_vector) return std_ulogic_vector is
  begin
    return stdulv(uns(vl) * uns(vr));
  end function;
  
  function "="(v : std_ulogic_vector; n : natural) return boolean is
  begin
    return uns(v) = to_unsigned(n, v'length);
  end function;
  
  function "="(u : unsigned; n : natural) return boolean is
  begin
    return u = to_unsigned(n, u'length);
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
  
  function "/="(u : unsigned; n : natural) return boolean is
  begin
    return u /= to_unsigned(n, u'length);
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
  
  function "&"(ul, ur : unsigned) return unsigned is
  begin
    return uns(std_ulogic_vector(ul) & std_ulogic_vector(ur));
  end function;
  
  function "&"(ul, ur : unsigned) return std_ulogic_vector is
  begin
    return std_ulogic_vector(ul) & std_ulogic_vector(ur);
  end function;
  
  function int(u : unsigned) return integer is
  begin
    return to_integer(u);
  end function;
  
  function int(v : std_ulogic_vector) return integer is
  begin
    return to_integer(unsigned(v));
  end function;
  
  function uns(v : std_ulogic_vector) return unsigned is
  begin
    return unsigned(v);
  end function;
  
  function uns(n, l : natural) return unsigned is
  begin
    return uns(stdulv(n, l));
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
    variable ret  : std_ulogic_vector(7 downto 0);
    variable tmp  : integer := character'pos(c);
  begin
    for i in ret'reverse_range loop
      if tmp mod 2 = 1 then
        ret(i)  := '1';
      else
        ret(i)  := '0';
      end if;
      tmp := tmp / 2;
    end loop;
    return ret;
  end function;
  
  function log2(val: INTEGER) return natural is
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
    else
      return r2;
    end if;
  end function;
  
  function arith_mean(vl, vr : std_ulogic_vector) return std_ulogic_vector is
    constant bits   : integer := max(vl'length, vr'length);
    variable ul, ur : unsigned(bits downto 0);
    variable sum    : std_ulogic_vector(bits downto 0);
  begin
    ul  := resize(uns(vl), bits+1);
    ur  := resize(uns(vr), bits+1);
    sum := stdulv(ul+ur);
    return sum(bits downto 1); -- divide by 2
  end arith_mean;
  
end help_funcs;
