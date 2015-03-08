library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

package TRANSPORT_LAYER_PKG is
    
    constant BUFFERED_PACKETS   : positive := 8;
    constant DATA_MAGIC         : std_ulogic_vector(7 downto 0) := x"65";
    constant ACK_MAGIC          : std_ulogic_vector(7 downto 0) := x"66";
    constant RESEND_MAGIC       : std_ulogic_vector(7 downto 0) := x"67";
    
    type packet_record_type is record
        is_buffered : boolean;
        buf_index   : unsigned(log2(BUFFERED_PACKETS)-1 downto 0);
    end record;
    
    constant packet_record_type_def : packet_record_type := (
        is_buffered => false,
        buf_index   => (others => '0')
    );
    
    type packet_records_type is
        array(0 to 255) of
        std_ulogic_vector(log2(BUFFERED_PACKETS) downto 0);
    
    constant packet_records_type_def    : packet_records_type := (
        others => (others => '0')
    );
    
    function packet_record_type_to_vector(d : in packet_record_type) return std_ulogic_vector is
        variable v  : std_ulogic_vector(log2(BUFFERED_PACKETS) downto 0);
    begin
        v   := (others => '0');
        if d.is_buffered then
            v(0)    := '1';
        end if;
        v(v'high downto 1)  := stdulv(d.buf_index);
        return v;
    end function;
    
    function vector_to_packet_record_type(v : in std_ulogic_vector) return packet_record_type is
        variable d  : packet_record_type;
    begin
        d.is_buffered   := v(0)='1';
        d.buf_index     := uns(v(v'high downto 1));
        return d;
    end function;
    
    --- packet meta information records, for resending packets ---
    
    type packet_meta_record_type is record
        packet_number   : unsigned(7 downto 0);
        packet_length   : unsigned(7 downto 0);
        checksum        : std_ulogic_vector(7 downto 0);
    end record;
    
    constant packet_meta_record_type_def    : packet_meta_record_type := (
        packet_number   => x"00",
        packet_length   => x"00",
        checksum        => x"00"
    );
    
    type packet_meta_records_type is
        array(0 to BUFFERED_PACKETS-1) of
        packet_meta_record_type;
    
    constant packet_meta_records_type_def   : packet_meta_records_type := (
        others  => packet_meta_record_type_def
    );
    
end TRANSPORT_LAYER_PKG;

package body TRANSPORT_LAYER_PKG is
    
end TRANSPORT_LAYER_PKG;
