----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    18:07:14 01/25/2014 
-- Design Name:    CLK_MAN
-- Module Name:    CLK_MAN - rtl
-- Tool versions:  Xilinx ISE 14.7
-- Description:    
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity CLK_MAN is
    generic (
        CLK_IN_PERIOD : real;
        MULTIPLIER    : natural range 2 to 256 := 2;
        DIVISOR       : natural range 1 to 256 := 1
    );
    port (
        CLK_IN  : in std_ulogic;
        RST     : in std_ulogic;
        
        REPROG_MULT : in std_ulogic_vector(7 downto 0) := x"00";
        REPROG_DIV  : in std_ulogic_vector(7 downto 0) := x"00";
        REPROG_EN   : in std_ulogic := '0';
        
        CLK_OUT     : out std_ulogic := '0';
        CLK_OUT_180 : out std_ulogic := '0';
        LOCKED      : out std_ulogic := '0'
    );
end;

architecture rtl of CLK_MAN is
    
    type state_type is (
        WAIT_FOR_START,
        SEND_CMD_LOAD_D1,
        SEND_CMD_LOAD_D2,
        SEND_DIV,
        DIV_GAP1,
        DIV_GAP2,
        SEND_CMD_LOAD_M1,
        SEND_CMD_LOAD_M2,
        SEND_MULT,
        MULT_GAP,
        SEND_CMD_GO,
        WAIT_FOR_PROGDONE
    );
    
    type reg_type is record
        state       : state_type;
        bit_index   : natural range 0 to 7;
        progen      : std_ulogic;
        progdata    : std_ulogic;
    end record;
    
    constant reg_type_def   : reg_type := (
        state       => WAIT_FOR_START,
        bit_index   => 7,
        progen      => '0',
        progdata    => '0'
    );
    
    signal cur_reg, next_reg    : reg_type := reg_type_def;
    
    signal rst_dcm          : std_ulogic := '0';
    signal dcm_locked       : std_ulogic := '0';
    signal dcm_status       : std_logic_vector(1 downto 0) := "00";
    signal clkfx_stopped    : std_ulogic := '0';
    signal progdone         : std_ulogic := '0';
    signal rst_dcm_holder   : std_ulogic_vector(3 downto 0) := x"F";
    
begin
    
    LOCKED  <= dcm_locked;
    
    clkfx_stopped   <= dcm_status(1);
    rst_dcm         <= RST or (clkfx_stopped and not dcm_locked);
    
    inst_dcm_clkgen : DCM_CLKGEN
        generic map (
            CLKIN_PERIOD    => CLK_IN_PERIOD,
            CLKFX_MULTIPLY  => MULTIPLIER,
            CLKFX_DIVIDE    => DIVISOR
            )
        port map (
            CLKIN       => CLK_IN,
            RST         => rst_dcm_holder(3),
            
            FREEZEDCM   => '0',
            
            PROGCLK     => CLK_IN,
            PROGDATA    => cur_reg.progdata,
            PROGEN      => cur_reg.progen,
            PROGDONE    => progdone,
            
            CLKFX       => CLK_OUT,
            CLKFX180    => CLK_OUT_180,
            STATUS      => dcm_status,
            LOCKED      => dcm_locked
            );
    
    dcm_rst_holder_proc : process(rst_dcm, CLK_IN)
    begin
        if rst_dcm='1' then
            rst_dcm_holder  <= x"F";
        elsif rising_edge(CLK_IN) then
            rst_dcm_holder(3 downto 1)  <= rst_dcm_holder(2 downto 0);
            rst_dcm_holder(0)           <= '0';
        end if;
    end process;
    
    stm_proc : process(cur_reg, RST, REPROG_EN, REPROG_MULT, REPROG_DIV, progdone)
        
        alias cr is cur_reg;
        variable r  : reg_type := reg_type_def;
    begin
        r   := cr;
        
        case cr.state is
            
            when WAIT_FOR_START =>
                r.bit_index := 0;
                r.progen    := '0';
                r.progdata  := '0';
                if REPROG_EN='1' then
                    r.state := SEND_CMD_LOAD_D1;
                end if;
            
            when SEND_CMD_LOAD_D1 =>
                r.progen    := '1';
                r.progdata  := '1';
                r.state     := SEND_CMD_LOAD_D2;
            
            when SEND_CMD_LOAD_D2 =>
                r.progdata  := '0';
                r.state     := SEND_DIV;
            
            when SEND_DIV =>
                r.bit_index := cr.bit_index+1;
                r.progdata  := REPROG_DIV(cr.bit_index);
                if cr.bit_index=7 then
                    r.bit_index := 0;
                    r.state     := DIV_GAP1;
                end if;
            
            when DIV_GAP1 =>
                r.progen    := '0';
                r.state     := DIV_GAP2;
            
            when DIV_GAP2 =>
                r.state := SEND_CMD_LOAD_M1;
            
            when SEND_CMD_LOAD_M1 =>
                r.progen    := '1';
                r.progdata  := '1';
                r.state     := SEND_CMD_LOAD_M2;
                
            
            when SEND_CMD_LOAD_M2 =>
                r.state     := SEND_MULT;
            
            when SEND_MULT =>
                r.bit_index := cr.bit_index+1;
                r.progdata  := REPROG_MULT(cr.bit_index);
                if cr.bit_index=7 then
                    r.bit_index := 0;
                    r.state     := MULT_GAP;
                end if;
            
            when MULT_GAP =>
                r.progen    := '0';
                r.state     := SEND_CMD_GO;
            
            when SEND_CMD_GO =>
                r.progen    := '1';
                r.state     := WAIT_FOR_PROGDONE;
            
            when WAIT_FOR_PROGDONE =>
                r.progen    := '0';
                if PROGDONE='1' then
                    r.state := WAIT_FOR_START;
                end if;
            
        end case;
        
        if RST='1' then
            r   := reg_type_def;
        end if;
        
        next_reg    <= r;
    end process;
    
    stm_sync_proc : process(RST, CLK_IN)
    begin
        if RST='1' then
            cur_reg <= reg_type_def;
        elsif rising_edge(CLK_IN) then
            cur_reg <= next_reg;
        end if;
    end process;
    
end;

