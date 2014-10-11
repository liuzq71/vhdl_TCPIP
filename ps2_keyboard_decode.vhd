----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:23:48 10/11/2014 
-- Design Name: 
-- Module Name:    ps2_keyboard_decode - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ps2_keyboard_decode is
    Port ( CLK_IN 			: in  STD_LOGIC;
           KEYCODE_IN 		: in  STD_LOGIC_VECTOR (7 downto 0);
           KEY_WR_IN 		: in  STD_LOGIC;
           ASCII_KEY_OUT 	: out  STD_LOGIC_VECTOR (7 downto 0);
           ACII_KEY_WR_OUT : out  STD_LOGIC);
end ps2_keyboard_decode;

architecture Behavioral of ps2_keyboard_decode is

signal ignore_next_key, handle_keycode : std_logic := '0';
signal keycode_cache : std_logic_vector(7 downto 0);

begin

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if KEY_WR_IN = '1' then
				if KEYCODE_IN = X"F0" then
					ignore_next_key <= '1';
				else
					ignore_next_key <= '0';
				end if;
			end if;
			if KEY_WR_IN = '1' then
				keycode_cache <= KEYCODE_IN;
				if ignore_next_key = '0' and KEYCODE_IN /= X"F0" then
					handle_keycode <= '1';
				end if;
			else
				handle_keycode <= '0';
			end if;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			ASCII_KEY_OUT <= keycode_cache;
			if handle_keycode = '1' then
				ACII_KEY_WR_OUT <= '1';
			else
				ACII_KEY_WR_OUT <= '0';
			end if;
		end if;
	end process;
	
end Behavioral;

