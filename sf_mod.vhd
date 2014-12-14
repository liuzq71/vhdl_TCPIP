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
           SF_WR_BAR_OUT 		: out  STD_LOGIC;
           SF_RESET_BAR_OUT 	: out  STD_LOGIC;
           SF_STATUS_IN 		: in   STD_LOGIC);
end sf_mod;

architecture Behavioral of sf_mod is

-- To check veracity of Flash Memory
constant C_start_ID			: std_logic_vector(15 downto 0) := X"7B25";
constant C_end_ID				: std_logic_vector(15 downto 0) := X"ED4A";

-- Addresses in Strata Flash
constant C_start_ID_addr 	: std_logic_vector(23 downto 0) := X"000000";
constant C_end_ID_addr 		: std_logic_vector(23 downto 0) := X"00003F";

signal sf_cs 	: std_logic := '0';
signal sf_addr : std_logic_vector(23 downto 0);
signal sf_data : std_logic_vector(15 downto 0);

signal start_ID_read, end_ID_read : std_logic_vector(15 downto 0) := (others => '0');
signal start_id_correct, end_id_correct : std_logic := '0';

signal init_cmplt, init_error, init_succeeded : std_logic := '0';

type SF_ST is (	IDLE,
						READ_VERACITY_REGS0,
						READ_VERACITY_REGS1,
						READ_VERACITY_REGS2,
						READ_VERACITY_REGS3,
						READ_VERACITY_REGS4,
						READ_VERACITY_REGS5,
						READ_VERACITY_REGS6,
						CHECK_SF_VERACITY0,
						CHECK_SF_VERACITY1,
						HANDLE_FLASH_RD0,
						HANDLE_FLASH_RD1,
						HANDLE_FLASH_RD2,
						HANDLE_FLASH_RD3,
						ERROR_REPORT_STATE,
						INIT_CMPLT_ST);

signal sf_state, sf_next_state : SF_ST := IDLE;

begin

	SF_RESET_BAR_OUT <= '1';
	SF_WR_BAR_OUT <= '1';
	SF_CS_BAR_OUT <= not(sf_cs);
	SF_OE_BAR_OUT <= not(sf_cs);
	SF_ADDR_OUT(23 downto 1) <= sf_addr(22 downto 0);
	sf_data <= SF_DATA_IN;
	
	ERROR_OUT <= init_error;
	INIT_CMPLT_OUT <= init_cmplt;
	
   CS_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = READ_VERACITY_REGS0 then
				sf_cs <= '1';
			elsif sf_state = READ_VERACITY_REGS6 then
				sf_cs <= '0';
			elsif sf_state = HANDLE_FLASH_RD0 then
				sf_cs <= '1';
			elsif sf_state = HANDLE_FLASH_RD3 then
				sf_cs <= '0';
			end if;
		end if;
   end process;
	
   ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = READ_VERACITY_REGS0 then
				sf_addr <= C_start_ID_addr;
			elsif sf_state = READ_VERACITY_REGS3 then
				sf_addr <= C_end_ID_addr;
			elsif sf_state = HANDLE_FLASH_RD0 then
				sf_addr <= '0' & ADDR_IN;
			end if;
		end if;
   end process;
	
   DATA_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = HANDLE_FLASH_RD3 then
				DATA_OUT <= sf_data;
			end if;
			if sf_state = HANDLE_FLASH_RD3 then
				RD_CMPLT_OUT <= '1';
			else
				RD_CMPLT_OUT <= '0';
			end if;
		end if;
   end process;

   ID_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = READ_VERACITY_REGS3 then
				start_ID_read <= sf_data;
			elsif sf_state = READ_VERACITY_REGS6 then
				end_ID_read <= sf_data;
			end if;
		end if;
   end process;
	
   ID_VERACITY_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = CHECK_SF_VERACITY0 then
				if start_ID_read = C_start_ID then
					start_id_correct <= '1';
				else
					start_id_correct <= '0';
				end if;
			end if;
			if sf_state = CHECK_SF_VERACITY0 then
				if end_ID_read = C_end_ID then
					end_id_correct <= '1';
				else
					end_id_correct <= '0';
				end if;
			end if;
		end if;
   end process;

	---- HANDLE COMMANDS ----

   SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			sf_state <= sf_next_state;
      end if;
   end process;

	NEXT_STATE_DECODE: process (sf_state, INIT_IN, RD_IN, init_succeeded, start_id_correct, end_id_correct)
   begin
      sf_next_state <= sf_state;  --default is to stay in current state
      case (sf_state) is
         when IDLE =>
				if INIT_IN = '1' then
					sf_next_state <= READ_VERACITY_REGS0;
				elsif RD_IN = '1' and init_succeeded = '1' then
					sf_next_state <= HANDLE_FLASH_RD0;
				end if;
			when READ_VERACITY_REGS0 =>
				sf_next_state <= READ_VERACITY_REGS1;
			when READ_VERACITY_REGS1 =>
				sf_next_state <= READ_VERACITY_REGS2;
			when READ_VERACITY_REGS2 =>
				sf_next_state <= READ_VERACITY_REGS3;
			when READ_VERACITY_REGS3 =>
				sf_next_state <= READ_VERACITY_REGS4;
			when READ_VERACITY_REGS4 =>
				sf_next_state <= READ_VERACITY_REGS5;
			when READ_VERACITY_REGS5 =>
				sf_next_state <= READ_VERACITY_REGS6;
			when READ_VERACITY_REGS6 =>
				sf_next_state <= CHECK_SF_VERACITY0;
			when CHECK_SF_VERACITY0 =>
				sf_next_state <= CHECK_SF_VERACITY1;
			when CHECK_SF_VERACITY1 =>
				if start_id_correct = '1' and end_id_correct = '1' then
					sf_next_state <= INIT_CMPLT_ST;
				else
					sf_next_state <= ERROR_REPORT_STATE;
				end if;
			when ERROR_REPORT_STATE =>
				sf_next_state <= IDLE;
			when INIT_CMPLT_ST =>
				sf_next_state <= IDLE;
			when HANDLE_FLASH_RD0 =>
				sf_next_state <= HANDLE_FLASH_RD1;
			when HANDLE_FLASH_RD1 =>
				sf_next_state <= HANDLE_FLASH_RD2;
			when HANDLE_FLASH_RD2 =>
				sf_next_state <= HANDLE_FLASH_RD3;
			when HANDLE_FLASH_RD3 =>
				sf_next_state <= IDLE;
		end case;
	end process;
	
	INIT_CMPLT_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = INIT_CMPLT_ST or sf_state = ERROR_REPORT_STATE then
				init_cmplt <= '1';
--			else
--				init_cmplt <= '0';
			end if;
			if init_cmplt = '1' and start_id_correct = '1' and end_id_correct = '1' then
				init_succeeded <= '1';
			end if;
      end if;
   end process;
	
	ERROR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if sf_state = ERROR_REPORT_STATE then
				init_error <= '1';
			elsif sf_state = READ_VERACITY_REGS0 then
				init_error <= '0';
			end if;
      end if;
   end process;
	
end Behavioral;

