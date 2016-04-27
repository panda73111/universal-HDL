--------------------------------------------------------------------------------
-- Engineer: Sebastian Huether
--
-- Create Date:   23:36:00 09/11/2014
-- Module Name:   SPI_FLASH_CONTROL_tb.vhd
-- Project Name:  SPI_FLASH_CONTROL
-- Tool versions: Xilinx ISE 14.7
-- Description:   
-- 
-- Additional Comments:
--  
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
use work.txt_util.all;
 
ENTITY SPI_FLASH_CONTROL_tb IS
END SPI_FLASH_CONTROL_tb;

ARCHITECTURE behavior OF SPI_FLASH_CONTROL_tb IS
    
    -- Inputs
    signal clk      : std_ulogic := '0';
    signal rst      : std_ulogic := '0';
    signal addr     : std_ulogic_vector(23 downto 0) := x"000000";
    signal din      : std_ulogic_vector(7 downto 0) := x"00";
    signal rd_en    : std_ulogic := '0';
    signal wr_en    : std_ulogic := '0';
    signal end_wr   : std_ulogic := '0';
    signal bulk     : std_ulogic := '0';
    signal miso     : std_ulogic := '0';
    
    -- Outputs
    signal dout    : std_ulogic_vector(7 downto 0);
    signal valid   : std_ulogic;
    signal wr_ack  : std_ulogic;
    signal busy    : std_ulogic;
    signal mosi    : std_ulogic;
    signal c       : std_ulogic;
    signal sn      : std_ulogic;
    
    -- clock period definitions
    constant clk_period         : time := 20 ns;
    constant clk_period_real    : real := real(clk_period / 1 ps) / real(1 ns / 1 ps);
    
    -- 4 Mbit
    type flash_mem_type is
        array(0 to 512*1024) of
        std_ulogic_vector(7 downto 0);
    signal flash_mem    : flash_mem_type  := (others => x"00");
    
BEGIN

    SPI_FLASH_CONTROL_inst : entity work.SPI_FLASH_CONTROL
        generic map (
            CLK_IN_PERIOD   => clk_period_real,
            CLK_OUT_MULT    => 2,
            CLK_OUT_DIV     => 5,
            BUFFER_SIZE     => 2048
        )
        port map (
            CLK => clk,
            RST => rst,
            
            ADDR    => addr,
            DIN     => din,
            RD_EN   => rd_en,
            WR_EN   => wr_en,
            END_WR  => end_wr,
            MISO    => miso,
            
            DOUT    => dout,
            VALID   => valid,
            WR_ACK  => wr_ack,
            BUSY    => busy,
            MOSI    => mosi,
            C       => c,
            SN      => sn
        );
    
    -- clock generation
    clk <= not clk after clk_period / 2;
    
    sn_deselect_time_check_proc : process
        variable sn_rising_time : time;
    begin
        wait until rising_edge(sn); sn_rising_time  := now;
        wait until falling_edge(sn);
        assert now-sn_rising_time>=100 ns
            report "Violation of S# deselect time"
            severity FAILURE;
    end process;
    
    sn_not_active_hold_timing_check_proc : process
        variable c_rising_time  : time;
    begin
        wait until rising_edge(c); c_rising_time    := now;
        wait until falling_edge(sn) or falling_edge(c);
        if falling_edge(sn) then
            assert now-c_rising_time>=10 ns
                report "Violation of S# not active hold time"
                severity FAILURE;
        end if;
    end process;
    
    sn_active_setup_time_check_proc : process
        variable sn_falling_time    : time;
    begin
        wait until falling_edge(sn); sn_falling_time    := now;
        wait until rising_edge(c) or rising_edge(sn);
        if rising_edge(c) then
            assert now-sn_falling_time>=10 ns
                report "Violation of S# active setup time"
                severity FAILURE;
        end if;
    end process;
    
    sn_active_hold_time_check_proc : process
        variable c_rising_time  : time;
    begin
        wait until rising_edge(c); c_rising_time    := now;
        wait until rising_edge(sn) or falling_edge(c);
        if rising_edge(sn) then
            assert now-c_rising_time>=10 ns
                report "Violation of S# active hold time"
                severity FAILURE;
        end if;
    end process;
    
    sn_not_active_setup_time_check_proc : process
        variable sn_rising_time : time;
    begin
        wait until rising_edge(sn); sn_rising_time  := now;
        wait until rising_edge(c) or falling_edge(sn);
        if rising_edge(c) then
            assert now-sn_rising_time>=10 ns
                report "Violation of S# not active setup time"
                severity FAILURE;
        end if;
    end process;
    
    data_in_setup_time_check_proc : process
        variable mosi_change_time    : time;
    begin
        wait until mosi'event; mosi_change_time := now;
        wait until rising_edge(c);
        assert now-mosi_change_time>=5 ns
            report "Violation of Data in setup time"
            severity FAILURE;
    end process;
    
    data_in_hold_time_check_proc : process
        variable c_rising_time  : time;
    begin
        wait until rising_edge(c); c_rising_time    := now;
        wait until mosi'event or falling_edge(c);
        if mosi'event then
            assert now-c_rising_time>=5 ns
                report "Violation of Data in hold time"
                severity FAILURE;
        end if;
    end process;
    
    spi_flash_sim_proc : process
        subtype cmd_type is std_ulogic_vector(7 downto 0);
        constant CMD_WRITE_ENABLE           : cmd_type := x"06";
        constant CMD_SECTOR_ERASE           : cmd_type := x"D8";
        constant CMD_READ_DATA_BYTES        : cmd_type := x"03";
        constant CMD_PAGE_PROGRAM           : cmd_type := x"02";
        constant CMD_READ_STATUS_REGISTER   : cmd_type := x"05";
        variable flash_cmd          : cmd_type;
        variable flash_addr         : std_ulogic_vector(23 downto 0);
        variable flash_data_byte    : std_ulogic_vector(7 downto 0);
        variable flash_status       : std_ulogic_vector(7 downto 0);
        variable erasing            : boolean;
        variable erase_start_time   : time;
        variable programming        : boolean;
        variable program_start_time : time;
        
        procedure get_cmd is
        begin
            bit_loop : for i in 7 downto 1 loop
                flash_cmd(i)    := mosi;
                wait until rising_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
            end loop;
            flash_cmd(0)    := mosi;
        end procedure;
        
        procedure get_addr is
        begin
            bit_loop : for i in 23 downto 1 loop
                flash_addr(i)   := mosi;
                wait until rising_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
            end loop;
            flash_addr(0)   := mosi;
        end procedure;
        
        procedure get_data_byte is
        begin
            bit_loop : for i in 7 downto 1 loop
                flash_data_byte(i)  := mosi;
                wait until rising_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
            end loop;
            flash_data_byte(0)  := mosi;
        end procedure;
        
        procedure send_status is
        begin
            bit_loop : for i in 7 downto 1 loop
                wait until falling_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
                miso    <= flash_status(i);
                wait until rising_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
            end loop;
            if sn='0' then
                wait until falling_edge(c) or sn='1';
                miso    <= flash_status(0);
            end if;
        end procedure;
        
        procedure send_data_byte is
        begin
            bit_loop : for i in 7 downto 1 loop
                wait until falling_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
                miso    <= flash_mem(int(flash_addr))(i);
                wait until rising_edge(c) or sn='1';
                if sn='1' then exit bit_loop; end if;
            end loop;
            if sn='0' then
                wait until falling_edge(c) or sn='1';
                miso    <= flash_mem(int(flash_addr))(0);
            end if;
        end procedure;
    begin
        flash_status    := x"00";
        main_loop : loop
            wait until rising_edge(c);
            
            if erasing and now-erase_start_time>=2 ms then
                -- more realistic erase time: 800 ms. Nobody got time for that...
                erasing         := false;
                flash_status(1) := '0'; -- WEN
                flash_status(0) := '0'; -- WIP
            end if;
            
            if programming and now-program_start_time>=800 us then
                programming     := false;
                flash_status(1) := '0'; -- WEN
                flash_status(0) := '0'; -- WIP
            end if;
            
            if sn='0' then
                
                get_cmd;
                report "Got command: 0x" & hstr(flash_cmd);
                
                case flash_cmd is
                    
                    when CMD_WRITE_ENABLE =>
                        wait until rising_edge(c) or sn='1';
                        if sn='1' then
                            if flash_status(0)='0' then
                                report "Setting WRITE ENABLE bit";
                                flash_status(1) := '1';
                            end if;
                        else
                            wait until sn='1';
                        end if;
                        next main_loop;
                    
                    when CMD_READ_STATUS_REGISTER =>
                        while sn='0' loop
                            report "Sending status";
                            send_status;
                            if sn='0' then
                                wait until rising_edge(c) or sn='1';
                            end if;
                        end loop;
                        next main_loop;
                    
                    when others =>
                        if
                            flash_cmd/=CMD_READ_DATA_BYTES and
                            flash_cmd/=CMD_SECTOR_ERASE and
                            flash_cmd/=CMD_PAGE_PROGRAM
                        then
                            report "Unknown command: " & hstr(flash_cmd);
                            if sn='0' then wait until sn='1'; end if;
                            next main_loop;
                        end if;
                    
                end case;
                
                wait until rising_edge(c) or sn='1';
                if sn='1' then next main_loop; end if;
                get_addr;
                report "Got address: 0x" & hstr(flash_addr, false);
                
                case flash_cmd is
                    
                    when CMD_READ_DATA_BYTES =>
                        if flash_status(0)='0' then
                            while sn='0' loop
                                report "Reading byte: 0x" & hstr(flash_mem(int(flash_addr))) & " at 0x" & hstr(flash_addr, false);
                                send_data_byte;
                                flash_addr  := flash_addr+1;
                                if sn='0' then
                                    wait until rising_edge(c) or sn='1';
                                end if;
                            end loop;
                        else
                            if sn='0' then wait until sn='1'; end if;
                        end if;
                        next main_loop;
                    
                    when CMD_SECTOR_ERASE =>
                        wait until rising_edge(c) or sn='1';
                        if sn='1' then
                            if flash_status(1 downto 0)="10" then
                                report "Erasing sector: 0x" & hstr(flash_addr(23 downto 16) & x"0000", false);
                            end if;
                            flash_status(1) := '0';
                        else
                            wait until sn='1';
                            report "Sector erase command not correctly finished!"
                                severity WARNING;
                            next main_loop;
                        end if;
                        erasing             := true;
                        erase_start_time    := now;
                        flash_status(0)     := '1';
                        next main_loop;
                    
                    when CMD_PAGE_PROGRAM =>
                        wait until rising_edge(c) or sn='1';
                        if sn='1' then next main_loop; end if;
                        while sn='0' loop
                            get_data_byte;
                            if sn='1' then
                                report "Program command not correctly finished!"
                                    severity WARNING;
                                next main_loop;
                            end if;
                            if flash_status(1 downto 0)="10" then
                                report "Writing byte: 0x" & hstr(flash_data_byte) & " at 0x" & hstr(flash_addr, false);
                                flash_mem(int(flash_addr))  <= flash_data_byte;
                                flash_addr(7 downto 0)      := flash_addr(7 downto 0)+1;
                            end if;
                            wait until rising_edge(c) or sn='1';
                        end loop;
                        flash_status(1)     := '0';
                        programming         := true;
                        program_start_time  := now;
                        flash_status(0)     := '1';
                        next main_loop;
                    
                    when others =>
                        null;
                    
                end case;
                
            end if;
        end loop;
    end process;
    
    -- Stimulus process
    stim_proc: process
        variable flash_addr : std_ulogic_vector(23 downto 0);
    begin
        -- hold reset state for 100 ns.
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for clk_period*10;
        wait until rising_edge(clk);
        
        -- insert stimulus here
        
        wait until rising_edge(clk) and busy='0';
        
        -- write one byte 0x77 at address 0xABCD
        flash_addr  := x"00ABCD";
        report "Starting test 1";
        wait until rising_edge(clk);
        addr    <= flash_addr;
        din     <= x"77";
        wr_en   <= '1';
        wait until rising_edge(clk);
        wr_en   <= '0';
        wait until rising_edge(clk);
        
        end_wr  <= '1';
        wait until falling_edge(busy);
        end_wr  <= '0';
        wait for 10 us;
        
        -- read one byte at address 0xABCD
        flash_addr  := x"00ABCD";
        report "---------------";
        report "Starting test 2";
        wait until rising_edge(clk);
        addr    <= flash_addr;
        rd_en   <= '1';
        while valid='0' loop
            wait until rising_edge(clk);
        end loop;
        assert dout=flash_mem(int(flash_addr))
            report "Got wrong data!"
            severity FAILURE;
        rd_en   <= '0';
        wait until rising_edge(clk);
        
        wait until falling_edge(busy);
        wait for 10 us;
        
        -- write 1024 bytes (8 bit counter) at address 0x60000
        flash_addr  := x"060000";
        report "---------------";
        report "Starting test 3";
        wait until rising_edge(clk);
        addr    <= flash_addr;
        wr_en   <= '1';
        for i in 0 to 1023 loop
            din <= stdulv(i mod 256, 8);
            wait until rising_edge(clk);
        end loop;
        wr_en   <= '0';
        wait until rising_edge(clk);
        
        end_wr  <= '1';
        wait until falling_edge(busy);
        end_wr  <= '0';
        wait for 10 us;
        
        -- read 1024 bytes at address 0x060000
        flash_addr  := x"060000";
        report "---------------";
        report "Starting test 4";
        wait until rising_edge(clk);
        addr    <= flash_addr;
        rd_en   <= '1';
        for i in 0 to 1023 loop
            wait until rising_edge(clk);
            while valid='0' loop
                wait until rising_edge(clk);
            end loop;
            assert dout=flash_mem(int(flash_addr)+i)
                report "Got wrong data at 0x" & hstr(flash_addr+i, false) &
                        ": expected 0x" & hstr(flash_mem(int(flash_addr)+i)) &
                        ", got 0x" & hstr(dout) & "!"
                severity FAILURE;
        end loop;
        rd_en   <= '0';
        wait until rising_edge(clk);
        
        wait until falling_edge(busy);
        wait for 10 us;
        
        -- write 2048 bytes (8 bit counter) at address 0x5FC00, across sector border at 0x60000
        flash_addr  := x"05FC00";
        report "---------------";
        report "Starting test 5";
        wait until rising_edge(clk);
        addr    <= flash_addr;
        wr_en   <= '1';
        for i in 0 to 2048 loop
            din <= stdulv(i mod 256, 8);
            wait until rising_edge(clk);
        end loop;
        wr_en   <= '0';
        wait until rising_edge(clk);
        
        end_wr  <= '1';
        wait until falling_edge(busy);
        end_wr  <= '0';
        wait for 10 us;
        
        -- write 2048 bytes (8 bit counter) at address 0x5FC00, with buffer underrun
        flash_addr  := x"05FC00";
        report "---------------";
        report "Starting test 5";
        wait until rising_edge(clk);
        addr    <= flash_addr;
        wr_en   <= '1';
        for i in 1 to 2048 loop
            din <= stdulv(i mod 256, 8);
            wait until rising_edge(clk);
            
            if i=888 or i=1234 then
                -- wait until the write buffer is empty
                wr_en   <= '0';
                wait for 10 ms;
                wait until rising_edge(clk);
                wr_en   <= '1';
            end if;
        end loop;
        wr_en   <= '0';
        wait until rising_edge(clk);
        
        end_wr  <= '1';
        wait until falling_edge(busy);
        end_wr  <= '0';
        wait for 10 us;
        report "NONE. All tests completed." severity failure;
    end process;
    
END;
