
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY DELAY_QUEUE_Testbench IS
END DELAY_QUEUE_Testbench;
 
ARCHITECTURE behavior OF DELAY_QUEUE_Testbench IS 
  
  --Inputs
   signal CLK : std_logic := '0';
   signal DATA_IN : std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal DATA_OUT : std_logic_vector(7 downto 0);

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
        
   DELAY_QUEUE_BRAM_INST : entity work.DELAY_QUEUE
    PORT MAP (
          CLK => CLK,
          DATA_IN => DATA_IN,
          DATA_OUT => DATA_OUT
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for CLK_period*10;

      -- insert stimulus here
      
      for i in 0 to 200 loop
        
        DATA_IN <= std_logic_vector(to_unsigned(i, DATA_IN'length));
        wait until rising_edge(CLK);
        
      end loop;
      
      wait for CLK_period*50;
      
      assert false severity failure;

      wait;
   end process;

END;
