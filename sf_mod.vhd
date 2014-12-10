----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:58:34 12/10/2014 
-- Design Name: 
-- Module Name:    sf_mod - Behavioral 
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

entity sf_mod is
    Port ( CLK_IN 				: in  STD_LOGIC;
           RESET_IN 				: in  STD_LOGIC;
			  
			  -- Command interface
           INIT_IN 				: in  STD_LOGIC;
           INIT_CMPLT_OUT		: out STD_LOGIC;
			  ERROR_OUT				: out STD_LOGIC;
			  
			  -- Ethernet command interface
			  ADDR_IN				: in 	STD_LOGIC_VECTOR (23 downto 1);
			  DATA_OUT 				: out STD_LOGIC_VECTOR (15 downto 0);
			  RD_IN					: in  STD_LOGIC;
			  RD_CMPLT_OUT			: out STD_LOGIC;
			  
			  -- Flash interface
           SF_DATA_IN 			: in   STD_LOGIC_VECTOR (15 downto 0);
           SF_ADDR_OUT 			: out  STD_LOGIC_VECTOR (23 downto 1);
           SF_CS_BAR_OUT 		: out  STD_LOGIC;
           SF_OE_BAR_OUT 		: out  STD_LOGIC;
           SF_RESET_BAR_OUT 	: out  STD_LOGIC;
           SF_STATUS_IN 		: in   STD_LOGIC);
end sf_mod;

architecture Behavioral of sf_mod is

begin


end Behavioral;

