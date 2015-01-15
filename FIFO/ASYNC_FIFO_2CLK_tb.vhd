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
    
    signal read_counter     : natural := 0;
    signal write_counter    : natural := 0;
    signal din_counter      : unsigned(WIDTH-1 downto 0) := (others => '0');
    signal dout_counter     : unsigned(WIDTH-1 downto 0) := (others => '0');
    
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
    
    RD_CLK  <= not RD_CLK after RD_CLK_PERIOD/2;
    WR_CLK  <= not WR_CLK after WR_CLK_PERIOD/2;
    
    stim_proc : process
    begin
        RST <= '1';
        wait for 100 ns;
        RST <= '0';
        wait for 100 ns;
        
        -- stage 0: start test processes
        
        start_read  <= true;
        start_write <= true;
        
        wait until read_stage=1 and write_stage=1;
        
        -- stage 1: fill the FIFO
        
        wait until read_stage=2 and write_stage=2;
        
        -- stage 2: empty the FIFO
        
        wait until read_stage=3 and write_stage=3;
        
        -- stage 3: write too much data to the FIFO
        
--        wait until read_stage=4 and write_stage=4;
        
        wait for 1 us;
        report "NONE. All tests completed."
            severity FAILURE;
    end process;
    
    read_proc : process(RD_CLK)
        procedure test_flags(
            constant expect_valid   : in boolean;
            constant expect_empty   : in boolean
        ) is
        begin
            if expect_empty then
                assert EMPTY='1'
                    report "FIFO unexpectedly not empty!"
                    severity FAILURE;
            else
                assert EMPTY='0'
                    report "FIFO unexpectedly empty!"
                    severity FAILURE;
            end if;
            if expect_valid then
                assert VALID='1'
                    report "Didn't get any data!"
                    severity FAILURE;
                assert DOUT=stdulv(dout_counter)
                    report "Got wrong data!"
                    severity FAILURE;
            else
                assert VALID='0'
                    report "Got unexpected data!"
                    severity FAILURE;
            end if;
        end procedure;
    begin
        if rising_edge(RD_CLK) then
            read_counter    <= 0;
            case read_stage is
                
                when 0 =>
                    if start_read then
                        read_stage  <= 1;
                    end if;
                
                when 1 =>
                    if write_stage=2 then
                        read_stage  <= 2;
                    end if;
                
                when 2 =>
                    read_counter    <= read_counter+1;
                    case read_counter is
                        when 0 =>
                            test_flags(false, false);
                            RD_EN   <= '1';
                        when 1 =>
                            test_flags(false, false);
                        when 32 =>
                            test_flags(true, false);
                            RD_EN   <= '0';
                        when 33 =>
                            test_flags(false, true);
                            read_stage  <= 3;
                        when others =>
                            test_flags(true, false);
                            RD_EN           <= '1';
                            dout_counter    <= dout_counter+1;
                    end case;
                
                when others =>
                    null;
                
            end case;
        end if;
    end process;
    
    write_proc : process(WR_CLK)
        procedure test_flags(
            constant expect_wr_ack  : in boolean;
            constant expect_full    : in boolean
        ) is
        begin
            if expect_full then
                assert FULL='1'
                    report "FIFO unexpectedly not full!"
                    severity FAILURE;
            else
                assert FULL='0'
                    report "FIFO unexpectedly full!"
                    severity FAILURE;
            end if;
            if expect_wr_ack then
                assert WR_ACK='1'
                    report "Could unexpectedly not write!"
                    severity FAILURE;
            else
                assert WR_ACK='0'
                    report "Could unexpectedly write!"
                    severity FAILURE;
            end if;
        end procedure;
    begin
        if rising_edge(WR_CLK) then
            write_counter   <= 0;
            case write_stage is
                
                when 0 =>
                    if start_write then
                        write_stage <= 1;
                    end if;
                
                when 1 =>
                    write_counter   <= write_counter+1;
                    case write_counter is
                        when 32 =>
                            test_flags(true, false);
                            WR_EN   <= '0';
                        when 33 =>
                            test_flags(true, true);
                        when 34 =>
                            test_flags(false, true);
                            write_stage <= 2;
                        when others =>
                            test_flags(write_counter>1, false);
                            WR_EN       <= '1';
                            din_counter <= din_counter+1;
                            DIN         <= stdulv(din_counter);
                    end case;
                
                when 2 =>
                    if read_stage=3 then
                        write_stage <= 3;
                    end if;
                
                when others =>
                    null;
                
            end case;
        end if;
    end process;
    
end behavior;

