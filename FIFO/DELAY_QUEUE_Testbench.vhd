
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.help_funcs.all;
 
ENTITY DELAY_QUEUE_Testbench IS
    generic (
        WIDTH   : natural := 8;
        CYCLES  : natural := 50
    );
END DELAY_QUEUE_Testbench;
 
ARCHITECTURE behavior OF DELAY_QUEUE_Testbench IS 
    
    --Inputs
    signal CLK  : std_ulogic := '0';
    signal RST  : std_ulogic := '0';
    
    signal DIN  : std_ulogic_vector(7 downto 0) := (others => '0');
    
    --Outputs
    signal DOUT : std_ulogic_vector(7 downto 0);
    
    -- Clock period definitions
    constant CLK_period : time := 10 ns;
    
BEGIN

    DELAY_QUEUE_INST : entity work.DELAY_QUEUE
        generic map (
            WIDTH   => WIDTH,
            CYCLES  => CYCLES
        )
        port map
        (
            CLK => CLK,
            RST => RST,
            
            DIN => DIN,
            
            DOUT    => DOUT
        );

    CLK <= not CLK after CLK_period/2;


    -- Stimulus process
    stim_proc: process
    begin		
        -- hold reset state for 100 ns.
        RST <= '1';
        wait for 100 ns;	
        RSt <= '0';
        wait for CLK_period*10;
        wait until rising_edge(CLK);
        
        -- insert stimulus here

        for i in 0 to 200 loop
            
            DIN <= stdulv(i, WIDTH);
            wait until rising_edge(CLK);
            
        end loop;
        
        wait for CLK_period*100;
        
        report "NONE. All tests completed successfully."
            severity failure;
    end process;

END;
