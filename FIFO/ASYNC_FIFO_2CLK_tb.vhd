----------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
-- 
-- Create Date:    14:48:35 01/14/2015 
-- Module Name:    ASYNC_FIFO_2CLK_tb - behavioral 
-- Project Name:   ASYNC_FIFO_2CLK
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

entity ASYNC_FIFO_2CLK_tb is
    generic (
        WIDTH   : positive := 8;
        DEPTH   : positive := 32
    );  
end ASYNC_FIFO_2CLK_tb;

architecture behavior of ASYNC_FIFO_2CLK_tb is
    
    -- inputs
    signal RD_CLK   : std_ulogic := '0';
    signal WR_CLK   : std_ulogic := '0';
    signal RST      : std_ulogic := '0';
    
    signal RD_EN    : std_ulogic := '0';
    signal WR_EN    : std_ulogic := '0';
    signal DIN      : std_ulogic_vector(7 downto 0) := x"00";
    
    -- outputs
    signal VALID    : std_ulogic;
    signal WR_ACK   : std_ulogic;
    signal FULL     : std_ulogic;
    signal EMPTY    : std_ulogic;
    signal DOUT     : std_ulogic_vector(7 downto 0);
    
    -- clock period definitions
    constant RD_CLK_PERIOD  : time := 20 ns; -- 50 MHz
    constant WR_CLK_PERIOD  : time := 30 ns; -- 33 MHz
    
    signal start_read   : boolean := false;
    signal start_write  : boolean := false;
    
    signal read_stage   : natural := 0;
    signal write_stage  : natural := 0;
    
begin
    
    ASYNC_FIFO_2CLK_inst : entity work.ASYNC_FIFO_2CLK
        generic map (
            WIDTH   => WIDTH,
            DEPTH   => DEPTH
        )
        port map (
            RD_CLK  => RD_CLK,
            WR_CLK  => WR_CLK,
            RST     => RST,
            
            RD_EN   => RD_EN,
            WR_EN   => WR_EN,
            DIN     => DIN,
            
            VALID   => VALID,
            WR_ACK  => WR_ACK,
            FULL    => FULL,
            EMPTY   => EMPTY,
            DOUT    => DOUT
        );
    
    RD_CLK  <= not RD_CLK after RD_CLK_PERIOD;
    WR_CLK  <= not WR_CLK after WR_CLK_PERIOD;
    
    stim_proc : process
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        
        start_read  <= true;
        start_write <= true;
        
        -- stage 0: fill the FIFO
        
        wait until read_stage=1 and write_stage=1;
        
        -- stage 1: empty the FIFO
        
        wait until read_stage=2 and write_stage=2;
        
        -- stage 2: write too much data to the FIFO
        
        wait until read_stage=3 and write_stage=3;
        
        wait for 1 us;
        report "NONE. All tests completed."
            severity FAILURE;
    end process;
    
    read_proc : process
        variable dout_counter   : unsigned(WIDTH-1 downto 0);
        
        procedure read_bytes(
            variable data           : inout unsigned(7 downto 0);
            constant count          : in positive;
            constant expect_empty   : in boolean
        ) is
        begin
            wait until falling_edge(RD_CLK);
            RD_EN   <= '1';
            wait until rising_edge(RD_CLK);
            for i in 0 to count-1 loop
                wait until rising_edge(RD_CLK);
                if expect_empty then
                    assert EMPTY='1'
                        report "FIFO unexpectedly not empty!"
                        severity FAILURE;
                    assert VALID='0'
                        report "Got unexpected data!"
                        severity FAILURE;
                else
                    assert EMPTY='0'
                        report "FIFO unexpectedly empty!"
                        severity FAILURE;
                    assert VALID='1'
                        report "Didn't get any data!"
                        severity FAILURE;                
                    assert DOUT=stdulv(dout_counter)
                        report "Got wrong data!"
                        severity FAILURE;
                end if;
                
                dout_counter    := dout_counter+1;
            end loop;
            RD_EN   <= '0';
        end procedure;
    begin
        RD_EN           <= '0';
        dout_counter    := (others => '0');
        wait until start_read;
        
        -- stage 0
        wait until write_stage=1;
        
        read_stage  <= read_stage+1;
        
        -- stage 1
        
        read_bytes(dout_counter, DEPTH-1, false);
        read_bytes(dout_counter, 1, true);
        
        read_stage  <= read_stage+1;
        
        -- stage 2
        wait until write_stage=3;
        
        read_stage  <= read_stage+1;
        
        wait;
    end process;
    
    write_proc : process
        variable din_counter    : unsigned(WIDTH-1 downto 0);
        
        procedure write_bytes(
            variable data           : inout unsigned(7 downto 0);
            constant count          : in positive;
            constant expect_full    : in boolean
        ) is
        begin
            wait until falling_edge(WR_CLK);
            WR_EN   <= '1';
            for i in 0 to count-1 loop
                DIN         <= stdulv(din_counter);
                din_counter := din_counter+1;
                
                wait until rising_edge(WR_CLK);
                if expect_full then
                    assert FULL='1'
                        report "FIFO unexpectedly not full!"
                        severity FAILURE;
                else
                    assert FULL='0'
                        report "FIFO unexpectedly full!"
                        severity FAILURE;
                end if;
                
                wait until falling_edge(WR_CLK);
            end loop;
            WR_EN   <= '0';
        end procedure;
    begin
        WR_EN       <= '0';
        din_counter := uns(0, din_counter'length);
        wait until start_write;
        
        -- stage 0
        write_bytes(din_counter, DEPTH, false);
        wait until rising_edge(WR_CLK);
        assert FULL='1'
            report "FIFO unexpectedly not full!"
            severity FAILURE;
        
        write_stage <= write_stage+1;
        
        -- stage 1
        wait until read_stage=2;
        
        write_stage <= write_stage+1;
        
        -- stage 2
        
        write_bytes(din_counter, DEPTH, false);
        wait until rising_edge(WR_CLK);
        assert FULL='1'
            report "FIFO unexpectedly not full!"
            severity FAILURE;
        write_bytes(din_counter, DEPTH, true);
        
        write_stage <= write_stage+1;
        
        wait;
    end process;
    
end behavioral;

