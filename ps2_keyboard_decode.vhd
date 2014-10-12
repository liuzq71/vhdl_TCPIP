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

	COMPONENT ps2_to_ascii
	PORT (
		 clka 	: IN STD_LOGIC;
		 wea 		: IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra 	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 dina 	: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 douta 	: OUT STD_LOGIC_VECTOR(7 DOWNTO 0));
	END COMPONENT;

constant C_shift_key_left	: std_logic_vector(7 downto 0) := X"12";
constant C_shift_key_right	: std_logic_vector(7 downto 0) := X"59";
constant C_caps_lock_key 	: std_logic_vector(7 downto 0) := X"58";

signal key_released, handle_keycode, shift_pressed, handle_keypressed : std_logic := '0';
signal keycode_cache, ps2toascii_addr, ascii_key : std_logic_vector(7 downto 0);

begin

	ASCII_KEY_OUT <= ascii_key;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if KEY_WR_IN = '1' then
				keycode_cache <= KEYCODE_IN;
				if KEYCODE_IN /= X"E0" then
					handle_keycode <= '1';
				end if;
			else
				handle_keycode <= '0';
			end if;
		end if;
	end process;

	ps2toascii_addr <= shift_pressed & keycode_cache(6 downto 0);

	ps2_to_ascii_inst : ps2_to_ascii
	PORT MAP (
		 clka 	=> CLK_IN,
		 wea 		=> "0",
		 addra 	=> ps2toascii_addr,
		 dina 	=> (others => '0'),
		 douta 	=> ascii_key);

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if handle_keycode = '1' then
				if KEYCODE_IN = X"F0" then
					key_released <= '1';
				else
					key_released <= '0';
				end if;
			end if;
			if handle_keycode = '1' and KEYCODE_IN /= X"F0" then
				if key_released = '1' then
					if keycode_cache = C_shift_key_left or keycode_cache = C_shift_key_right then
						shift_pressed <= '0';
					end if;
				else
					if keycode_cache = C_shift_key_left or keycode_cache = C_shift_key_right then
						shift_pressed <= '1';
					else
						handle_keypressed <= '1';
					end if;
				end if;
			else
				handle_keypressed <= '0';
			end if;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if handle_keypressed = '1' and ascii_key /= X"00" then
				ACII_KEY_WR_OUT <= '1';
			else
				ACII_KEY_WR_OUT <= '0';
			end if;
		end if;
	end process;
	
end Behavioral;

