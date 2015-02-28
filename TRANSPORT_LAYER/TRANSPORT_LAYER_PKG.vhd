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
        was_sent    : boolean;
        buf_index   : unsigned(log2(BUFFERED_PACKETS)-1 downto 0);
    end record;
    
    constant packet_record_type_def : packet_record_type := (
        is_buffered => false,
        was_sent    => false,
        buf_index   => (others => '0')
    );
    
    type packet_records_type is
        array(0 to 255) of
        packet_record_type;
    
    constant packet_records_type_def    : packet_records_type := (
        others => packet_record_type_def
    );
    
    --- packet meta information records, for resending packets ---
    
    type packet_meta_record_type is record
        is_buffered     : boolean;
        packet_number   : unsigned(7 downto 0);
        packet_length   : unsigned(7 downto 0);
        checksum        : std_ulogic_vector(7 downto 0);
    end record;
    
    constant packet_meta_record_type_def    : packet_meta_record_type := (
        is_buffered     => false,
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
