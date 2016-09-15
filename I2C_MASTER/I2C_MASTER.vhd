----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    20:02:28 09/15/2016
-- Design Name:    I2C_MASTER
-- Module Name:    I2C_MASTER - rtl
-- Tool versions:  Xilinx ISE 14.7
-- Description:
--  
-- Additional Comments:
--  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.help_funcs.all;

entity I2C_MASTER is
    generic (
        CLK_IN_PERIOD   : real
    );
    port (
        RST : in std_ulogic;
        CLK : in std_ulogic;
        
        SDA_IN  : in std_ulogic;
        SCL_IN  : in std_ulogic;
        SDA_OUT : out std_ulogic := '1';
        SCL_OUT : out std_ulogic := '1';
        
        ADDR    : in std_ulogic_vector(6 downto 0);
        RD_EN   : in std_ulogic;
        WR_EN   : in std_ulogic;
        
        DOUT        : out std_ulogic_vector(7 downto 0) := x"00";
        DOUT_VALID  : out std_ulogic := '0';
        BUSY        : out std_ulogic := '0';
        ERROR       : out std_ulogic := '0'
    );
end I2C_MASTER;

architecture rtl of I2C_MASTER is
    
    -- target frequency: 100 kHz = 10 us period;
    -- SCL states: rising, high, falling, low;
    -- switch the state after 10 us / 4 = 2.5 us
    constant SCL_STATE_TICKS    : positive := (2500 / CLK_IN_PERIOD);
    
    type scl_state_type is (
        RISING,
        HIGH,
        FALLING,
        LOW
    );
    
    type state_type is (
        WAITING_FOR_START,
        READ_ACCESS_SENDING_START,
        READ_ACCESS_SENDING_ADDR,
        READ_ACCESS_SENDING_READ_BIT,
        READ_ACCESS_GETTING_ADDR_ACK,
        READ_ACCESS_GETTING_DATA,
        READ_ACCESS_SENDING_DATA_ACK,
        READ_ACCESS_SENDING_DATA_NACK,
        WRITE_ACCESS_SENDING_START,
        WRITE_ACCESS_SENDING_ADDR,
        WRITE_ACCESS_SENDING_WRITE_BIT,
        WRITE_ACCESS_GETTING_ADDR_ACK,
        WRITE_ACCESS_SENDING_DATA,
        WRITE_ACCESS_GETTING_DATA_ACK,
        SENDING_STOP
    );
    
    type reg_type is record
        state       : state_type;
        active      : boolean;
        error       : std_ulogic;
        scl_out     : std_ulogic;
        sda_out     : std_ulogic;
        bit_index   : natural;
        bit_counter : unsigned(3 downto 0);
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => WAITING_FOR_START,
        active      => false,
        error       => '0',
        scl_out     => '1',
        sda_out     => '1',
        bit_index   => 7,
        bit_counter => uns(5, 4)
    );
    
    signal scl_state    : scl_state_type := RISING;
    signal scl_counter  : unsigned(log2(SCL_STATE_TICKS) downto 0) := (others => '0');
    signal scl_event    : boolean := false;
    
    signal cur_reg, next_reg    : reg_type  := reg_type_def;
    
    signal sda_in_sync, scl_in_sync : std_ulogic := '1';
    
begin
    
    SDA_OUT <= '0' when cur_reg.sda_out='0' else 'Z';
    SCL_OUT <= '0' when cur_reg.scl_out='0' else 'Z';
    
    ERROR   <= cur_reg.error;
    BUSY    <= '1' when cur_reg.active else '0';
    
    SDA_IN_SIGNAL_SYNC_inst : entity work.SIGNAL_SYNC
        generic map (
            DEFAULT_VALUE   => '1'
        )
        port map (
            DIN     => SDA_IN,
            DOUT    => sda_in_sync
        );
    
    SCL_IN_SIGNAL_SYNC_inst : entity work.SIGNAL_SYNC
        generic map (
            DEFAULT_VALUE   => '1'
        )
        port map (
            DIN     => SCL_IN,
            DOUT    => scl_in_sync
        );
    
    scl_event_proc : process(RST, CLK)
    begin
        if not cur_reg.out_enable then
            scl_counter <= (others => '0');
            scl_event   <= false;
        elsif rising_edge(CLK) then
            scl_counter <= scl_counter-1;
            scl_event   <= false;
            
            if scl_counter(scl_counter'high)='1' then
                
                scl_counter <= uns(SCL_STATE_TICKS-1, scl_counter'length);
                scl_state   <= scl_state_type'succ(scl_state);
                scl_event   <= true;
                
                if scl_state=SCL_RISE and scl_in_sync='0' then
                    -- clock stretch
                    scl_event   <= false;
                    scl_state   <= SCL_RISE;
                end if;
                
            end if;
        end if;
    end process;
    
    stm_proc : process(cur_reg, RST, sda_in_sync, scl_in_sync, RD_EN, WR_EN, scl_event, scl_state)
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        if scl_state=RISING then
            r.scl_out   := '1';
        elsif scl_state=FALLING then
            r.scl_out   := '0';
        end if;
        
        case cr.state is
            
            when WAITING_FOR_START =>
                r.active    := false;
                if RD_EN='1' then
                    r.active    := true;
                    r.error     := '0';
                    r.state     := READ_ACCESS_SENDING_START;
                end if;
                if WR_EN='1' then
                    r.active    := true;
                    r.error     := '0';
                    r.state     := WRITE_ACCESS_SENDING_START;
                end if;
            
            when READ_ACCESS_SENDING_START =>
                if scl_state=HIGH then
                    r.sda_out   := '0';
                elsif scl_state=FALLING then
                    r.state := READ_ACCESS_SENDING_ADDR;
                end if;
            
            when READ_ACCESS_SENDING_ADDR =>
                if scl_state=LOW then
                    r.bit_index     := cr.bit_index+1;
                    r.bit_counter   := cr.bit_counter-1;
                    r.sda_out       := ADDR(cr.bit_index);
                elsif scl_state=FALLING then
                    if cr.bit_counter(3)='1' then
                        r.state := READ_ACCESS_SENDING_READ_BIT;
                    end if;
                end if;
            
            when READ_ACCESS_SENDING_READ_BIT =>
                if scl_state=LOW then
                    r.sda_out   := '1';
                elsif scl_state=FALLING then
                    r.state     := READ_ACCESS_GETTING_ADDR_ACK;
                end if;
            
            when READ_ACCESS_GETTING_ADDR_ACK =>
                if scl_state=HIGH then
                    r.state := READ_ACCESS_GETTING_DATA;
                    if sda_in_sync/='0' then
                        r.error := '1';
                        r.state := SEND_STOP; -- NACK
                    end if;
                end if;
            
            when READ_ACCESS_GETTING_DATA =>
                
            
            when READ_ACCESS_SENDING_DATA_ACK =>
                
            
            when READ_ACCESS_SENDING_DATA_NACK =>
                
            
            when WRITE_ACCESS_SENDING_START =>
                
            
            when WRITE_ACCESS_SENDING_ADDR =>
                
            
            when WRITE_ACCESS_SENDING_WRITE_BIT =>
                
            
            when WRITE_ACCESS_GETTING_ADDR_ACK =>
                if scl_state=HIGH then
                    r.state := READ_ACCESS_GETTING_DATA;
                    if sda_in_sync/='0' then
                        r.error := '1';
                        r.state := SEND_STOP; -- NACK
                    end if;
                end if;
            
            when WRITE_ACCESS_SENDING_DATA =>
                if scl_state=HIGH then
                    r.state := READ_ACCESS_GETTING_DATA;
                    if sda_in_sync/='0' then
                        r.error := '1';
                        r.state := SEND_STOP; -- NACK
                    end if;
                end if;
            
            when WRITE_ACCESS_GETTING_DATA_ACK =>
                
            
            when SENDING_STOP =>
                if scl_state=HIGH then
                    r.sda_out   := '1';
                elsif scl_state=FALLING then
                    r.state := WAITING_FOR_START;
                end if;
            
        end case;
        
        if not scl_event and not r.active then
            r   := cur_reg;
        end if;
        
        if RST='1' or not r.active then
            r   := reg_type_def;
        end if;
        
        next_reg    <= r;
    end process;
    
    sync_stm_proc : process(RST, CLK)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(CLK) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end;
