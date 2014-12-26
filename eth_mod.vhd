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
			  DEBUG_OUT				: out  STD_LOGIC_VECTOR (15 downto 0);
			  
           -- Flash mod ctrl interface
			  FRAME_ADDR_OUT 				: out  STD_LOGIC_VECTOR (23 downto 1);
           FRAME_DATA_IN 				: in  STD_LOGIC_VECTOR (15 downto 0);
           FRAME_DATA_RD_OUT 			: out  STD_LOGIC;
           FRAME_DATA_RD_CMPLT_IN 	: in  STD_LOGIC;
           
			  -- Eth SPI interface
			  SDI_OUT 	: out  STD_LOGIC;
           SDO_IN 	: in  STD_LOGIC;
           SCLK_OUT 	: out  STD_LOGIC;
           CS_OUT 	: out  STD_LOGIC;
			  INT_IN		: in STD_LOGIC);
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
	
	COMPONENT TDP_RAM
		Generic (G_DATA_A_SIZE 	:natural :=32;
					G_ADDR_A_SIZE	:natural :=9;
					G_RELATION		:natural :=3;
					G_INIT_FILE		:string :="");--log2(SIZE_A/SIZE_B)
		Port ( CLK_A_IN 	: in  STD_LOGIC;
				 WE_A_IN 	: in  STD_LOGIC;
				 ADDR_A_IN 	: in  STD_LOGIC_VECTOR (G_ADDR_A_SIZE-1 downto 0);
				 DATA_A_IN	: in  STD_LOGIC_VECTOR (G_DATA_A_SIZE-1 downto 0);
				 DATA_A_OUT	: out  STD_LOGIC_VECTOR (G_DATA_A_SIZE-1 downto 0);
				 CLK_B_IN 	: in  STD_LOGIC;
				 WE_B_IN 	: in  STD_LOGIC;
				 ADDR_B_IN 	: in  STD_LOGIC_VECTOR (G_ADDR_A_SIZE+G_RELATION-1 downto 0);
				 DATA_B_IN 	: in  STD_LOGIC_VECTOR (G_DATA_A_SIZE/(2**G_RELATION)-1 downto 0);
				 DATA_B_OUT : out STD_LOGIC_VECTOR (G_DATA_A_SIZE/(2**G_RELATION)-1 downto 0));
	END COMPONENT;

subtype slv is std_logic_vector;

constant C_init_cmnds_start_addr : std_logic_vector(7 downto 0) := X"01";
constant C_init_cmnds_max_addr 	: std_logic_vector(7 downto 0) := X"7F";
constant C_arp_reply_packet_addr : std_logic_vector(7 downto 0) := X"80";

constant C_phy_rd_delay_count 	: std_logic_vector(8 downto 0) := "1"&X"F4";

constant C_ARP_Packet_Type : std_logic_vector(15 downto 0) := X"0806";

signal spi_we, spi_wr_continuous, spi_wr_cmplt : std_logic := '0';
signal spi_rd, spi_rd_width, spi_rd_cmplt, spi_oper_cmplt : std_logic := '0';
signal spi_wr_addr, spi_wr_data, spi_rd_addr, spi_data_rd : std_logic_vector(7 downto 0) := (others => '0');
signal int, int_p, int_waiting : std_logic := '0';

signal frame_addr : std_logic_vector(22 downto 0);
signal frame_data : std_logic_vector(15 downto 0);
signal frame_data_rd, frame_rd_cmplt, slow_cs_en : std_logic := '0';

signal command_cmplt 	: std_logic := '0';
signal init_cmnd_addr 	: unsigned(7 downto 0);

signal enc28j60_version 			: std_logic_vector(7 downto 0) := (others => '0');
signal phy_rd_counter 				: unsigned(8 downto 0) := unsigned(C_phy_rd_delay_count);
signal phy_reg_lwr, phy_reg_upr	: std_logic_vector(7 downto 0) := (others => '0');
signal phy_rd_addr 					: std_logic_vector(7 downto 0) := (others => '0');
signal interrupt_counter 			: unsigned(7 downto 0) := (others => '0');
signal next_packet_pointer			: std_logic_vector(15 downto 0) := (others => '0');
signal previous_packet_pointer	: unsigned(15 downto 0) := (others => '0');
signal eir_register					: std_logic_vector(7 downto 0) := (others => '0');

signal rx_packet_ram_we, handle_rx_packet, rx_packet_handled : std_logic := '0';
signal rx_packet_ram_we_addr, rx_packet_ram_rd_addr : unsigned(10 downto 0) := (others => '0');
signal rx_packet_rd_data : std_logic_vector(7 downto 0);
signal rx_packet_status_vector, arp_target_ip_addr, arp_source_ip_addr : std_logic_vector(31 downto 0);
signal rx_packet_type 			: std_logic_vector(15 downto 0);
signal rx_packet_source_mac 	: std_logic_vector(47 downto 0);
signal send_arp_reply : std_logic := '0';

signal tx_packet_ram_we : std_logic := '0';
signal tx_packet_ram_we_addr, tx_packet_ram_rd_addr : unsigned(10 downto 0) := (others => '0');
signal tx_packet_rd_data, tx_packet_ram_data : std_logic_vector(7 downto 0);

signal ip_addr  : std_logic_vector(31 downto 0) := X"0A0A0666"; 		-- 10.10.6.102
signal mac_addr : std_logic_vector(47 downto 0) := X"8066F23D547A";

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
						HANDLE_INIT_CMND5,
						SERVICE_INTERRUPT0,
						SERVICE_INTERRUPT1,
						SERVICE_INTERRUPT2,
						SERVICE_INTERRUPT3,
						SERVICE_INTERRUPT4,
						SERVICE_INTERRUPT5,
						SERVICE_INTERRUPT6,
						SERVICE_INTERRUPT7,
						SERVICE_INTERRUPT8,
						HANDLE_TX_INTERRUPT0,
						HANDLE_RX_INTERRUPT0,
						HANDLE_RX_INTERRUPT1,
						HANDLE_RX_INTERRUPT2,
						HANDLE_RX_INTERRUPT3,
						HANDLE_RX_INTERRUPT4,
						HANDLE_RX_INTERRUPT5,
						HANDLE_RX_INTERRUPT6,
						HANDLE_RX_INTERRUPT7,
						HANDLE_RX_INTERRUPT8,
						HANDLE_RX_INTERRUPT9,
						HANDLE_RX_INTERRUPT10,
						HANDLE_RX_INTERRUPT11,
						HANDLE_RX_INTERRUPT12,
						HANDLE_RX_INTERRUPT13,
						HANDLE_RX_INTERRUPT14,
						HANDLE_RX_INTERRUPT15,
						HANDLE_RX_INTERRUPT16,
						HANDLE_RX_INTERRUPT17,
						COPY_RX_PACKET_TO_BUF0,
						COPY_RX_PACKET_TO_BUF1,
						COPY_RX_PACKET_TO_BUF2,
						COPY_RX_PACKET_TO_BUF3,
						COPY_RX_PACKET_TO_BUF4,
						COPY_RX_PACKET_TO_BUF5,
						COPY_RX_PACKET_TO_BUF6
						);

signal eth_state, eth_next_state : ETH_ST := IDLE;
signal state_debug_sig : unsigned(7 downto 0);

type PACKET_HANDLER_ST is (	IDLE,
										CHECK_PACKET_VERACITY0,
										CHECK_PACKET_VERACITY1,
										CHECK_PACKET_VERACITY2,
										CHECK_PACKET_VERACITY3,
										CHECK_PACKET_VERACITY4,
										CHECK_PACKET_VERACITY5,
										CHECK_PACKET_VERACITY6,
										PARSE_SOURCE_MAC0,
										PARSE_SOURCE_MAC1,
										PARSE_SOURCE_MAC2,
										PARSE_SOURCE_MAC3,
										PARSE_SOURCE_MAC4,
										PARSE_SOURCE_MAC5,
										PARSE_SOURCE_MAC6,
										PARSE_SOURCE_MAC7,
										PARSE_PACKET_TYPE0,
										PARSE_PACKET_TYPE1,
										PARSE_PACKET_TYPE2,
										PARSE_PACKET_TYPE3,
										PARSE_PACKET_TYPE4,
										HANDLE_ARP_REQUEST0,
										HANDLE_ARP_REQUEST1,
										HANDLE_ARP_REQUEST2,
										HANDLE_ARP_REQUEST3,
										HANDLE_ARP_REQUEST4,
										HANDLE_ARP_REQUEST5,
										HANDLE_ARP_REQUEST6,
										HANDLE_ARP_REQUEST7,
										HANDLE_ARP_REQUEST8,
										HANDLE_ARP_REQUEST9,
										HANDLE_ARP_REQUEST10,
										HANDLE_ARP_REQUEST11,
										HANDLE_ARP_REQUEST12,
										HANDLE_ARP_REQUEST13,
										TRIGGER_ARP_REPLY,
										COMPLETE
									);
										
signal packet_handler_state, packet_handler_next_state : PACKET_HANDLER_ST := IDLE;					

begin
	
	--DEBUG_OUT(15 downto 8) <= X"00";
	--DEBUG_OUT(7 downto 0) <= slv(init_cmnd_addr);
	--DEBUG_OUT(7 downto 0) <= slv(state_debug_sig);
	--DEBUG_OUT(7 downto 0) <= enc28j60_version;
	--DEBUG_OUT(7 downto 0) <= phy_reg_upr;
	--DEBUG_OUT(7 downto 0) <= slv(interrupt_counter);
	--DEBUG_OUT <= spi_wr_addr & spi_wr_data;
	--DEBUG_OUT <= next_packet_pointer;
	--DEBUG_OUT <= rx_packet_status_vector(15 downto 0) when DEBUG_IN = '0' else rx_packet_status_vector(31 downto 16);
	--DEBUG_OUT <= rx_packet_source_mac(15 downto 0) when DEBUG_IN = '0' else rx_packet_source_mac(31 downto 16);
	--DEBUG_OUT <= arp_target_ip_addr(15 downto 0) when DEBUG_IN = '0' else arp_target_ip_addr(31 downto 16);
	DEBUG_OUT <= arp_source_ip_addr(15 downto 0) when DEBUG_IN = '0' else arp_source_ip_addr(31 downto 16);
	--DEBUG_OUT(7 downto 0) <= rx_packet_rd_data;
	--DEBUG_OUT <= rx_packet_type;
	
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

	NEXT_STATE_DECODE: process (eth_state, COMMAND_IN, COMMAND_EN_IN, init_cmnd_addr, 
											phy_rd_counter, int_waiting, frame_data)
   begin
      eth_next_state <= eth_state;  --default is to stay in current state
      case (eth_state) is
         when IDLE =>
				if COMMAND_EN_IN = '1' then
					eth_next_state <= PARSE_COMMAND;
				elsif int_waiting = '1' then
					eth_next_state <= SERVICE_INTERRUPT0;
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
					if frame_data = X"0000" then
						eth_next_state <= IDLE;
					else
						eth_next_state <= HANDLE_INIT_CMND3;
					end if;
				end if;
			when HANDLE_INIT_CMND3 =>
				eth_next_state <= HANDLE_INIT_CMND4;
			when HANDLE_INIT_CMND4 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_INIT_CMND5;
				end if;
			when HANDLE_INIT_CMND5 =>
				if slv(init_cmnd_addr) = C_init_cmnds_max_addr then
					eth_next_state <= IDLE;
				else
					eth_next_state <= HANDLE_INIT_CMND1;
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
			when SERVICE_INTERRUPT0 =>
				eth_next_state <= SERVICE_INTERRUPT1;
			when SERVICE_INTERRUPT1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= SERVICE_INTERRUPT2;
				end if;
			when SERVICE_INTERRUPT2 =>
				eth_next_state <= SERVICE_INTERRUPT3;
			when SERVICE_INTERRUPT3 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= SERVICE_INTERRUPT4;
				end if;
			when SERVICE_INTERRUPT4 =>
				eth_next_state <= SERVICE_INTERRUPT5;
			when SERVICE_INTERRUPT5 =>
				if eir_register(6) = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT0;
				elsif eir_register(3) = '1' then
					eth_next_state <= HANDLE_TX_INTERRUPT0;
				end if;
			when HANDLE_TX_INTERRUPT0 =>
				eth_next_state <= IDLE;
			when HANDLE_RX_INTERRUPT0 =>
				eth_next_state <= HANDLE_RX_INTERRUPT1;
			when HANDLE_RX_INTERRUPT1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT2;
				end if;
			when HANDLE_RX_INTERRUPT2 =>
				eth_next_state <= HANDLE_RX_INTERRUPT3;
			when HANDLE_RX_INTERRUPT3 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT4;
				end if;
			when HANDLE_RX_INTERRUPT4 =>
				eth_next_state <= COPY_RX_PACKET_TO_BUF0;
			
			when COPY_RX_PACKET_TO_BUF0 =>
				eth_next_state <= COPY_RX_PACKET_TO_BUF1;
			when COPY_RX_PACKET_TO_BUF1 =>
				eth_next_state <= COPY_RX_PACKET_TO_BUF2;
			when COPY_RX_PACKET_TO_BUF2 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= COPY_RX_PACKET_TO_BUF3;
				end if;
			when COPY_RX_PACKET_TO_BUF3 =>
				eth_next_state <= COPY_RX_PACKET_TO_BUF4;
			when COPY_RX_PACKET_TO_BUF4 =>
				if slv(previous_packet_pointer) = next_packet_pointer then
					eth_next_state <= COPY_RX_PACKET_TO_BUF5;
				else
					eth_next_state <= COPY_RX_PACKET_TO_BUF1;
				end if;
			when COPY_RX_PACKET_TO_BUF5 =>
				eth_next_state <= COPY_RX_PACKET_TO_BUF6;
			when COPY_RX_PACKET_TO_BUF6 =>
				if rx_packet_handled = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT5;
				end if;
			
			when HANDLE_RX_INTERRUPT5 =>
				eth_next_state <= HANDLE_RX_INTERRUPT6;
			when HANDLE_RX_INTERRUPT6 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT7;
				end if;
			when HANDLE_RX_INTERRUPT7 =>
				eth_next_state <= HANDLE_RX_INTERRUPT8;
			when HANDLE_RX_INTERRUPT8 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT9;
				end if;
			when HANDLE_RX_INTERRUPT9 =>
				eth_next_state <= HANDLE_RX_INTERRUPT10;
			when HANDLE_RX_INTERRUPT10 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT11;
				end if;
			when HANDLE_RX_INTERRUPT11 =>
				eth_next_state <= HANDLE_RX_INTERRUPT12;
			when HANDLE_RX_INTERRUPT12 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT13;
				end if;
			when HANDLE_RX_INTERRUPT13 =>
				eth_next_state <= HANDLE_RX_INTERRUPT14;
			when HANDLE_RX_INTERRUPT14 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT15;
				end if;
			when HANDLE_RX_INTERRUPT15 =>
				eth_next_state <= HANDLE_RX_INTERRUPT16;
			when HANDLE_RX_INTERRUPT16 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_RX_INTERRUPT17;
				end if;
			when HANDLE_RX_INTERRUPT17 =>
				eth_next_state <= SERVICE_INTERRUPT6;
				
			when SERVICE_INTERRUPT6 =>
				eth_next_state <= SERVICE_INTERRUPT7;
			when SERVICE_INTERRUPT7 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= SERVICE_INTERRUPT8;
				end if;
			when SERVICE_INTERRUPT8 =>
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
			elsif eth_state = SERVICE_INTERRUPT0 then
				spi_we <= '1';
			elsif eth_state = SERVICE_INTERRUPT6 then
				spi_we <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT5 then
				spi_we <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT7 then
				spi_we <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT9 then
				spi_we <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT11 then
				spi_we <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT13 then
				spi_we <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT15 then
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
			elsif eth_state = SERVICE_INTERRUPT0 then
				spi_wr_addr <= X"BB";
			elsif eth_state = HANDLE_RX_INTERRUPT5 then
				spi_wr_addr <= X"BF";
			elsif eth_state = HANDLE_RX_INTERRUPT7 then
				spi_wr_addr <= X"4C";
			elsif eth_state = HANDLE_RX_INTERRUPT9 then
				spi_wr_addr <= X"4D";
			elsif eth_state = HANDLE_RX_INTERRUPT11 then
				spi_wr_addr <= X"40";
			elsif eth_state = HANDLE_RX_INTERRUPT13 then
				spi_wr_addr <= X"41";	
			elsif eth_state = HANDLE_RX_INTERRUPT15 then
				spi_wr_addr <= X"9E";
			elsif eth_state = SERVICE_INTERRUPT6 then
				spi_wr_addr <= X"9B";
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
			elsif eth_state = SERVICE_INTERRUPT0 then
				spi_wr_data <= X"80";
			elsif eth_state = HANDLE_RX_INTERRUPT5 then
				spi_wr_data <= X"03";
			elsif eth_state = HANDLE_RX_INTERRUPT7 then
				spi_wr_data <= next_packet_pointer(7 downto 0);
			elsif eth_state = HANDLE_RX_INTERRUPT9 then
				spi_wr_data <= next_packet_pointer(15 downto 8);
			elsif eth_state = HANDLE_RX_INTERRUPT11 then
				spi_wr_data <= next_packet_pointer(7 downto 0);
			elsif eth_state = HANDLE_RX_INTERRUPT13 then
				spi_wr_data <= next_packet_pointer(15 downto 8);
			elsif eth_state = HANDLE_RX_INTERRUPT15 then
				spi_wr_data <= X"40";
			elsif eth_state = SERVICE_INTERRUPT6 then
				spi_wr_data <= X"80";
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
			elsif eth_state = SERVICE_INTERRUPT2 then
				spi_rd_addr <= X"1C";
			elsif eth_state = HANDLE_RX_INTERRUPT0 then
				spi_rd_addr <= X"3A";
			elsif eth_state = HANDLE_RX_INTERRUPT2 then
				spi_rd_addr <= X"3A";
			elsif eth_state = COPY_RX_PACKET_TO_BUF1 then
				spi_rd_addr <= X"3A";
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
			elsif eth_state = SERVICE_INTERRUPT2 then
				spi_rd <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT0 then
				spi_rd <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT2 then
				spi_rd <= '1';
			elsif eth_state = COPY_RX_PACKET_TO_BUF1 then
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
			if eth_state = SERVICE_INTERRUPT4 then
				eir_register <= spi_data_rd;
			end if;
			if eth_state = HANDLE_RX_INTERRUPT2 then
				next_packet_pointer(7 downto 0) <= spi_data_rd;
			end if;
			if eth_state = HANDLE_RX_INTERRUPT4 then
				next_packet_pointer(15 downto 8) <= spi_data_rd;
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

	int <= INT_IN;

	INT_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			int_p <= int;
			if int_p = '1' and int = '0' then
				int_waiting <= '1';
			elsif eth_state = SERVICE_INTERRUPT0 then
				int_waiting <= '0';
			end if;
			if eth_state = HANDLE_RX_INTERRUPT0 then
				interrupt_counter <= interrupt_counter + 1;
			end if;
		end if;
	end process;

------------------------- RX PACKET --------------------------------

	handle_rx_packet <= '1' when eth_state = COPY_RX_PACKET_TO_BUF5 else '0';

	RX_PACKET_WR_ADDR: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = COPY_RX_PACKET_TO_BUF0 then
				rx_packet_ram_we_addr <= "00000000000";
			elsif eth_state = COPY_RX_PACKET_TO_BUF3 then
				rx_packet_ram_we_addr <= rx_packet_ram_we_addr + 1;
			end if;
			if eth_state = HANDLE_RX_INTERRUPT5 then
				previous_packet_pointer <= unsigned(next_packet_pointer);
			elsif eth_state = COPY_RX_PACKET_TO_BUF3 then
				previous_packet_pointer <= previous_packet_pointer + 1;
			end if;
		end if;
	end process;

	rx_packet_ram_we <= '1' when eth_state = COPY_RX_PACKET_TO_BUF3 else '0';

	RX_PACKET_RAM : TDP_RAM
		Generic Map (	G_DATA_A_SIZE 	=> spi_data_rd'length,
							G_ADDR_A_SIZE	=> rx_packet_ram_we_addr'length,
							G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
							G_INIT_FILE		=> "")
		Port Map ( CLK_A_IN 	=> CLK_IN,
				 WE_A_IN 		=> rx_packet_ram_we,
				 ADDR_A_IN 		=> slv(rx_packet_ram_we_addr),
				 DATA_A_IN		=> spi_data_rd,
				 DATA_A_OUT		=> open,
				 CLK_B_IN 		=> CLK_IN,
				 WE_B_IN 		=> '0',
				 ADDR_B_IN 		=> slv(rx_packet_ram_rd_addr),
				 DATA_B_IN 		=> X"00",
				 DATA_B_OUT 	=> rx_packet_rd_data);

	PH_SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			packet_handler_state <= packet_handler_next_state;
      end if;
   end process;

	rx_packet_handled <= '1' when packet_handler_state = COMPLETE else '0';
	send_arp_reply <= '1' when packet_handler_state = TRIGGER_ARP_REPLY else '0';

	PH_NEXT_STATE_DECODE: process (packet_handler_state)
   begin
      packet_handler_next_state <= packet_handler_state;  --default is to stay in current state
      case (packet_handler_state) is
         when IDLE =>
				if handle_rx_packet = '1' then
					packet_handler_next_state <= CHECK_PACKET_VERACITY0;
				end if;
			when CHECK_PACKET_VERACITY0 =>
				packet_handler_next_state <= CHECK_PACKET_VERACITY1;
			when CHECK_PACKET_VERACITY1 =>
				packet_handler_next_state <= CHECK_PACKET_VERACITY2;
			when CHECK_PACKET_VERACITY2 =>
				packet_handler_next_state <= CHECK_PACKET_VERACITY3;
			when CHECK_PACKET_VERACITY3 =>
				packet_handler_next_state <= CHECK_PACKET_VERACITY4;
			when CHECK_PACKET_VERACITY4 =>
				packet_handler_next_state <= CHECK_PACKET_VERACITY5;
			when CHECK_PACKET_VERACITY5 =>
				packet_handler_next_state <= CHECK_PACKET_VERACITY6;
			when CHECK_PACKET_VERACITY6 =>
				if rx_packet_status_vector(23) = '1' then
					packet_handler_next_state <= PARSE_SOURCE_MAC0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when PARSE_SOURCE_MAC0 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC1;
			when PARSE_SOURCE_MAC1 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC2;
			when PARSE_SOURCE_MAC2 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC3;
			when PARSE_SOURCE_MAC3 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC4;
			when PARSE_SOURCE_MAC4 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC5;
			when PARSE_SOURCE_MAC5 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC6;
			when PARSE_SOURCE_MAC6 =>
				packet_handler_next_state <= PARSE_SOURCE_MAC7;
			when PARSE_SOURCE_MAC7 =>
				packet_handler_next_state <= PARSE_PACKET_TYPE0;
			when PARSE_PACKET_TYPE0 =>
				packet_handler_next_state <= PARSE_PACKET_TYPE1;
			when PARSE_PACKET_TYPE1 =>
				packet_handler_next_state <= PARSE_PACKET_TYPE2;
			when PARSE_PACKET_TYPE2 =>
				packet_handler_next_state <= PARSE_PACKET_TYPE3;
			when PARSE_PACKET_TYPE3 =>
				packet_handler_next_state <= PARSE_PACKET_TYPE4;
			when PARSE_PACKET_TYPE4 =>
				if rx_packet_type = C_ARP_Packet_Type then
					packet_handler_next_state <= HANDLE_ARP_REQUEST0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
				
			when HANDLE_ARP_REQUEST0 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST1;
			when HANDLE_ARP_REQUEST1 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST2;
			when HANDLE_ARP_REQUEST2 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST3;
			when HANDLE_ARP_REQUEST3 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST4;
			when HANDLE_ARP_REQUEST4 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST5;
			when HANDLE_ARP_REQUEST5 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST6;
			when HANDLE_ARP_REQUEST6 =>
				if arp_target_ip_addr = ip_addr then
					packet_handler_next_state <= HANDLE_ARP_REQUEST7;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when HANDLE_ARP_REQUEST7 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST8;
			when HANDLE_ARP_REQUEST8 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST9;
			when HANDLE_ARP_REQUEST9 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST10;
			when HANDLE_ARP_REQUEST10 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST11;
			when HANDLE_ARP_REQUEST11 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST12;
			when HANDLE_ARP_REQUEST12 =>
				packet_handler_next_state <= HANDLE_ARP_REQUEST13;
			when HANDLE_ARP_REQUEST13 =>
				packet_handler_next_state <= TRIGGER_ARP_REPLY;
				
			when TRIGGER_ARP_REPLY =>
				packet_handler_next_state <= COMPLETE;
			
			when COMPLETE =>
				packet_handler_next_state <= IDLE;
		end case;
	end process;

	RX_PACKET_RD_ADDR: process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_state = CHECK_PACKET_VERACITY0 then
				rx_packet_ram_rd_addr <= "000"&X"00";
			elsif packet_handler_state = CHECK_PACKET_VERACITY1 then
				rx_packet_ram_rd_addr <= "000"&X"01";
			elsif packet_handler_state = CHECK_PACKET_VERACITY2 then
				rx_packet_ram_rd_addr <= "000"&X"02";
			elsif packet_handler_state = CHECK_PACKET_VERACITY3 then
				rx_packet_ram_rd_addr <= "000"&X"03";
			elsif packet_handler_state = PARSE_SOURCE_MAC0 then
				rx_packet_ram_rd_addr <= "000"&X"0A";
			elsif packet_handler_state = PARSE_SOURCE_MAC1 then
				rx_packet_ram_rd_addr <= "000"&X"0B";
			elsif packet_handler_state = PARSE_SOURCE_MAC2 then
				rx_packet_ram_rd_addr <= "000"&X"0C";
			elsif packet_handler_state = PARSE_SOURCE_MAC3 then
				rx_packet_ram_rd_addr <= "000"&X"0D";
			elsif packet_handler_state = PARSE_SOURCE_MAC4 then
				rx_packet_ram_rd_addr <= "000"&X"0E";
			elsif packet_handler_state = PARSE_SOURCE_MAC5 then
				rx_packet_ram_rd_addr <= "000"&X"0F";
			elsif packet_handler_state = PARSE_PACKET_TYPE0 then
				rx_packet_ram_rd_addr <= "000"&X"10";
			elsif packet_handler_state = PARSE_PACKET_TYPE1 then
				rx_packet_ram_rd_addr <= "000"&X"11";
			elsif packet_handler_state = HANDLE_ARP_REQUEST0 then
				rx_packet_ram_rd_addr <= "000"&X"2A";
			elsif packet_handler_state = HANDLE_ARP_REQUEST1 then
				rx_packet_ram_rd_addr <= "000"&X"2B";
			elsif packet_handler_state = HANDLE_ARP_REQUEST2 then
				rx_packet_ram_rd_addr <= "000"&X"2C";
			elsif packet_handler_state = HANDLE_ARP_REQUEST3 then
				rx_packet_ram_rd_addr <= "000"&X"2D";
			elsif packet_handler_state = HANDLE_ARP_REQUEST7 then
				rx_packet_ram_rd_addr <= "000"&X"20";
			elsif packet_handler_state = HANDLE_ARP_REQUEST8 then
				rx_packet_ram_rd_addr <= "000"&X"21";
			elsif packet_handler_state = HANDLE_ARP_REQUEST9 then
				rx_packet_ram_rd_addr <= "000"&X"22";
			elsif packet_handler_state = HANDLE_ARP_REQUEST10 then
				rx_packet_ram_rd_addr <= "000"&X"23";
			end if;
			if packet_handler_state = HANDLE_ARP_REQUEST9 then
				arp_source_ip_addr(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_ARP_REQUEST10 then
				arp_source_ip_addr(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_ARP_REQUEST11 then
				arp_source_ip_addr(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_ARP_REQUEST12 then
				arp_source_ip_addr(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = HANDLE_ARP_REQUEST2 then
				arp_target_ip_addr(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_ARP_REQUEST3 then
				arp_target_ip_addr(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_ARP_REQUEST4 then
				arp_target_ip_addr(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_ARP_REQUEST5 then
				arp_target_ip_addr(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = CHECK_PACKET_VERACITY2 then
				rx_packet_status_vector(7 downto 0) <= rx_packet_rd_data;
			elsif packet_handler_state = CHECK_PACKET_VERACITY3 then
				rx_packet_status_vector(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = CHECK_PACKET_VERACITY4 then
				rx_packet_status_vector(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = CHECK_PACKET_VERACITY5 then
				rx_packet_status_vector(31 downto 24) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_SOURCE_MAC2 then
				rx_packet_source_mac(47 downto 40) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_SOURCE_MAC3 then
				rx_packet_source_mac(39 downto 32) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_SOURCE_MAC4 then
				rx_packet_source_mac(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_SOURCE_MAC5 then
				rx_packet_source_mac(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_SOURCE_MAC6 then
				rx_packet_source_mac(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_SOURCE_MAC7 then
				rx_packet_source_mac(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_PACKET_TYPE2 then
				rx_packet_type(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_PACKET_TYPE3 then
				rx_packet_type(7 downto 0) <= rx_packet_rd_data;
			end if;
		end if;
	end process;

--------------------- TX PACKET ------------------------------

	TX_PACKET_RAM : TDP_RAM
		Generic Map (	G_DATA_A_SIZE 	=> tx_packet_ram_data'length,
							G_ADDR_A_SIZE	=> tx_packet_ram_we_addr'length,
							G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
							G_INIT_FILE		=> "")
		Port Map ( CLK_A_IN 	=> CLK_IN,
				 WE_A_IN 		=> tx_packet_ram_we,
				 ADDR_A_IN 		=> slv(tx_packet_ram_we_addr),
				 DATA_A_IN		=> tx_packet_ram_data,
				 DATA_A_OUT		=> open,
				 CLK_B_IN 		=> CLK_IN,
				 WE_B_IN 		=> '0',
				 ADDR_B_IN 		=> slv(tx_packet_ram_rd_addr),
				 DATA_B_IN 		=> X"00",
				 DATA_B_OUT 	=> tx_packet_rd_data);

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

