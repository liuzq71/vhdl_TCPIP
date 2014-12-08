----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:48:34 12/08/2014 
-- Design Name: 
-- Module Name:    led_mod - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_mod is
    Port ( CLK_IN 				: in  STD_LOGIC;
           LED_0_STATE_IN 		: in  STD_LOGIC_VECTOR (2 downto 0);
           LED_1_STATE_IN 		: in  STD_LOGIC_VECTOR (2 downto 0);
			  ERROR_CODE_IN		: in	STD_LOGIC_VECTOR (4 downto 0);
			  ERROR_CODE_EN_IN	: in	STD_LOGIC;
           LEDS_OUT 				: out  STD_LOGIC_VECTOR (1 downto 0));
end led_mod;

architecture Behavioral of led_mod is

subtype slv is std_logic_vector;

constant C_clk_div_1sec 		: std_logic_vector(27 downto 0) := X"17D7840";
constant C_clk_div_1sec_test	: std_logic_vector(27 downto 0) := X"0000007";

-- Shared state info
constant C_off_state 			: std_logic_vector(2 downto 0) := "000";
constant C_error_state 			: std_logic_vector(2 downto 0) := "111";

-- LED 0 only state info
constant C_heardbeat_state 	: std_logic_vector(2 downto 0) := "001";

-- LED 1 only state info
constant C_initializing_state : std_logic_vector(2 downto 0) := "001";
constant C_init_cmplt_state 	: std_logic_vector(2 downto 0) := "010";

signal led0_state, led1_state : std_logic_vector(2 downto 0) := "000";
signal leds 						: std_logic_vector(1 downto 0) := "00";

signal clk_div_1sec_counter 				: unsigned(27 downto 0) := (others => '0');
signal clk_div_1sec_en, led_error_mask	: std_logic := '0';

signal error_code_buf0, error_code_buf1 : std_logic_vector(7 downto 0) := (others => '0');

begin

	LEDS_OUT <= leds;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if clk_div_1sec_counter = X"0000000" then
				clk_div_1sec_counter <= unsigned(C_clk_div_1sec);
			else
				clk_div_1sec_counter <= clk_div_1sec_counter - 1;
			end if;
			if clk_div_1sec_counter = X"0000000" then
				clk_div_1sec_en <= '1';
			else
				clk_div_1sec_en <= '0';
			end if;
			if clk_div_1sec_en = '1' then
				led_error_mask <= '1';
			elsif clk_div_1sec_counter = unsigned('0' & C_clk_div_1sec(27 downto 1)) then
				led_error_mask <= '0';
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			led0_state <= LED_0_STATE_IN;
			
			case(led0_state) is
				when C_off_state =>
					leds(0) <= '0';
				when C_error_state =>
					leds(0) <= error_code_buf0(7) and led_error_mask;
				
				when others =>
					leds(0) <= '0';
			end case;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			led1_state <= LED_1_STATE_IN;
			
			case(led1_state) is
				when C_off_state =>
					leds(1) <= '0';
				when C_error_state =>
					leds(1) <= error_code_buf1(7) and led_error_mask;
				
				when others =>
					leds(1) <= '0';
			end case;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if ERROR_CODE_EN_IN = '1' then
				error_code_buf0 <= "000" & ERROR_CODE_IN;
				error_code_buf1 <= "000" & not(ERROR_CODE_IN);
			elsif clk_div_1sec_en = '1' then
				if led0_state = C_error_state or led1_state = C_error_state then
					error_code_buf0(7 downto 1) <= error_code_buf0(6 downto 0);
					error_code_buf0(0) <= error_code_buf0(7);
					error_code_buf1(7 downto 1) <= error_code_buf1(6 downto 0);
					error_code_buf1(0) <= error_code_buf1(7);
				end if;
			end if;
		end if;
	end process;

end Behavioral;

