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
    signal COUNT    : std_ulogic_vector(log2(DEPTH) downto 0);
    
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
            DOUT    => DOUT,
            COUNT   => COUNT
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
        
        -- stage 1: fill the FIFO
        -- stage 2: empty the FIFO
        -- stage 3: single write
        -- stage 4: single read
        -- stage 5: fill half the capacity
        -- stage 6: empty the fifo
        -- stage 7: fill the fifo
        -- stage 8: empty the fifo
        
        for next_stage in 1 to 9 loop
            wait until read_stage=next_stage and write_stage=next_stage;
        end loop;
        
        wait for 1 us;
        report "NONE. All tests completed."
            severity FAILURE;
    end process;
    
    read_proc : process(RD_CLK)
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
                            RD_EN   <= '1';
                        when 32 =>
                            RD_EN   <= '0';
                        when others =>
                            assert read_counter<100
                                report "Read timeout!"
                                severity FAILURE;
                    end case;
                    if EMPTY='1' then
                        read_stage  <= 3;
                    end if;
                
                when 3 =>
                    if write_stage=4 then
                        read_stage  <= 4;
                    end if;
                
                when 4 =>
                    read_counter    <= read_counter+1;
                    case read_counter is
                        when 0 =>
                            RD_EN   <= '1';
                        when 1 =>
                            RD_EN   <= '0';
                        when others =>
                            assert read_counter<100
                                report "Read timeout!"
                                severity FAILURE;
                    end case;
                    if EMPTY='1' then
                        read_stage  <= 5;
                    end if;
                
                when 5 =>
                    if write_stage=6 then
                        read_stage  <= 6;
                    end if;
                
                when 6 =>
                    read_counter    <= read_counter+1;
                    case read_counter is
                        when 0 =>
                            RD_EN   <= '1';
                        when 16 =>
                            RD_EN   <= '0';
                        when others =>
                            assert read_counter<100
                                report "Read timeout!"
                                severity FAILURE;
                    end case;
                    if EMPTY='1' then
                        read_stage  <= 7;
                    end if;
                
                when 7 =>
                    if write_stage=8 then
                        read_stage  <= 8;
                    end if;
                
                when 8 =>
                    read_counter    <= read_counter+1;
                    case read_counter is
                        when 0 =>
                            RD_EN   <= '1';
                        when 32 =>
                            RD_EN   <= '0';
                        when others =>
                            assert read_counter<100
                                report "Read timeout!"
                                severity FAILURE;
                    end case;
                    if EMPTY='1' then
                        read_stage  <= 9;
                    end if;
                
                when others =>
                    null;
                
            end case;
            
            if VALID='1' then
                assert DOUT=stdulv(dout_counter)
                    report "Got wrong data!"
                    severity FAILURE;
                dout_counter    <= dout_counter+1;
            end if;
        end if;
    end process;
    
    write_proc : process(WR_CLK)
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
                    WR_EN           <= '0';
                    if write_counter<32 then
                        WR_EN       <= '1';
                        DIN         <= stdulv(din_counter);
                        din_counter <= din_counter+1;
                    end if;
                    if FULL='1' then
                        write_stage <= 2;
                    end if;
                
                when 2 =>
                    if read_stage=3 then
                        write_stage <= 3;
                    end if;
                
                when 3 =>
                    write_counter   <= write_counter+1;
                    WR_EN           <= '0';
                    if write_counter=0 then
                        WR_EN       <= '1';
                        DIN         <= stdulv(din_counter);
                        din_counter <= din_counter+1;
                    end if;
                    if EMPTY='0' then
                        write_stage <= 4;
                    end if;
                
                when 4 =>
                    if read_stage=5 then
                        write_stage <= 5;
                    end if;
                
                when 5 =>
                    write_counter   <= write_counter+1;
                    WR_EN           <= '0';
                    if write_counter<16 then
                        WR_EN       <= '1';
                        DIN         <= stdulv(din_counter);
                        din_counter <= din_counter+1;
                    else
                        write_stage     <= 6;
                    end if;
                
                when 6 =>
                    if read_stage=7 then
                        write_stage <= 7;
                    end if;
                
                when 7 =>
                    write_counter   <= write_counter+1;
                    WR_EN           <= '0';
                    if write_counter<32 then
                        WR_EN       <= '1';
                        DIN         <= stdulv(din_counter);
                        din_counter <= din_counter+1;
                    end if;
                    if FULL='1' then
                        write_stage <= 8;
                    end if;
                
                when 8 =>
                    if read_stage=9 then
                        write_stage <= 9;
                    end if;
                
                when others =>
                    null;
                
            end case;
        end if;
    end process;
    
end behavior;

