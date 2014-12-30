----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:51:09 12/30/2014 
-- Design Name: 
-- Module Name:    checksum_calc - Behavioral 
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

entity checksum_calc is
    Port ( CLK_IN 				: in  STD_LOGIC;
           RST_IN 				: in  STD_LOGIC;
           CHECKSUM_CALC_IN 	: in  STD_LOGIC;
           START_ADDR_IN 		: in  STD_LOGIC_VECTOR (10 downto 0);
           COUNT_IN 				: in  STD_LOGIC_VECTOR (10 downto 0);
           VALUE_IN 				: in  STD_LOGIC_VECTOR (7 downto 0);
           VALUE_ADDR_OUT 		: out  STD_LOGIC_VECTOR (10 downto 0);
           CHECKSUM_OUT 		: out STD_LOGIC_VECTOR (15 downto 0);
           CHECKSUM_DONE_OUT 	: out STD_LOGIC);
end checksum_calc;

architecture Behavioral of checksum_calc is

type CC_ST is (	IDLE,
						LOAD_START_ADDR,
						INC_ADDR0,
						INC_ADDR1,
						LOAD_VALUE_LSB,
						ADD_VALUE,
						CHECK_COUNT,
						ADD_REMAINDER,
						ONES_COMPLEMENT,
						COMPLETE
						);

signal cc_state, cc_next_state : CC_ST := IDLE;

signal rd_addr 								: unsigned(10 downto 0);
signal value 									: unsigned(15 downto 0);
signal checksum_reg, checksum_reg_inv 	: unsigned(24 downto 0);
signal count 									: unsigned(10 downto 0);

begin

	VALUE_ADDR_OUT <= std_logic_vector(rd_addr);
	CHECKSUM_OUT <= std_logic_vector(checksum_reg_inv(15 downto 0));
	CHECKSUM_DONE_OUT <= '1' when cc_state = COMPLETE else '0';

	SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			cc_state <= cc_next_state;
      end if;
   end process;

	NEXT_STATE_DECODE: process (cc_state, CHECKSUM_CALC_IN, count)
   begin
      cc_next_state <= cc_state;  --default is to stay in current state
      case (cc_state) is
         when IDLE =>
				if CHECKSUM_CALC_IN = '1' then
					cc_next_state <= LOAD_START_ADDR;
				end if;
			when LOAD_START_ADDR =>
				cc_next_state <= INC_ADDR0;
			when INC_ADDR0 =>
				cc_next_state <= INC_ADDR1;			
			when INC_ADDR1 =>
				cc_next_state <= LOAD_VALUE_LSB;
			when LOAD_VALUE_LSB =>
				cc_next_state <= ADD_VALUE;
			when ADD_VALUE =>
				cc_next_state <= CHECK_COUNT;
			when CHECK_COUNT =>
				if count = "00000000000" then
					cc_next_state <= ADD_REMAINDER;
				else
					cc_next_state <= INC_ADDR0;
				end if;
			
			when ADD_REMAINDER =>
				cc_next_state <= ONES_COMPLEMENT;
			when ONES_COMPLEMENT =>
				cc_next_state <= COMPLETE;
			
			when COMPLETE =>
				cc_next_state <= IDLE;
			
		end case;
	end process;
	
	RD_ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if cc_state = LOAD_START_ADDR then
				rd_addr <= unsigned(START_ADDR_IN);
			elsif cc_state = INC_ADDR0 then
				rd_addr <= rd_addr + 1;
			elsif cc_state = INC_ADDR1 then
				rd_addr <= rd_addr + 1;
			end if;
      end if;
   end process;
	
	LOAD_VALUE_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if cc_state = INC_ADDR1 then
				value(15 downto 8) <= unsigned(VALUE_IN);
			end if;
			if cc_state = LOAD_VALUE_LSB then
				value(7 downto 0) <= unsigned(VALUE_IN);
			end if;
      end if;
   end process;
	
	ADD_VALUE_TO_CHECKSUM: process(CLK_IN)
	begin
      if rising_edge(CLK_IN) then
			if cc_state = IDLE then
				checksum_reg <= (others => '0');
			elsif cc_state = ADD_VALUE then
				checksum_reg <= checksum_reg + unsigned(X"00" & value);
			elsif cc_state = ADD_REMAINDER then
				checksum_reg <= checksum_reg + unsigned(X"0000" & checksum_reg(24 downto 16));
			end if;
			if cc_state = ONES_COMPLEMENT then
				checksum_reg_inv <= not(checksum_reg);
			end if;
		end if;
	end process;
	
	COUNT_PROC: process(CLK_IN)
	begin
      if rising_edge(CLK_IN) then
			if cc_state = IDLE and CHECKSUM_CALC_IN = '1' then
				count <= unsigned(COUNT_IN);
			elsif cc_state = ADD_VALUE then
				count <= count - 1;
			end if;
		end if;
	end process;
	
end Behavioral;

