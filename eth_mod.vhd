----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:09:04 12/10/2014 
-- Design Name: 
-- Module Name:    eth_mod - Behavioral 
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

entity eth_mod is
    Port ( CLK_IN 	: in  STD_LOGIC;
           RESET_IN 	: in  STD_LOGIC;
			  
			  -- Command interface
           COMMAND_IN			: in  STD_LOGIC_VECTOR (7 downto 0);
			  COMMAND_EN_IN		: in 	STD_LOGIC;
           COMMAND_CMPLT_OUT 	: out STD_LOGIC;
           ERROR_OUT 			: out  STD_LOGIC_VECTOR (7 downto 0);
			  DEBUG_IN				: in 	STD_LOGIC;
			  DEBUG_OUT				: out  STD_LOGIC_VECTOR (7 downto 0);
			  
           -- Flash mod ctrl interface
			  FRAME_ADDR_OUT 				: out  STD_LOGIC_VECTOR (23 downto 1);
           FRAME_DATA_IN 				: in  STD_LOGIC_VECTOR (15 downto 0);
           FRAME_DATA_RD_OUT 			: out  STD_LOGIC;
           FRAME_DATA_RD_CMPLT_IN 	: in  STD_LOGIC;
           
			  -- Eth SPI interface
			  SDI_OUT 	: out  STD_LOGIC;
           SDO_IN 	: in  STD_LOGIC;
           SCLK_OUT 	: out  STD_LOGIC;
           CS_OUT 	: out  STD_LOGIC);
end eth_mod;

architecture Behavioral of eth_mod is

	COMPONENT spi_mod
		Port ( 	CLK_IN 				: in  STD_LOGIC;
					RST_IN 				: in  STD_LOGIC;
					
					WR_CONTINUOUS_IN 	: in  STD_LOGIC;
					WE_IN 				: in  STD_LOGIC;
					WR_ADDR_IN			: in 	STD_LOGIC_VECTOR (7 downto 0);
					WR_DATA_IN 			: in  STD_LOGIC_VECTOR (7 downto 0);
					WR_DATA_CMPLT_OUT	: out STD_LOGIC;
					
					RD_IN					: in	STD_LOGIC;
					RD_WIDTH_IN 		: in  STD_LOGIC;
					RD_ADDR_IN 			: in  STD_LOGIC_VECTOR (7 downto 0);
					RD_DATA_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
					RD_DATA_CMPLT_OUT	: out STD_LOGIC;
					
					SLOW_CS_EN_IN			  : in STD_LOGIC;
					OPER_CMPLT_POST_CS_OUT : out STD_LOGIC;
					
					SDI_OUT				: out STD_LOGIC;
					SDO_IN				: in 	STD_LOGIC;
					SCLK_OUT				: out STD_LOGIC;
					CS_OUT				: out STD_LOGIC);
	END COMPONENT;

subtype slv is std_logic_vector;

constant C_init_cmnds_start_addr : std_logic_vector(7 downto 0) := X"01";
constant C_init_cmnds_end_addr : std_logic_vector(7 downto 0) := X"0F";
constant C_phy_rd_delay_count : std_logic_vector(8 downto 0) := "1"&X"F4";

signal spi_we, spi_wr_continuous, spi_wr_cmplt : std_logic := '0';
signal spi_rd, spi_rd_width, spi_rd_cmplt, spi_oper_cmplt : std_logic := '0';
signal spi_wr_addr, spi_wr_data, spi_rd_addr, spi_data_rd : std_logic_vector(7 downto 0) := (others => '0');

signal frame_addr : std_logic_vector(22 downto 0);
signal frame_data : std_logic_vector(15 downto 0);
signal frame_data_rd, frame_rd_cmplt, slow_cs_en : std_logic := '0';

signal command_cmplt : std_logic := '0';
signal init_cmnd_addr : unsigned(7 downto 0);

signal enc28j60_version : std_logic_vector(7 downto 0) := (others => '0');
signal phy_rd_counter 	: unsigned(8 downto 0) := unsigned(C_phy_rd_delay_count);
signal phy_reg_lwr, phy_reg_upr	: std_logic_vector(7 downto 0) := (others => '0');
signal phy_rd_addr 		: std_logic_vector(7 downto 0) := (others => '0');

type ETH_ST is (	IDLE,
						PARSE_COMMAND,
						READ_VERSION0,
						READ_VERSION1,
						READ_VERSION2,
						READ_VERSION3,
						READ_VERSION4,
						READ_PHY_STAT,
						READ_DUPLEX_MODE,
						READ_PHY_REG0,
						READ_PHY_REG1,
						READ_PHY_REG2,
						READ_PHY_REG3,
						READ_PHY_REG4,
						READ_PHY_REG5,
						READ_PHY_REG6,
						READ_PHY_REG7,
						READ_PHY_REG8,
						READ_PHY_REG9,
						READ_PHY_REG10,
						READ_PHY_REG11,
						READ_PHY_REG12,
						READ_PHY_REG13,
						HANDLE_INIT_CMND0,
						HANDLE_INIT_CMND1,
						HANDLE_INIT_CMND2,
						HANDLE_INIT_CMND3,
						HANDLE_INIT_CMND4,
						HANDLE_INIT_CMND5);

signal eth_state, eth_next_state : ETH_ST := IDLE;
signal state_debug_sig : unsigned(7 downto 0);

begin

	--DEBUG_OUT <= slv(init_cmnd_addr);
	--DEBUG_OUT <= slv(state_debug_sig);
	--DEBUG_OUT <= enc28j60_version;
	DEBUG_OUT <= phy_reg_upr;
	
--	debug_state: process(CLK_IN)
--	begin
-- 		if rising_edge(CLK_IN) then
--			case (eth_state) is
--				when IDLE =>
--					state_debug_sig <= to_unsigned(0, 8);
--				when PARSE_COMMAND =>
--					state_debug_sig <= to_unsigned(1, 8);
--				when HANDLE_INIT_CMND0 =>
--					state_debug_sig <= to_unsigned(2, 8);
--				when HANDLE_INIT_CMND1 =>
--					state_debug_sig <= to_unsigned(3, 8);
--				when HANDLE_INIT_CMND2 =>
--					state_debug_sig <= to_unsigned(4, 8);
--				when HANDLE_INIT_CMND3 =>
--					state_debug_sig <= to_unsigned(5, 8);
--				when HANDLE_INIT_CMND4 =>
--					state_debug_sig <= to_unsigned(6, 8);
--				when HANDLE_INIT_CMND5 =>
--					state_debug_sig <= to_unsigned(7, 8);
--				when others =>
--					state_debug_sig <= to_unsigned(255, 8);
--			end case;
--		end if;
--	end process;

	COMMAND_CMPLT_OUT <= command_cmplt;
	
	FRAME_ADDR_OUT(23 downto 1) <= frame_addr(22 downto 0);
	frame_data <= FRAME_DATA_IN;
	FRAME_DATA_RD_OUT <= frame_data_rd;
	frame_rd_cmplt <= FRAME_DATA_RD_CMPLT_IN;

	---- HANDLE COMMANDS ----

   SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			eth_state <= eth_next_state;
      end if;
   end process;

	NEXT_STATE_DECODE: process (eth_state, COMMAND_IN, COMMAND_EN_IN, init_cmnd_addr, phy_rd_counter, DEBUG_IN, init_cmnd_addr)
   begin
      eth_next_state <= eth_state;  --default is to stay in current state
      case (eth_state) is
         when IDLE =>
				if COMMAND_EN_IN = '1' then
					eth_next_state <= PARSE_COMMAND;
				end if;
			when PARSE_COMMAND =>
				if COMMAND_IN = X"00" then
					eth_next_state <= READ_PHY_STAT;
				elsif COMMAND_IN = X"01" then
					eth_next_state <= READ_DUPLEX_MODE;
				elsif COMMAND_IN = X"02" then
					eth_next_state <= READ_VERSION0;
				elsif COMMAND_IN = X"03" then
					eth_next_state <= HANDLE_INIT_CMND0;
				else
					eth_next_state <= IDLE;
				end if;
			when HANDLE_INIT_CMND0 =>
				eth_next_state <= HANDLE_INIT_CMND1;
			when HANDLE_INIT_CMND1 =>
				eth_next_state <= HANDLE_INIT_CMND2;
			when HANDLE_INIT_CMND2 =>
				if frame_rd_cmplt = '1' then
					eth_next_state <= HANDLE_INIT_CMND3;
				end if;
			when HANDLE_INIT_CMND3 =>
				eth_next_state <= HANDLE_INIT_CMND4;
			when HANDLE_INIT_CMND4 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_INIT_CMND5;
				end if;
			when HANDLE_INIT_CMND5 =>
				if init_cmnd_addr > unsigned(C_init_cmnds_end_addr) then
					eth_next_state <= IDLE;
				else
					if DEBUG_IN = '1' then
						eth_next_state <= HANDLE_INIT_CMND1;
					end if;
				end if;
			when READ_VERSION0 =>
				eth_next_state <= READ_VERSION1;
			when READ_VERSION1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_VERSION2;
				end if;
			when READ_VERSION2 =>
				eth_next_state <= READ_VERSION3;
			when READ_VERSION3 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_VERSION4;
				end if;
			when READ_VERSION4 =>
				eth_next_state <= IDLE;
			when READ_PHY_STAT =>
				eth_next_state <= READ_PHY_REG0;
			when READ_DUPLEX_MODE =>
				eth_next_state <= READ_PHY_REG0;
			when READ_PHY_REG0 =>
				eth_next_state <= READ_PHY_REG1;
			when READ_PHY_REG1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_PHY_REG2;
				end if;
			when READ_PHY_REG2 =>
				eth_next_state <= READ_PHY_REG3;
			when READ_PHY_REG3 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_PHY_REG4;
				end if;
			when READ_PHY_REG4 =>
				eth_next_state <= READ_PHY_REG5;
			when READ_PHY_REG5 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_PHY_REG6;
				end if;
			when READ_PHY_REG6 =>
				if phy_rd_counter = "000000000" then
					eth_next_state <= READ_PHY_REG7;
				end if;
			when READ_PHY_REG7 =>
				eth_next_state <= READ_PHY_REG8;
			when READ_PHY_REG8 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_PHY_REG9;
				end if;
			when READ_PHY_REG9 =>
				eth_next_state <= READ_PHY_REG10;
			when READ_PHY_REG10 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_PHY_REG11;
				end if;
			when READ_PHY_REG11 =>
				eth_next_state <= READ_PHY_REG12;
			when READ_PHY_REG12 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= READ_PHY_REG13;
				end if;
			when READ_PHY_REG13 =>
				eth_next_state <= IDLE;
		end case;
	end process;
	
   INIT_ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND0 then
				init_cmnd_addr <= unsigned(C_init_cmnds_start_addr);
			elsif eth_state = HANDLE_INIT_CMND3 then
				init_cmnd_addr <= init_cmnd_addr + 1;
			end if;
      end if;
   end process;
	
   SLOW_CS_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND0 then
				slow_cs_en <= '1';
			elsif eth_state = READ_PHY_REG0 then
				slow_cs_en <= '1';
			elsif eth_state = IDLE then
				slow_cs_en <= '0';
			end if;
      end if;
   end process;
	
   FRAME_ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND1 then
				frame_addr <= "000000000000000" & slv(init_cmnd_addr);
			end if;
      end if;
   end process;

	FRAME_RD_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND1 then
				frame_data_rd <= '1';
			else
				frame_data_rd <= '0';
			end if;
      end if;
   end process;

	SPI_WR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND3 then
				spi_we <= '1';
			elsif eth_state = READ_VERSION0 then
				spi_we <= '1';
			elsif eth_state = READ_PHY_REG0 then
				spi_we <= '1';
			elsif eth_state = READ_PHY_REG2 then
				spi_we <= '1';
			elsif eth_state = READ_PHY_REG4 then
				spi_we <= '1';
			elsif eth_state = READ_PHY_REG7 then
				spi_we <= '1';
			else
				spi_we <= '0';
			end if;
      end if;
   end process;
	
	PHY_ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = READ_PHY_STAT then
				phy_rd_addr <= X"01";
			elsif eth_state = READ_DUPLEX_MODE then
				phy_rd_addr <= X"00";
			end if;
		end if;
	end process;
	
	SPI_ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND3 then
				spi_wr_addr <= frame_data(15 downto 8);
			elsif eth_state = READ_VERSION0 then
				spi_wr_addr <= X"5F";
			elsif eth_state = READ_PHY_REG0 then
				spi_wr_addr <= X"5F";
			elsif eth_state = READ_PHY_REG2 then
				spi_wr_addr <= X"54";
			elsif eth_state = READ_PHY_REG4 then
				spi_wr_addr <= X"52";
			elsif eth_state = READ_PHY_REG7 then
				spi_wr_addr <= X"52";
			end if;
      end if;
   end process;
	
	SPI_DATA_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND3 then
				spi_wr_data <= frame_data(7 downto 0);
			elsif eth_state = READ_VERSION0 then
				spi_wr_data <= X"03";
			elsif eth_state = READ_PHY_REG0 then
				spi_wr_data <= X"02";
			elsif eth_state = READ_PHY_REG2 then
				spi_wr_data <= phy_rd_addr;
			elsif eth_state = READ_PHY_REG4 then
				spi_wr_data <= X"01";
			elsif eth_state = READ_PHY_REG7 then
				spi_wr_data <= X"00";
			end if;
      end if;
   end process;
	
	COMMAND_CMPLT_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state /= IDLE and eth_next_state = IDLE then
				command_cmplt <= '1';
			elsif eth_state /= IDLE and eth_next_state /= IDLE then
				command_cmplt <= '0';
			end if;
      end if;
   end process;
	
	SPI_RD_ADDR_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = READ_VERSION2 then
				spi_rd_addr <= X"12";
			elsif eth_state = READ_PHY_REG9 then
				spi_rd_addr <= X"18";
			elsif eth_state = READ_PHY_REG11 then
				spi_rd_addr <= X"19";
			end if;
      end if;
   end process;

	SPI_RD_FLAG_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = READ_VERSION2 then
				spi_rd <= '1';
			elsif eth_state = READ_PHY_REG9 then
				spi_rd <= '1';
			elsif eth_state = READ_PHY_REG11 then
				spi_rd <= '1';
			else
				spi_rd <= '0';
			end if;
      end if;
   end process;

	ENC_VERSION_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = READ_VERSION4 then
				enc28j60_version <= spi_data_rd;
			end if;
      end if;
   end process;

	RD_PHY_DELAY: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = READ_PHY_REG6 then
				phy_rd_counter <= phy_rd_counter - 1;
			else
				phy_rd_counter <= unsigned(C_phy_rd_delay_count);
			end if;
			if eth_state = READ_PHY_REG11 then
				phy_reg_lwr <= spi_data_rd;
			end if;
			if eth_state = READ_PHY_REG13 then
				phy_reg_upr <= spi_data_rd;
			end if;
		end if;
	end process;
	
	RD_PHY_DUMMY_BYTE: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = READ_PHY_REG10 then
				spi_rd_width <= '1';
			else
				spi_rd_width <= '0';
			end if;
		end if;
	end process;

------------------------- SPI --------------------------------

	spi_mod_inst : spi_mod
		Port Map ( 	CLK_IN 				=> CLK_IN,
						RST_IN 				=> '0',
						WR_CONTINUOUS_IN 	=> spi_wr_continuous,
						WE_IN 				=> spi_we,
						WR_ADDR_IN			=> spi_wr_addr,
						WR_DATA_IN 			=> spi_wr_data,
						WR_DATA_CMPLT_OUT	=> spi_wr_cmplt,
						RD_IN					=> spi_rd,
						RD_WIDTH_IN 		=> spi_rd_width,
						RD_ADDR_IN 			=> spi_rd_addr,
						RD_DATA_OUT 		=> spi_data_rd,
						RD_DATA_CMPLT_OUT	=> spi_rd_cmplt,
						SLOW_CS_EN_IN		=> slow_cs_en,
						OPER_CMPLT_POST_CS_OUT => spi_oper_cmplt,
						SDI_OUT				=> SDI_OUT,
						SDO_IN				=> SDO_IN,
						SCLK_OUT				=> SCLK_OUT,
						CS_OUT				=> CS_OUT);

end Behavioral;

