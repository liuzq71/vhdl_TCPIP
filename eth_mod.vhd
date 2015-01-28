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
           COMMAND_IN			: in  STD_LOGIC_VECTOR (3 downto 0);
			  COMMAND_EN_IN		: in 	STD_LOGIC;
           COMMAND_CMPLT_OUT 	: out STD_LOGIC;
           ERROR_OUT 			: out  STD_LOGIC_VECTOR (7 downto 0);
			  
			  -- Data Interface
			  ADDR_IN	: in  STD_LOGIC_VECTOR (7 downto 0);
			  DATA_OUT	: out  STD_LOGIC_VECTOR (7 downto 0);
			  
			  -- Debug Interface
--			  DEBUG_IN				: in 	STD_LOGIC;
			  DEBUG_OUT				: out  STD_LOGIC_VECTOR (15 downto 0);
			  
           -- TCP Connection Interface
			  TCP_RD_DATA_AVAIL_OUT : out STD_LOGIC;
			  TCP_RD_DATA_EN_IN 		: in STD_LOGIC;
			  TCP_RD_DATA_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
           
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
	
	COMPONENT checksum_calc
    Port ( CLK_IN 					: in  STD_LOGIC;
           RST_IN 					: in  STD_LOGIC;
           CHECKSUM_CALC_IN 		: in  STD_LOGIC;
           START_ADDR_IN 			: in  STD_LOGIC_VECTOR (10 downto 0);
           COUNT_IN 					: in  STD_LOGIC_VECTOR (10 downto 0);
           VALUE_IN 					: in  STD_LOGIC_VECTOR (7 downto 0);
           VALUE_ADDR_OUT 			: out  STD_LOGIC_VECTOR (10 downto 0);
			  CHECKSUM_INIT_IN		: in  STD_LOGIC_VECTOR (15 downto 0);
			  CHECKSUM_SET_INIT_IN	: in  STD_LOGIC;
           CHECKSUM_OUT 			: out STD_LOGIC_VECTOR (15 downto 0);
           CHECKSUM_DONE_OUT 		: out STD_LOGIC);
	END COMPONENT;
	
	COMPONENT lfsr32_mod
		 Port ( CLK_IN 		: in  STD_LOGIC;
				  SEED_IN 		: in  STD_LOGIC_VECTOR(31 downto 0);
				  SEED_EN_IN 	: in  STD_LOGIC;
				  VAL_OUT 		: out STD_LOGIC_VECTOR(31 downto 0));
	END COMPONENT;
	
	COMPONENT TDP_RAM
		Generic (G_DATA_A_SIZE 	:natural :=32;
					G_ADDR_A_SIZE	:natural :=9;
					G_RELATION		:natural :=3;
					G_INIT_ZERO		:boolean := true;
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
	
	--COMPONENT Packet_Definition_LX9
	COMPONENT Packet_Definition
	  PORT (
		 clka 	: IN STD_LOGIC;
		 addra 	: IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		 douta 	: OUT STD_LOGIC_VECTOR(15 DOWNTO 0));
	END COMPONENT;

subtype slv is std_logic_vector;

constant C_init_cmnds_start_addr 	: std_logic_vector(7 downto 0) := X"01";
constant C_init_cmnds_max_addr 		: std_logic_vector(7 downto 0) := X"7F";
constant C_arp_reply_frame_addr 		: std_logic_vector(11 downto 0) := X"080";
constant C_icmp_reply_frame_addr 	: std_logic_vector(11 downto 0) := X"0AB";
constant C_dhcp_discover_frame_addr : std_logic_vector(11 downto 0) := X"124";
constant C_dhcp_request_frame_addr 	: std_logic_vector(11 downto 0) := X"286";
constant C_arp_request_frame_addr 	: std_logic_vector(11 downto 0) := X"467";
constant C_tcp_packet_frame_addr 	: std_logic_vector(11 downto 0) := X"492";

constant C_arp_reply_length 		: std_logic_vector(15 downto 0) := X"002A";
constant C_icmp_reply_length 		: std_logic_vector(15 downto 0) := X"0062";
constant C_dhcp_discover_length 	: std_logic_vector(15 downto 0) := X"0156";
constant C_dhcp_request_length 	: std_logic_vector(15 downto 0) := X"015C";
constant C_arp_request_length 	: std_logic_vector(15 downto 0) := X"002A";
constant C_tcp_packet_length 		: std_logic_vector(15 downto 0) := X"004A";

constant C_ARP_Packet_Type 		: std_logic_vector(15 downto 0) := X"0806";
constant C_IP_Packet_Type 			: std_logic_vector(15 downto 0) := X"0800";
constant C_ICMP_Protocol_Number	: std_logic_vector(7 downto 0) := X"01";
constant C_UDP_Protocol_Number	: std_logic_vector(7 downto 0) := X"11";
constant C_TCP_Protocol_Number	: std_logic_vector(7 downto 0) := X"06";
constant C_IPV4_Protocol_Number	: std_logic_vector(3 downto 0) := X"4";
constant C_DHCP_Source_Port		: std_logic_vector(15 downto 0) := X"0043";
constant C_DHCP_Dest_Port			: std_logic_vector(15 downto 0) := X"0044";
constant C_dhcp_magic_cookie		: std_logic_vector(31 downto 0) := X"63825363";
constant C_tcp_syn_flags			: std_logic_vector(7 downto 0) := X"02";
constant C_tcp_ack_flags			: std_logic_vector(7 downto 0) := X"10";

constant C_phy_rd_delay_count 	: std_logic_vector(8 downto 0) := "1"&X"F4";
constant C_ICMP_Ping_Length 		: std_logic_vector(15 downto 0) := X"0054";
constant C_ARP_Request 				: std_logic_vector(7 downto 0) := X"01";
constant C_ARP_Reply			 		: std_logic_vector(7 downto 0) := X"02";

constant C_rx_pointer_min : unsigned(15 downto 0) := X"0000";
constant C_rx_pointer_max : unsigned(15 downto 0) := X"0FFF";

signal int, int_p, int_waiting : std_logic := '0';
signal spi_we, spi_wr_continuous, spi_wr_cmplt : std_logic := '0';
signal spi_rd, spi_rd_width, spi_rd_cmplt, spi_oper_cmplt : std_logic := '0';
signal spi_wr_addr, spi_wr_data, spi_rd_addr, spi_data_rd : std_logic_vector(7 downto 0) := (others => '0');

signal frame_addr : std_logic_vector(11 downto 0);
signal frame_data : std_logic_vector(15 downto 0);
signal frame_data_rd, frame_rd_cmplt, slow_cs_en : std_logic := '0';
signal network_interface_enabled : std_logic := '0';

signal command_cmplt, command_trig, command_en_in_p 	: std_logic := '0';
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
signal debug_rx_flag, debug_rx_flag1, debug_rx_flag2  : std_logic := '0';
signal rx_packet_ram_we_addr, rx_packet_ram_we_addr_buf : unsigned(10 downto 0) := (others => '0');
signal rx_packet_ram_rd_addr : unsigned(10 downto 0) := (others => '0');
signal rx_packet_rd2_addr : unsigned(10 downto 0) := (others => '0');
signal rx_packet_rd_data, rx_packet_rd_data2 : std_logic_vector(7 downto 0);
signal rx_packet_status_vector, arp_target_ip_addr, arp_source_ip_addr : std_logic_vector(31 downto 0);
signal rx_packet_type 			: std_logic_vector(15 downto 0);
signal rx_packet_source_mac 	: std_logic_vector(47 downto 0);
signal send_arp_reply, send_arp_request : std_logic := '0';
signal send_icmp_reply, send_dhcp_discover, send_dhcp_request : std_logic := '0';
signal arp_opcode : std_logic_vector(7 downto 0);

signal tx_packet_ram_we, tx_packet_config_cmplt : std_logic := '0';
signal tx_packet_ram_we_addr, tx_packet_ram_rd_addr : unsigned(10 downto 0) := (others => '0');
signal tx_packet_ram_we_addr_buf : unsigned(10 downto 0) := (others => '0');
signal tx_packet_rd_data, tx_packet_ram_data : std_logic_vector(7 downto 0);
signal tx_packet_rd_data2 : std_logic_vector(7 downto 0);

signal ip_addr  		: std_logic_vector(31 downto 0) := X"C0A80166"; 		-- 192.168.1.102
signal mac_addr 		: std_logic_vector(47 downto 0) := X"8066F23D547A";
signal ip_identification : std_logic_vector(15 downto 0);
signal ping_enable 	: std_logic := '1';
signal dhcp_enable 	: std_logic := '1';
signal dhcp_addr_locked, static_addr_locked 	: std_logic := '0';

signal server_ip_addr : std_logic_vector(31 downto 0) := X"C0A80100";
signal server_mac_addr : std_logic_vector(47 downto 0) := X"000000000000";

signal cloud_ip_addr : std_logic_vector(31 downto 0) := X"DCEFF2CC"; -- 220.239.242.204

signal tx_packet_frame_addr :unsigned(11 downto 0);
signal tx_packet_length, tx_packet_length_counter, tx_packet_end_pointer :unsigned(15 downto 0);
signal doing_tx_packet_config, tx_packet_frame_data_rd : std_logic := '0';
signal packet_instruction, packet_data : std_logic_vector(7 downto 0);
signal tx_packet_ready_from_transmission : std_logic := '0';

signal ip_packet_version  			: std_logic_vector(3 downto 0);
signal ip_packet_protocol 			: std_logic_vector(7 downto 0);
signal ip_packet_header_length	: std_logic_vector(7 downto 0);
signal ip_packet_destination_ip 	: std_logic_vector(31 downto 0);
signal ip_packet_length 			: std_logic_vector(15 downto 0);
signal total_packet_length 		: unsigned(15 downto 0);

signal lfsr_val : std_logic_vector(31 downto 0);
signal calc_checksum, checksum_calc_done : std_logic := '0';
signal checksum_start_addr, checksum_addr, checksum_wr_addr : std_logic_vector(10 downto 0);
signal checksum_count : std_logic_vector(10 downto 0);
signal checksum : std_logic_vector(15 downto 0);
signal checksum_initial_value : std_logic_vector(15 downto 0);
signal checksum_set_initial_value : std_logic;

signal command : std_logic_vector(3 downto 0);
signal poll_interrupt_reg, command_waiting : std_logic;
signal poll_counter : unsigned(3 downto 0) := (others => '1');

signal dhcp_transaction_id : std_logic_vector(31 downto 0) := X"CA805562";
signal transaction_id_rd : std_logic_vector(31 downto 0) := X"00000000";

signal udp_source_port, udp_dest_port : std_logic_vector(15 downto 0);
signal dhcp_your_ip_addr, dhcp_server_ip_addr, dhcp_magic_cookie : std_logic_vector(31 downto 0);

signal expecting_dhcp_offer, expecting_dhcp_ack, expecting_arp_reply : std_logic := '0';
signal expecting_syn_ack : std_logic := '0';
signal dhcp_option_addr : unsigned(10 downto 0);
signal dhcp_option, dhcp_option_length, dhcp_message_type : std_logic_vector(7 downto 0);

signal packet_definition_addr : std_logic_vector(11 downto 0);
signal packet_definition_data : std_logic_vector(15 downto 0);

signal tcp_port 		: std_logic_vector(15 downto 0) := (others => '0');
signal server_port 	: std_logic_vector(15 downto 0) := X"0DA2";
signal tcp_sequence_number, tcp_acknowledge_number : unsigned(31 downto 0) := (others => '0');
signal tcp_sequence_number_p1 : unsigned(31 downto 0) := (others => '0');
signal tcp_flags : std_logic_vector(7 downto 0) := (others => '0');
signal window_size : std_logic_vector(15 downto 0) := X"0200";
signal send_tcp_svn_packet, send_tcp_ack_packet, cancel_dhcp_connect : std_logic := '0';
signal tcp_connection_active, close_tcp_connection, cancel_tcp_connection : std_logic := '0';
signal tcp_ip_identification : unsigned(15 downto 0);

signal rx_tcp_source_port, rx_tcp_dest_port : std_logic_vector(15 downto 0) := (others => '0');
signal rx_tcp_seq_number, rx_tcp_ack_number : std_logic_vector(31 downto 0) := (others => '0');
signal rx_tcp_window_size, rx_tcp_checksum : std_logic_vector(15 downto 0) := (others => '0');
signal rx_tcp_flags, rx_tcp_option, rx_tcp_header_length : std_logic_vector(7 downto 0) := (others => '0');
signal rx_tcp_option_length : unsigned(7 downto 0);
signal rx_tcp_window_shift : std_logic_vector(7 downto 0);
signal tcp_option_addr, next_protocol_start_addr : unsigned(10 downto 0);
signal rx_data_length : unsigned(15 downto 0);

signal tcp_rx_data_we, tcp_rd_data_available, tcp_data_rd_en : std_logic := '0';
signal tcp_rx_data_wr_addr : unsigned(8 downto 0) := "000000001";
signal tcp_rx_data_rd_addr : unsigned(8 downto 0) := (others => '0');
signal tcp_rx_data_wr_addr_m1 : unsigned(8 downto 0) := (others => '0');
signal tcp_rx_data : unsigned(7 downto 0) := (others => '0');
signal tcp_rx_data_rd_data : std_logic_vector(7 downto 0) := (others => '0');

type ETH_ST is (	IDLE,
						PARSE_COMMAND,
						TRIGGER_DHCP_DISCOVER,
						TRIGGER_ARP_REQUEST,
						TRIGGER_NEW_TCP_CONNECTION,
						TRIGGER_CANCEL_DHCP_CONNECT,
						TRIGGER_CLOSE_TCP_CONNECTION,
						TRIGGER_CANCEL_TCP_CONNECTION,
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
						HANDLE_INIT_CMND6,
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
						HANDLE_TX_INTERRUPT1,
						HANDLE_TX_INTERRUPT2,
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
						PRE_TX_TRANSMIT0,
						PRE_TX_TRANSMIT1,
						HANDLE_TX_TRANSMIT0,
						HANDLE_TX_TRANSMIT1,
						HANDLE_TX_TRANSMIT2,
						HANDLE_TX_TRANSMIT3,
						HANDLE_TX_TRANSMIT4,
						HANDLE_TX_TRANSMIT5,
						HANDLE_TX_TRANSMIT6,
						HANDLE_TX_TRANSMIT7,
						HANDLE_TX_TRANSMIT8,
						HANDLE_TX_TRANSMIT9,
						HANDLE_TX_TRANSMIT10,
						HANDLE_TX_TRANSMIT11,
						HANDLE_TX_TRANSMIT12,
						HANDLE_TX_TRANSMIT13,
						HANDLE_TX_TRANSMIT14,
						HANDLE_TX_TRANSMIT15,
						HANDLE_TX_TRANSMIT16,
						HANDLE_TX_TRANSMIT17);

signal eth_state, eth_next_state : ETH_ST := IDLE;
signal state_debug_sig : unsigned(7 downto 0);

type PACKET_HANDLER_ST is (	IDLE,
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
										HANDLE_ARP_PACKET0,
										HANDLE_ARP_PACKET1,
										HANDLE_ARP_PACKET2,
										HANDLE_ARP_PACKET3,
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
										HANDLE_ARP_REPLY0,
										HANDLE_ARP_REPLY1,
										HANDLE_ARP_REPLY2,
										HANDLE_ARP_REPLY3,
										HANDLE_ARP_REPLY4,
										HANDLE_ARP_REPLY5,
										HANDLE_ARP_REPLY6,
										HANDLE_ARP_REPLY7,
										TRIGGER_ARP_REPLY,
										HANDLE_IP_PACKET0,
										HANDLE_IP_PACKET1,
										HANDLE_IP_PACKET2,
										HANDLE_IP_PACKET3,
										HANDLE_IP_PACKET4,
										HANDLE_IP_PACKET5,
										HANDLE_IP_PACKET6,
										HANDLE_IP_PACKET7,
										HANDLE_IP_PACKET8,
										HANDLE_IP_PACKET9,
										HANDLE_IP_PACKET10,
										HANDLE_IP_PACKET11,
										HANDLE_IP_PACKET12,
										PRE_ICMP_PACKET_REPLY,
										TRIGGER_ICMP_PACKET_REPLY,
										PARSE_UDP_PACKET0,
										PARSE_UDP_PACKET1,
										PARSE_UDP_PACKET2,
										PARSE_UDP_PACKET3,
										PARSE_UDP_PACKET4,
										PARSE_UDP_PACKET5,
										PARSE_UDP_PACKET_TYPE0,
										PARSE_UDP_PACKET_TYPE1,
										PARSE_DHCP_PACKET0,
										PARSE_DHCP_PACKET1,
										PARSE_DHCP_PACKET2,
										PARSE_DHCP_PACKET3,
										PARSE_DHCP_PACKET4,
										PARSE_DHCP_PACKET5,
										PARSE_DHCP_PACKET6,
										PARSE_DHCP_PACKET7,
										PARSE_DHCP_PACKET8,
										PARSE_DHCP_PACKET9,
										PARSE_DHCP_PACKET10,
										PARSE_DHCP_PACKET11,
										PARSE_DHCP_PACKET12,
										PARSE_DHCP_PACKET13,
										PARSE_DHCP_PACKET14,
										PARSE_DHCP_PACKET15,
										PARSE_DHCP_PACKET16,
										PARSE_DHCP_PACKET17,
										PARSE_DHCP_PACKET18,
										PARSE_DHCP_PACKET19,
										PARSE_DHCP_PACKET20,
										PARSE_DHCP_PACKET21,
										PARSE_DHCP_PACKET22,
										PARSE_DHCP_PACKET23,
										PARSE_DHCP_PACKET24,
										CHECK_OFFER_EXPECTED,
										TRIGGER_DHCP_REQUEST,
										HANDLE_DHCP_ACK0,
										HANDLE_DHCP_ACK1,
										HANDLE_DHCP_ACK2,
										HANDLE_DHCP_ACK3,
										HANDLE_DHCP_ACK4,
										HANDLE_DHCP_ACK5,
										HANDLE_DHCP_ACK6,
										HANDLE_DHCP_ACK7,
										HANDLE_DHCP_ACK8,
										PARSE_TCP_PACKET0,
										PARSE_TCP_PACKET1,
										PARSE_TCP_PACKET2,
										PARSE_TCP_PACKET3,
										PARSE_TCP_PACKET4,
										PARSE_TCP_PACKET5,
										PARSE_TCP_PACKET6,
										PARSE_TCP_PACKET7,
										PARSE_TCP_PACKET8,
										PARSE_TCP_PACKET9,
										PARSE_TCP_PACKET10,
										PARSE_TCP_PACKET11,
										PARSE_TCP_PACKET12,
										PARSE_TCP_PACKET13,
										PARSE_TCP_PACKET14,
										PARSE_TCP_PACKET15,
										PARSE_TCP_PACKET16,
										PARSE_TCP_PACKET17,
										PARSE_TCP_PACKET18,
										PARSE_TCP_PACKET19,
										PARSE_TCP_PACKET20,
										PARSE_TCP_PACKET21,
										PARSE_TCP_PACKET22,
										PARSE_TCP_PACKET23,
										PARSE_TCP_PACKET24,
										PARSE_TCP_PACKET25,
										PARSE_TCP_PACKET26,
										PARSE_TCP_PACKET27,
										CHECK_TCP_SYN_ACK_PACKET0,
										CHECK_TCP_SYN_ACK_PACKET1,
										CHECK_TCP_SYN_ACK_PACKET2,
										CHECK_TCP_PSH_ACK_PACKET0,
										CHECK_TCP_PSH_ACK_PACKET1,
										CHECK_TCP_PSH_ACK_PACKET2,
										CHECK_TCP_PSH_ACK_PACKET3,
										CHECK_TCP_PSH_ACK_PACKET4,
										TRIGGER_TCP_ACK,
										COMPLETE
									);
										
signal packet_handler_state, packet_handler_next_state : PACKET_HANDLER_ST := IDLE;					

type TX_PACKET_CONFIG_ST is (	IDLE,
										INIT_ARP_REPLY_METADATA,
										INIT_ARP_REQUEST_METADATA,
										INIT_ICMP_REPLY_METADATA,
										INIT_DHCP_DISCOVER_METADATA,
										INIT_DHCP_REQUEST_METADATA,
										INIT_TCP_PACKET_METADATA,
										CANCEL_DHCP_CONNECT_ST,
										TCP_CONNECTION_CLOSED,
										CANCEL_TCP_CONNECTION_ST,
										READ_PACKET_BYTE0,
										READ_PACKET_BYTE1,
										HANDLE_PACKET_INSTRUCTION0,
										HANDLE_PACKET_INSTRUCTION1,
										SET_RX_PACKET_ADDR_LOWER_BYTE,
										SET_RX_PACKET_ADDR_UPPER_BYTE,
										SET_CHECKSUM_LENGTH_LSB,
										SET_CHECKSUM_LENGTH_MSB,
										SET_CHECKSUM_START_ADDR_LSB,
										SET_CHECKSUM_START_ADDR_MSB,
										SET_CHECKSUM_WR_ADDR_LSB,
										SET_CHECKSUM_WR_ADDR_MSB,
										MOVE_TX_PACKET_WR_ADDR,
										SET_NEW_TRANSACTION_ID,
										SET_CHECKSUM_START_VAL_LSB,
										SET_CHECKSUM_START_VAL_MSB,
										TRIGGER_CHECKSUM_LOAD_INITIAL_VALUE,
										TRIG_CHECKSUM_CALC,
										WAIT_FOR_CHECKSUM_CMPLT,
										COMPLETE
									);
										
signal tx_packet_state, tx_packet_next_state : TX_PACKET_CONFIG_ST := IDLE;

begin
	
	DEBUG_OUT(15 downto 8) <= X"00";
	--DEBUG_OUT <= slv(rx_data_length);
	--DEBUG_OUT <= udp_source_port when DEBUG_IN = '0' else udp_dest_port;
	--DEBUG_OUT <= rx_tcp_source_port when DEBUG_IN = '0' else rx_tcp_dest_port;
	--DEBUG_OUT <= rx_tcp_window_size when DEBUG_IN = '0' else rx_tcp_checksum;
	--DEBUG_OUT(7 downto 0) <= slv(rx_tcp_option_length);
	--DEBUG_OUT <= "00000"&slv(tcp_option_addr);
	--DEBUG_OUT(7 downto 4) <= X"0";
	--DEBUG_OUT(15 downto 8) <= ip_packet_protocol;
	--DEBUG_OUT(15 downto 8) <= rx_tcp_option;
	--DEBUG_OUT <= X"00" & slv(rx_tcp_option) when DEBUG_IN = '0' else rx_tcp_window_shift & slv(rx_tcp_option_length);
	--DEBUG_OUT <= dhcp_option & dhcp_option_length;
	--DEBUG_OUT(7 downto 0) <= slv(init_cmnd_addr);
	--DEBUG_OUT(7 downto 0) <= slv(state_debug_sig);
	DEBUG_OUT(7 downto 0) <= enc28j60_version;
	--DEBUG_OUT(7 downto 0) <= phy_reg_upr;
	--DEBUG_OUT(7 downto 0) <= slv(interrupt_counter);
	--DEBUG_OUT(7 downto 0) <= slv(eir_register);
	--DEBUG_OUT <= spi_wr_addr & spi_wr_data;
	--DEBUG_OUT <= next_packet_pointer;
	--DEBUG_OUT <= rx_packet_status_vector(15 downto 0) when DEBUG_IN = '0' else rx_packet_status_vector(31 downto 16);
	--DEBUG_OUT <= rx_packet_source_mac(15 downto 0) when DEBUG_IN = '0' else rx_packet_source_mac(31 downto 16);
	--DEBUG_OUT <= arp_target_ip_addr(15 downto 0) when DEBUG_IN = '0' else arp_target_ip_addr(31 downto 16);
	--DEBUG_OUT <= arp_source_ip_addr(15 downto 0) when DEBUG_IN = '0' else arp_source_ip_addr(31 downto 16);
	--DEBUG_OUT <= dhcp_your_ip_addr(15 downto 0) when DEBUG_IN = '0' else dhcp_your_ip_addr(31 downto 16);
	--DEBUG_OUT <= server_mac_addr(15 downto 0) when DEBUG_IN = '0' else server_mac_addr(31 downto 16);
	--DEBUG_OUT(7 downto 0) <= rx_packet_rd_data;
	--DEBUG_OUT(7 downto 0) <= tx_packet_rd_data;
	--DEBUG_OUT <= rx_packet_type;
	--DEBUG_OUT <= slv(tx_packet_end_pointer);
	--DEBUG_OUT(3 downto 0) <= ip_packet_version;
	--DEBUG_OUT(7 downto 0) <= X"0"&"0"&debug_rx_flag2&debug_rx_flag1&debug_rx_flag;
	--DEBUG_OUT(15 downto 8) <= slv(state_debug_sig);
	
--	debug_rx_flag1 <= '1' when eth_state = COPY_RX_PACKET_TO_BUF4 else '0';
--	debug_rx_flag2 <= '1' when eth_state = COPY_RX_PACKET_TO_BUF5 else '0';
	
--	debug_state: process(CLK_IN)
--	begin
-- 		if rising_edge(CLK_IN) then
--			case (eth_state) is
--				when COPY_RX_PACKET_TO_BUF4 =>
--					state_debug_sig <= to_unsigned(1, 8);
--				when COPY_RX_PACKET_TO_BUF5 =>
--					state_debug_sig <= to_unsigned(2, 8);
--				when others =>
--					state_debug_sig <= to_unsigned(255, 8);
--			end case;
--		end if;
--	end process;

	COMMAND_CMPLT_OUT <= command_cmplt;
	
	packet_definition_addr <= frame_addr when doing_tx_packet_config = '0' else slv(tx_packet_frame_addr);
	frame_data <= packet_definition_data;
	frame_rd_cmplt <= '1';
	
	--FRAME_DATA_RD_OUT <= frame_data_rd when doing_tx_packet_config = '0' else tx_packet_frame_data_rd;
	
	--frame_data <= FRAME_DATA_IN;
	--frame_rd_cmplt <= FRAME_DATA_RD_CMPLT_IN;

	---- HANDLE COMMANDS ----
	
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

   SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			eth_state <= eth_next_state;
      end if;
   end process;

	NEXT_STATE_DECODE: process (eth_state, command, command_waiting, init_cmnd_addr, poll_interrupt_reg,
											phy_rd_counter, frame_data, tx_packet_ready_from_transmission, spi_oper_cmplt, 
												eir_register, previous_packet_pointer, next_packet_pointer, rx_packet_handled, 
													tx_packet_length_counter)
   begin
      eth_next_state <= eth_state;  --default is to stay in current state
      case (eth_state) is
         when IDLE =>
				if tx_packet_ready_from_transmission = '1' then -- TODO should be "..ready_for_tran.."
					eth_next_state <= PRE_TX_TRANSMIT0;
				elsif int_waiting = '1' then
					eth_next_state <= SERVICE_INTERRUPT0;
				elsif command_waiting = '1' then
					eth_next_state <= PARSE_COMMAND;
				elsif poll_interrupt_reg = '1' then
					eth_next_state <= SERVICE_INTERRUPT0;
				end if;
			when PARSE_COMMAND =>
				if command = X"0" then
					eth_next_state <= READ_PHY_STAT;
				elsif command = X"1" then
					eth_next_state <= READ_DUPLEX_MODE;
				elsif command = X"2" then
					eth_next_state <= READ_VERSION0;
				elsif command = X"3" then
					eth_next_state <= HANDLE_INIT_CMND0;
				elsif command = X"4" then
					eth_next_state <= TRIGGER_DHCP_DISCOVER;
				elsif command = X"5" then
					eth_next_state <= TRIGGER_ARP_REQUEST;
				elsif command = X"6" then
					eth_next_state <= TRIGGER_NEW_TCP_CONNECTION;
				elsif command = X"7" then
					eth_next_state <= TRIGGER_CANCEL_DHCP_CONNECT;
				elsif command = X"8" then
					eth_next_state <= TRIGGER_CLOSE_TCP_CONNECTION;
				elsif command = X"9" then
					eth_next_state <= TRIGGER_CANCEL_TCP_CONNECTION;
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
						eth_next_state <= HANDLE_INIT_CMND6;
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
					eth_next_state <= HANDLE_INIT_CMND6;
				else
					eth_next_state <= HANDLE_INIT_CMND1;
				end if;
			when HANDLE_INIT_CMND6 =>
				eth_next_state <= IDLE;
			
			when TRIGGER_DHCP_DISCOVER =>
				eth_next_state <= IDLE;
			when TRIGGER_ARP_REQUEST =>
				eth_next_state <= IDLE;
			when TRIGGER_NEW_TCP_CONNECTION =>
				eth_next_state <= IDLE;
			when TRIGGER_CANCEL_DHCP_CONNECT =>
				eth_next_state <= IDLE;
			when TRIGGER_CLOSE_TCP_CONNECTION =>
				eth_next_state <= IDLE;
			when TRIGGER_CANCEL_TCP_CONNECTION =>
				eth_next_state <= IDLE;
			
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
				else
					eth_next_state <= SERVICE_INTERRUPT6;
				end if;
			when HANDLE_TX_INTERRUPT0 =>
				eth_next_state <= HANDLE_TX_INTERRUPT1;
			when HANDLE_TX_INTERRUPT1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_INTERRUPT2;
				end if;
			when HANDLE_TX_INTERRUPT2 =>
				eth_next_state <= SERVICE_INTERRUPT6;
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

			when PRE_TX_TRANSMIT0 =>
				eth_next_state <= PRE_TX_TRANSMIT1;
			when PRE_TX_TRANSMIT1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT0;
				end if;
			when HANDLE_TX_TRANSMIT0 =>
				eth_next_state <= HANDLE_TX_TRANSMIT1;
			when HANDLE_TX_TRANSMIT1 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT2;
				end if;
			when HANDLE_TX_TRANSMIT2 =>
				eth_next_state <= HANDLE_TX_TRANSMIT3;
			when HANDLE_TX_TRANSMIT3 =>
				if spi_oper_cmplt = '1' then	-- TODO Remove all spi_oper_cmplt
					eth_next_state <= HANDLE_TX_TRANSMIT4;
				end if;
			when HANDLE_TX_TRANSMIT4 =>
				eth_next_state <= HANDLE_TX_TRANSMIT5;
			when HANDLE_TX_TRANSMIT5 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT6;
				end if;
			when HANDLE_TX_TRANSMIT6 =>
				eth_next_state <= HANDLE_TX_TRANSMIT7;
			when HANDLE_TX_TRANSMIT7 =>
				if tx_packet_length_counter = X"0000" then
					eth_next_state <= HANDLE_TX_TRANSMIT11;
				else
					eth_next_state <= HANDLE_TX_TRANSMIT8;
				end if;
			when HANDLE_TX_TRANSMIT8 =>
				eth_next_state <= HANDLE_TX_TRANSMIT9;
			when HANDLE_TX_TRANSMIT9 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT10;
				end if;
			when HANDLE_TX_TRANSMIT10 =>
				eth_next_state <= HANDLE_TX_TRANSMIT6;
			when HANDLE_TX_TRANSMIT11 =>
				eth_next_state <= HANDLE_TX_TRANSMIT12;
			when HANDLE_TX_TRANSMIT12 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT13;
				end if;
			when HANDLE_TX_TRANSMIT13 =>
				eth_next_state <= HANDLE_TX_TRANSMIT14;
			when HANDLE_TX_TRANSMIT14 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT15;
				end if;
			when HANDLE_TX_TRANSMIT15 =>
				eth_next_state <= HANDLE_TX_TRANSMIT16;
			when HANDLE_TX_TRANSMIT16 =>
				if spi_oper_cmplt = '1' then
					eth_next_state <= HANDLE_TX_TRANSMIT17;
				end if;
			when HANDLE_TX_TRANSMIT17 =>
				eth_next_state <= IDLE;
				
		end case;
	end process;
	
	POLL_INT_PROC :process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			poll_counter <= poll_counter - 1;
			if poll_counter = X"0" then
				poll_interrupt_reg <= '1';
			else
				poll_interrupt_reg <= '0';
			end if;
		end if;
	end process;
	
	TX_PACKET_LENGTH_PROC :process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if eth_state = HANDLE_TX_TRANSMIT5 then
				tx_packet_length_counter <= tx_packet_length;
			elsif eth_state = HANDLE_TX_TRANSMIT10 then
				tx_packet_length_counter <= tx_packet_length_counter - 1;
			end if;
			if eth_state = HANDLE_TX_TRANSMIT5 then
				tx_packet_ram_rd_addr <= "00000000000";
			elsif eth_state = HANDLE_TX_TRANSMIT10 then
				tx_packet_ram_rd_addr <= tx_packet_ram_rd_addr + 1;
			end if;
--			if DEBUG_IN = '1' then
--				tx_packet_ram_rd_addr <= tx_packet_ram_rd_addr + 1;
--			end if;
		end if;
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
				frame_addr <= X"0" & slv(init_cmnd_addr);
			end if;
      end if;
   end process;
	
	SETTINGS_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_INIT_CMND0 then
				network_interface_enabled <= '0';
			elsif eth_state = HANDLE_INIT_CMND6 then
				network_interface_enabled <= '1'; -- TODO add disable code
			end if;
		end if;
	end process;
	
--	FRAME_RD_PROC: process(CLK_IN)
--   begin
--      if rising_edge(CLK_IN) then
--			if eth_state = HANDLE_INIT_CMND1 then
--				frame_data_rd <= '1';
--			else
--				frame_data_rd <= '0';
--			end if;
--      end if;
--   end process;

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
			elsif eth_state = HANDLE_TX_INTERRUPT0 then
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
			elsif eth_state = PRE_TX_TRANSMIT0 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT0 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT2 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT4 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT8 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT11 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT13 then
				spi_we <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT15 then
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
			elsif eth_state = HANDLE_TX_INTERRUPT0 then
				spi_wr_addr <= X"BC";
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
			elsif eth_state = PRE_TX_TRANSMIT0 then
				spi_wr_addr <= X"BF";
			elsif eth_state = HANDLE_TX_TRANSMIT0 then
				spi_wr_addr <= X"42";
			elsif eth_state = HANDLE_TX_TRANSMIT2 then
				spi_wr_addr <= X"43";
			elsif eth_state = HANDLE_TX_TRANSMIT4 then
				spi_wr_addr <= X"7A";
			elsif eth_state = HANDLE_TX_TRANSMIT8 then
				spi_wr_addr <= X"7A";
			elsif eth_state = HANDLE_TX_TRANSMIT11 then
				spi_wr_addr <= X"46";
			elsif eth_state = HANDLE_TX_TRANSMIT13 then
				spi_wr_addr <= X"47";
			elsif eth_state = HANDLE_TX_TRANSMIT15 then
				spi_wr_addr <= X"9F";
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
			elsif eth_state = HANDLE_TX_INTERRUPT0 then
				spi_wr_data <= X"08";
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
			elsif eth_state = PRE_TX_TRANSMIT0 then
				spi_wr_data <= X"03";
			elsif eth_state = HANDLE_TX_TRANSMIT0 then
				spi_wr_data <= X"00";
			elsif eth_state = HANDLE_TX_TRANSMIT2 then
				spi_wr_data <= X"10";
			elsif eth_state = HANDLE_TX_TRANSMIT4 then
				spi_wr_data <= X"00";
			elsif eth_state = HANDLE_TX_TRANSMIT8 then
				spi_wr_data <= tx_packet_rd_data;
			elsif eth_state = HANDLE_TX_TRANSMIT11 then
				spi_wr_data <= slv(tx_packet_end_pointer(7 downto 0));
			elsif eth_state = HANDLE_TX_TRANSMIT13 then
				spi_wr_data <= slv(tx_packet_end_pointer(15 downto 8));
			elsif eth_state = HANDLE_TX_TRANSMIT15 then
				spi_wr_data <= X"08";
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

	COMMAND_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			command_en_in_p <= COMMAND_EN_IN;
			if command_en_in_p = '0' and COMMAND_EN_IN = '1' then
				command_trig <= '1';
			else
				command_trig <= '0';
			end if;
			if command_trig = '1' then
				command_waiting <= '1';
			elsif eth_state = PARSE_COMMAND then
				command_waiting <= '0';
			end if;
			if command_trig = '1' then
				command <= COMMAND_IN;
			end if;
		end if;
	end process;

	INT_DEBUG_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_RX_INTERRUPT0 then
				interrupt_counter <= interrupt_counter + 1;
			end if;
		end if;
	end process;

------------------------- RX PACKET --------------------------------

	handle_rx_packet <= '1' when eth_state = COPY_RX_PACKET_TO_BUF5 else '0';
	
	process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = HANDLE_RX_INTERRUPT0 then
				debug_rx_flag <= '1';
			elsif eth_state = HANDLE_RX_INTERRUPT17 then
				debug_rx_flag <= '0';
			end if;
		end if;
	end process;

	RX_PACKET_WR_ADDR: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if eth_state = COPY_RX_PACKET_TO_BUF0 then
				rx_packet_ram_we_addr_buf <= "00000000000";
			elsif eth_state = COPY_RX_PACKET_TO_BUF3 then
				rx_packet_ram_we_addr_buf <= rx_packet_ram_we_addr_buf + 1;
			end if;
			if eth_state = HANDLE_RX_INTERRUPT5 then
				previous_packet_pointer <= unsigned(next_packet_pointer);
			elsif eth_state = COPY_RX_PACKET_TO_BUF3 then
				if previous_packet_pointer = C_rx_pointer_max then
					previous_packet_pointer <= C_rx_pointer_min;
				else
					previous_packet_pointer <= previous_packet_pointer + 1;
				end if;
			end if;
		end if;
	end process;

	rx_packet_ram_we <= '1' when eth_state = COPY_RX_PACKET_TO_BUF3 else '0';
	rx_packet_ram_we_addr <= rx_packet_ram_we_addr_buf when doing_tx_packet_config = '0' else rx_packet_rd2_addr;

	RX_PACKET_RAM : TDP_RAM
		Generic Map (	G_DATA_A_SIZE 	=> spi_data_rd'length,
							G_ADDR_A_SIZE	=> rx_packet_ram_we_addr'length,
							G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
							G_INIT_ZERO		=> true,
							G_INIT_FILE		=> "")
		Port Map ( CLK_A_IN 	=> CLK_IN,
				 WE_A_IN 		=> rx_packet_ram_we,
				 ADDR_A_IN 		=> slv(rx_packet_ram_we_addr),
				 DATA_A_IN		=> spi_data_rd,
				 DATA_A_OUT		=> rx_packet_rd_data2,
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
	send_arp_request <= '1' when eth_state = TRIGGER_ARP_REQUEST else '0';
	
	send_icmp_reply <= '1' when packet_handler_state = TRIGGER_ICMP_PACKET_REPLY else '0';
	
	send_dhcp_discover <= '1' when eth_state = TRIGGER_DHCP_DISCOVER else '0';
	send_dhcp_request <= '1' when packet_handler_state = TRIGGER_DHCP_REQUEST else '0';
	send_tcp_svn_packet <= '1' when eth_state = TRIGGER_NEW_TCP_CONNECTION else '0';
	send_tcp_ack_packet <= '1' when packet_handler_state = TRIGGER_TCP_ACK else '0';
	cancel_dhcp_connect <= '1' when eth_state = TRIGGER_CANCEL_DHCP_CONNECT else '0';
	close_tcp_connection <= '1' when eth_state = TRIGGER_CLOSE_TCP_CONNECTION else '0';
	cancel_tcp_connection <= '1' when eth_state = TRIGGER_CANCEL_TCP_CONNECTION else '0';

	PH_NEXT_STATE_DECODE: process (packet_handler_state, handle_rx_packet, rx_packet_status_vector(23), rx_tcp_flags, 
												rx_packet_type, arp_target_ip_addr, rx_tcp_option, tcp_option_addr, total_packet_length,
													rx_tcp_option_length, arp_opcode, expecting_arp_reply, ip_addr, tx_packet_config_cmplt,
														ip_packet_version, ip_packet_destination_ip, dhcp_enable, dhcp_addr_locked, ip_packet_protocol,
															ip_packet_length, udp_source_port, udp_dest_port, dhcp_transaction_id, transaction_id_rd,
																dhcp_magic_cookie, dhcp_option, dhcp_option_length, dhcp_option_addr, expecting_syn_ack,
																	dhcp_message_type, expecting_dhcp_offer, expecting_dhcp_ack, rx_tcp_source_port,
																		server_port, rx_tcp_dest_port, tcp_port, ping_enable, rx_tcp_header_length, tcp_sequence_number_p1, 
																			rx_tcp_ack_number, tcp_sequence_number, tcp_acknowledge_number, rx_tcp_seq_number, rx_packet_ram_rd_addr)
   begin
      packet_handler_next_state <= packet_handler_state;  --default is to stay in current state
      case (packet_handler_state) is
         when IDLE =>
				if handle_rx_packet = '1' then
					packet_handler_next_state <= PARSE_SOURCE_MAC0;
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
					packet_handler_next_state <= HANDLE_ARP_PACKET0;
				elsif rx_packet_type = C_IP_Packet_Type then
					packet_handler_next_state <= HANDLE_IP_PACKET0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			
			when HANDLE_ARP_PACKET0 =>
				packet_handler_next_state <= HANDLE_ARP_PACKET1;
			when HANDLE_ARP_PACKET1 =>
				packet_handler_next_state <= HANDLE_ARP_PACKET2;
			when HANDLE_ARP_PACKET2 =>
				packet_handler_next_state <= HANDLE_ARP_PACKET3;
			when HANDLE_ARP_PACKET3 =>
				if arp_opcode = C_ARP_Request then
					packet_handler_next_state <= HANDLE_ARP_REQUEST0;
				elsif arp_opcode = C_ARP_Reply then
					packet_handler_next_state <= HANDLE_ARP_REPLY0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
				
			when HANDLE_ARP_REPLY0 =>
				if expecting_arp_reply = '1' then
					packet_handler_next_state <= HANDLE_ARP_REPLY1;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when HANDLE_ARP_REPLY1 =>
				packet_handler_next_state <= HANDLE_ARP_REPLY2;
			when HANDLE_ARP_REPLY2 =>
				packet_handler_next_state <= HANDLE_ARP_REPLY3;	
			when HANDLE_ARP_REPLY3 =>
				packet_handler_next_state <= HANDLE_ARP_REPLY4;
			when HANDLE_ARP_REPLY4 =>
				packet_handler_next_state <= HANDLE_ARP_REPLY5;
			when HANDLE_ARP_REPLY5 =>
				packet_handler_next_state <= HANDLE_ARP_REPLY6;
			when HANDLE_ARP_REPLY6 =>
				packet_handler_next_state <= HANDLE_ARP_REPLY7;
			when HANDLE_ARP_REPLY7 =>
				packet_handler_next_state <= COMPLETE;
			
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
				if tx_packet_config_cmplt = '1' then
					packet_handler_next_state <= COMPLETE;
				end if;
				
			when HANDLE_IP_PACKET0 =>
				packet_handler_next_state <= HANDLE_IP_PACKET1;
			when HANDLE_IP_PACKET1 =>
				packet_handler_next_state <= HANDLE_IP_PACKET2;
			when HANDLE_IP_PACKET2 =>
				packet_handler_next_state <= HANDLE_IP_PACKET3;
			when HANDLE_IP_PACKET3 =>
				packet_handler_next_state <= HANDLE_IP_PACKET4;
			when HANDLE_IP_PACKET4 =>
				packet_handler_next_state <= HANDLE_IP_PACKET5;
			when HANDLE_IP_PACKET5 =>
				packet_handler_next_state <= HANDLE_IP_PACKET6;
			when HANDLE_IP_PACKET6 =>
				packet_handler_next_state <= HANDLE_IP_PACKET7;
			when HANDLE_IP_PACKET7 =>
				packet_handler_next_state <= HANDLE_IP_PACKET8;
			when HANDLE_IP_PACKET8 =>
				packet_handler_next_state <= HANDLE_IP_PACKET9;
			when HANDLE_IP_PACKET9 =>
				packet_handler_next_state <= HANDLE_IP_PACKET10;
			when HANDLE_IP_PACKET10 =>
				if ip_packet_version = C_IPV4_Protocol_Number then
					packet_handler_next_state <= HANDLE_IP_PACKET11;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when HANDLE_IP_PACKET11 =>
				if ip_packet_destination_ip = ip_addr then
					packet_handler_next_state <= HANDLE_IP_PACKET12;
				elsif dhcp_enable = '1' and dhcp_addr_locked = '0' then
					packet_handler_next_state <= HANDLE_IP_PACKET12;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when HANDLE_IP_PACKET12 =>
				if ip_packet_protocol = C_ICMP_Protocol_Number then
					packet_handler_next_state <= PRE_ICMP_PACKET_REPLY;
				elsif ip_packet_protocol = C_UDP_Protocol_Number then
					packet_handler_next_state <= PARSE_UDP_PACKET0;
				elsif ip_packet_protocol = C_TCP_Protocol_Number then
					packet_handler_next_state <= PARSE_TCP_PACKET0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			
			when PRE_ICMP_PACKET_REPLY =>
				if ip_packet_length = C_ICMP_Ping_Length and ping_enable = '1' then
					packet_handler_next_state <= TRIGGER_ICMP_PACKET_REPLY;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when TRIGGER_ICMP_PACKET_REPLY =>
				if tx_packet_config_cmplt = '1' then
					packet_handler_next_state <= COMPLETE;
				end if;
				
			when PARSE_UDP_PACKET0 =>
				packet_handler_next_state <= PARSE_UDP_PACKET1;
			when PARSE_UDP_PACKET1 =>
				packet_handler_next_state <= PARSE_UDP_PACKET2;
			when PARSE_UDP_PACKET2 =>
				packet_handler_next_state <= PARSE_UDP_PACKET3;
			when PARSE_UDP_PACKET3 =>
				packet_handler_next_state <= PARSE_UDP_PACKET4;
			when PARSE_UDP_PACKET4 =>
				packet_handler_next_state <= PARSE_UDP_PACKET5;
			when PARSE_UDP_PACKET5 =>
				packet_handler_next_state <= PARSE_UDP_PACKET_TYPE0;
			when PARSE_UDP_PACKET_TYPE0 =>
				if udp_source_port = C_DHCP_Source_Port then
					packet_handler_next_state <= PARSE_UDP_PACKET_TYPE1;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when PARSE_UDP_PACKET_TYPE1 =>
				if udp_dest_port = C_DHCP_Dest_Port then
					packet_handler_next_state <= PARSE_DHCP_PACKET0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
				
			when PARSE_DHCP_PACKET0 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET1;
			when PARSE_DHCP_PACKET1 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET2;
			when PARSE_DHCP_PACKET2 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET3;
			when PARSE_DHCP_PACKET3 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET4;
			when PARSE_DHCP_PACKET4 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET5;
			when PARSE_DHCP_PACKET5 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET6;
			when PARSE_DHCP_PACKET6 =>
				if dhcp_transaction_id = transaction_id_rd then
					packet_handler_next_state <= PARSE_DHCP_PACKET7;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when PARSE_DHCP_PACKET7 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET8;
			when PARSE_DHCP_PACKET8 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET9;
			when PARSE_DHCP_PACKET9 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET10;
			when PARSE_DHCP_PACKET10 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET11;
			when PARSE_DHCP_PACKET11 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET12;
			when PARSE_DHCP_PACKET12 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET13;
			when PARSE_DHCP_PACKET13 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET14;
			when PARSE_DHCP_PACKET14 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET15;
			when PARSE_DHCP_PACKET15 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET16;
			when PARSE_DHCP_PACKET16 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET17;
			when PARSE_DHCP_PACKET17 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET18;
			when PARSE_DHCP_PACKET18 =>
				if C_dhcp_magic_cookie = dhcp_magic_cookie then
					packet_handler_next_state <= PARSE_DHCP_PACKET19;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			
			when PARSE_DHCP_PACKET19 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET20;
			when PARSE_DHCP_PACKET20 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET21;
			when PARSE_DHCP_PACKET21 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET22;
			when PARSE_DHCP_PACKET22 =>
				packet_handler_next_state <= PARSE_DHCP_PACKET23;
			when PARSE_DHCP_PACKET23 =>
				if dhcp_option = X"35" and dhcp_option_length = X"01" then
					packet_handler_next_state <= PARSE_DHCP_PACKET24;
				elsif dhcp_option = X"FF" then
					packet_handler_next_state <= COMPLETE;
				elsif RESIZE(dhcp_option_addr, 16) > total_packet_length then
					packet_handler_next_state <= COMPLETE;
				else
					packet_handler_next_state <= PARSE_DHCP_PACKET19;
				end if;
			when PARSE_DHCP_PACKET24 =>
				if dhcp_message_type = X"02" then -- dhcp offer
					packet_handler_next_state <= CHECK_OFFER_EXPECTED;
				elsif dhcp_message_type = X"04" then -- dhcp decline
					packet_handler_next_state <= COMPLETE;
				elsif dhcp_message_type = X"05" then -- dhcp acknowledge
					packet_handler_next_state <= HANDLE_DHCP_ACK0;
				elsif dhcp_message_type = X"06" then -- dhcp negative acknowledge
					packet_handler_next_state <= COMPLETE;
				elsif dhcp_message_type = X"07" then -- dhcp release
					packet_handler_next_state <= COMPLETE;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			
			when CHECK_OFFER_EXPECTED =>
				if expecting_dhcp_offer = '1' then
					packet_handler_next_state <= TRIGGER_DHCP_REQUEST;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when TRIGGER_DHCP_REQUEST =>
				if tx_packet_config_cmplt = '1' then
					packet_handler_next_state <= COMPLETE;
				end if;
			
			when HANDLE_DHCP_ACK0 =>
				if expecting_dhcp_ack = '1' then
					packet_handler_next_state <= HANDLE_DHCP_ACK1;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when HANDLE_DHCP_ACK1 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK2;
			when HANDLE_DHCP_ACK2 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK3;
			when HANDLE_DHCP_ACK3 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK4;
			when HANDLE_DHCP_ACK4 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK5;
			when HANDLE_DHCP_ACK5 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK6;
			when HANDLE_DHCP_ACK6 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK7;
			when HANDLE_DHCP_ACK7 =>
				packet_handler_next_state <= HANDLE_DHCP_ACK8;
			when HANDLE_DHCP_ACK8 =>
				packet_handler_next_state <= COMPLETE;
			
			when PARSE_TCP_PACKET0 =>
				packet_handler_next_state <= PARSE_TCP_PACKET1;
			when PARSE_TCP_PACKET1 =>
				packet_handler_next_state <= PARSE_TCP_PACKET2;
			when PARSE_TCP_PACKET2 =>
				packet_handler_next_state <= PARSE_TCP_PACKET3;
			when PARSE_TCP_PACKET3 =>
				packet_handler_next_state <= PARSE_TCP_PACKET4;
			when PARSE_TCP_PACKET4 =>
				packet_handler_next_state <= PARSE_TCP_PACKET5;
			when PARSE_TCP_PACKET5 =>
				if rx_tcp_source_port = server_port then
					packet_handler_next_state <= PARSE_TCP_PACKET6;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when PARSE_TCP_PACKET6 =>
				if rx_tcp_dest_port = tcp_port then
					packet_handler_next_state <= PARSE_TCP_PACKET7;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when PARSE_TCP_PACKET7 =>
				packet_handler_next_state <= PARSE_TCP_PACKET8;
			when PARSE_TCP_PACKET8 =>
				packet_handler_next_state <= PARSE_TCP_PACKET9;
			when PARSE_TCP_PACKET9 =>
				packet_handler_next_state <= PARSE_TCP_PACKET10;
			when PARSE_TCP_PACKET10 =>
				packet_handler_next_state <= PARSE_TCP_PACKET11;
			when PARSE_TCP_PACKET11 =>
				packet_handler_next_state <= PARSE_TCP_PACKET12;
			when PARSE_TCP_PACKET12 =>
				packet_handler_next_state <= PARSE_TCP_PACKET13;
			when PARSE_TCP_PACKET13 =>
				packet_handler_next_state <= PARSE_TCP_PACKET14;
			when PARSE_TCP_PACKET14 =>
				packet_handler_next_state <= PARSE_TCP_PACKET15;
			when PARSE_TCP_PACKET15 =>
				packet_handler_next_state <= PARSE_TCP_PACKET16;
			when PARSE_TCP_PACKET16 =>
				packet_handler_next_state <= PARSE_TCP_PACKET17;
			when PARSE_TCP_PACKET17 =>
				packet_handler_next_state <= PARSE_TCP_PACKET18;
			when PARSE_TCP_PACKET18 =>
				packet_handler_next_state <= PARSE_TCP_PACKET19;	
			when PARSE_TCP_PACKET19 =>
				if rx_tcp_flags(4 downto 0) = "1"&X"2" then -- SYN-ACK PACKET (READ OPTIONS)
					packet_handler_next_state <= PARSE_TCP_PACKET20;
				else
					packet_handler_next_state <= PARSE_TCP_PACKET25;
				end if;
			when PARSE_TCP_PACKET20 =>
				packet_handler_next_state <= PARSE_TCP_PACKET21;
			when PARSE_TCP_PACKET21 =>
				packet_handler_next_state <= PARSE_TCP_PACKET22;
			when PARSE_TCP_PACKET22 =>
				packet_handler_next_state <= PARSE_TCP_PACKET23;
			when PARSE_TCP_PACKET23 =>
				packet_handler_next_state <= PARSE_TCP_PACKET24;
			when PARSE_TCP_PACKET24 =>
				if rx_tcp_option = X"03" then
					packet_handler_next_state <= PARSE_TCP_PACKET25;
				elsif rx_tcp_option = X"01" then
					packet_handler_next_state <= PARSE_TCP_PACKET26;
				elsif RESIZE(tcp_option_addr, 16) > total_packet_length then
					packet_handler_next_state <= COMPLETE;
				else
					packet_handler_next_state <= PARSE_TCP_PACKET27;
				end if;
			when PARSE_TCP_PACKET25 =>
				if rx_tcp_flags(4 downto 0) = "1"&X"2" and expecting_syn_ack = '1' then
					packet_handler_next_state <= CHECK_TCP_SYN_ACK_PACKET0;
				elsif rx_tcp_flags(4 downto 0) = "1"&X"8" or rx_tcp_flags(4 downto 0) = "1"&X"0" then -- TODO look at data sent?
					packet_handler_next_state <= CHECK_TCP_PSH_ACK_PACKET0;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when PARSE_TCP_PACKET26 =>
				packet_handler_next_state <= PARSE_TCP_PACKET20;
			when PARSE_TCP_PACKET27 =>
				if rx_tcp_option_length = X"00" then
					packet_handler_next_state <= COMPLETE;
				else
					packet_handler_next_state <= PARSE_TCP_PACKET20;
				end if;
			when CHECK_TCP_SYN_ACK_PACKET0 =>
				packet_handler_next_state <= CHECK_TCP_SYN_ACK_PACKET1;
			when CHECK_TCP_SYN_ACK_PACKET1 =>
				if tcp_sequence_number_p1 = unsigned(rx_tcp_ack_number) then
					packet_handler_next_state <= CHECK_TCP_SYN_ACK_PACKET2;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when CHECK_TCP_SYN_ACK_PACKET2 =>
				packet_handler_next_state <= TRIGGER_TCP_ACK;
				
			when CHECK_TCP_PSH_ACK_PACKET0 =>
				if tcp_sequence_number = unsigned(rx_tcp_ack_number) then
					packet_handler_next_state <= CHECK_TCP_PSH_ACK_PACKET1;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when CHECK_TCP_PSH_ACK_PACKET1 =>
				if tcp_acknowledge_number = unsigned(rx_tcp_seq_number) then
					packet_handler_next_state <= CHECK_TCP_PSH_ACK_PACKET2;
				else
					packet_handler_next_state <= COMPLETE;
				end if;
			when CHECK_TCP_PSH_ACK_PACKET2 =>
				packet_handler_next_state <= CHECK_TCP_PSH_ACK_PACKET3;
			when CHECK_TCP_PSH_ACK_PACKET3 =>
				packet_handler_next_state <= CHECK_TCP_PSH_ACK_PACKET4;
			when CHECK_TCP_PSH_ACK_PACKET4 =>
				if RESIZE(rx_packet_ram_rd_addr, 16) >= total_packet_length then
					packet_handler_next_state <= TRIGGER_TCP_ACK;
				end if;
				
			when TRIGGER_TCP_ACK =>
				if tx_packet_state = INIT_TCP_PACKET_METADATA then
					packet_handler_next_state <= COMPLETE;
				end if;
				
			when COMPLETE =>
				packet_handler_next_state <= IDLE;
				
		end case;
	end process;

	RX_PACKET_RD_ADDR: process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if packet_handler_state = PARSE_SOURCE_MAC0 then
				rx_packet_ram_rd_addr <= "000"&X"0A";
			elsif packet_handler_state = PARSE_PACKET_TYPE0 then
				rx_packet_ram_rd_addr <= "000"&X"10";
			elsif packet_handler_state = HANDLE_ARP_REQUEST0 then
				rx_packet_ram_rd_addr <= "000"&X"2A";
			elsif packet_handler_state = HANDLE_ARP_REQUEST7 then
				rx_packet_ram_rd_addr <= "000"&X"20";
			elsif packet_handler_state = HANDLE_IP_PACKET0 then
				rx_packet_ram_rd_addr <= "000"&X"12";
			elsif packet_handler_state = HANDLE_IP_PACKET1 then
				rx_packet_ram_rd_addr <= "000"&X"1B";
			elsif packet_handler_state = HANDLE_IP_PACKET2 then
				rx_packet_ram_rd_addr <= "000"&X"22";
			elsif packet_handler_state = HANDLE_IP_PACKET6 then
				rx_packet_ram_rd_addr <= "000"&X"14";
			elsif packet_handler_state = PARSE_UDP_PACKET0 then
				rx_packet_ram_rd_addr <= "000"&X"26";
			elsif packet_handler_state = PARSE_DHCP_PACKET0 then
				rx_packet_ram_rd_addr <= "000"&X"32";
			elsif packet_handler_state = PARSE_DHCP_PACKET4 then
				rx_packet_ram_rd_addr <= "000"&X"3E";
			elsif packet_handler_state = PARSE_DHCP_PACKET12 then
				rx_packet_ram_rd_addr <= "001"&X"1A";
			elsif packet_handler_state = PARSE_DHCP_PACKET19 then
				rx_packet_ram_rd_addr <= dhcp_option_addr;
			elsif packet_handler_state = HANDLE_ARP_PACKET0 then
				rx_packet_ram_rd_addr <= "000"&X"19";
			elsif packet_handler_state = HANDLE_ARP_REPLY0 then
				rx_packet_ram_rd_addr <= "000"&X"1A";
			elsif packet_handler_state = PARSE_TCP_PACKET0 then
				rx_packet_ram_rd_addr <= next_protocol_start_addr;
			elsif packet_handler_state = PARSE_TCP_PACKET20 then
				rx_packet_ram_rd_addr <= tcp_option_addr;
			elsif packet_handler_state = CHECK_TCP_PSH_ACK_PACKET2 then
				rx_packet_ram_rd_addr <= "000"&X"3A";
			elsif packet_handler_state = HANDLE_DHCP_ACK1 then
				rx_packet_ram_rd_addr <= "000"&X"0A";
			else
				rx_packet_ram_rd_addr <= rx_packet_ram_rd_addr + 1;
			end if;
			if packet_handler_state = HANDLE_ARP_PACKET2 then
				arp_opcode <= rx_packet_rd_data;
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
			if packet_handler_state = HANDLE_IP_PACKET2 then
				ip_packet_version <= rx_packet_rd_data(7 downto 4);
			end if;
			if packet_handler_state = HANDLE_IP_PACKET3 then
				ip_packet_protocol <= rx_packet_rd_data;
			end if;
			if packet_handler_state = HANDLE_IP_PACKET2 then
				ip_packet_header_length(3 downto 0) <= rx_packet_rd_data(3 downto 0);
				ip_packet_header_length(7 downto 4) <= X"0";
			elsif packet_handler_state = HANDLE_IP_PACKET3 then
				ip_packet_header_length <= ip_packet_header_length(5 downto 0) & "00";
			end if;
			if packet_handler_state = HANDLE_IP_PACKET4 then
				next_protocol_start_addr <= RESIZE(unsigned(ip_packet_header_length), 11) + "00000010010"; -- src/dest mac + protocol + status reg (4 bytes)
			end if;
			if packet_handler_state = HANDLE_IP_PACKET4 then
				ip_packet_destination_ip(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_IP_PACKET5 then
				ip_packet_destination_ip(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_IP_PACKET6 then
				ip_packet_destination_ip(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_IP_PACKET7 then
				ip_packet_destination_ip(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = HANDLE_IP_PACKET8 then
				ip_packet_length(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = HANDLE_IP_PACKET9 then
				ip_packet_length(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = HANDLE_IP_PACKET10 then -- TODO Rename ip_packet_length ?
				total_packet_length <= unsigned(ip_packet_length) + X"0012"; -- src/dest mac + protocol + status reg (4 bytes)
			end if;
			if packet_handler_state = PARSE_UDP_PACKET2 then
				udp_source_port(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_UDP_PACKET3 then
				udp_source_port(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_UDP_PACKET4 then
				udp_dest_port(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_UDP_PACKET5 then
				udp_dest_port(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET2 then
				transaction_id_rd(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET3 then
				transaction_id_rd(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET4 then
				transaction_id_rd(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET5 then
				transaction_id_rd(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET6 then
				dhcp_your_ip_addr(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET7 then
				dhcp_your_ip_addr(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET8 then
				dhcp_your_ip_addr(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET9 then
				dhcp_your_ip_addr(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET10 then
				dhcp_server_ip_addr(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET11 then
				dhcp_server_ip_addr(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET12 then
				dhcp_server_ip_addr(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET13 then
				dhcp_server_ip_addr(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET14 then
				dhcp_magic_cookie(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET15 then
				dhcp_magic_cookie(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET16 then
				dhcp_magic_cookie(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_DHCP_PACKET17 then
				dhcp_magic_cookie(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET21 then
				dhcp_option <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET22 then
				dhcp_option_length <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET18 then
				dhcp_option_addr <= "001"&X"1E";
			elsif packet_handler_state = PARSE_DHCP_PACKET23 then
				dhcp_option_addr <= dhcp_option_addr + RESIZE(unsigned(dhcp_option_length), 11);
			end if;
			if packet_handler_state = PARSE_DHCP_PACKET23 then
				dhcp_message_type <= rx_packet_rd_data;
			end if;
			if (packet_handler_state = HANDLE_ARP_REPLY2) or (packet_handler_state = HANDLE_DHCP_ACK3) then
				server_mac_addr(47 downto 40) <= rx_packet_rd_data;
			elsif (packet_handler_state = HANDLE_ARP_REPLY3) or (packet_handler_state = HANDLE_DHCP_ACK4) then
				server_mac_addr(39 downto 32) <= rx_packet_rd_data;
			elsif (packet_handler_state = HANDLE_ARP_REPLY4) or (packet_handler_state = HANDLE_DHCP_ACK5) then
				server_mac_addr(31 downto 24) <= rx_packet_rd_data;
			elsif (packet_handler_state = HANDLE_ARP_REPLY5) or (packet_handler_state = HANDLE_DHCP_ACK6) then
				server_mac_addr(23 downto 16) <= rx_packet_rd_data;
			elsif (packet_handler_state = HANDLE_ARP_REPLY6) or (packet_handler_state = HANDLE_DHCP_ACK7) then
				server_mac_addr(15 downto 8) <= rx_packet_rd_data;
			elsif (packet_handler_state = HANDLE_ARP_REPLY7) or (packet_handler_state = HANDLE_DHCP_ACK8) then
				server_mac_addr(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET2 then
				rx_tcp_source_port(15 downto 8) <= rx_packet_rd_data; 
			elsif packet_handler_state = PARSE_TCP_PACKET3 then
				rx_tcp_source_port(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET4 then
				rx_tcp_dest_port(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET5 then
				rx_tcp_dest_port(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET6 then
				rx_tcp_seq_number(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET7 then
				rx_tcp_seq_number(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET8 then
				rx_tcp_seq_number(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET9 then
				rx_tcp_seq_number(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET10 then
				rx_tcp_ack_number(31 downto 24) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET11 then
				rx_tcp_ack_number(23 downto 16) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET12 then
				rx_tcp_ack_number(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET13 then
				rx_tcp_ack_number(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET14 then
				rx_tcp_header_length <= "00"&rx_packet_rd_data(7 downto 2);
			end if;
			if packet_handler_state = PARSE_TCP_PACKET15 then
				rx_tcp_flags <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET14 then
				rx_data_length <= unsigned(ip_packet_length);
			elsif packet_handler_state = PARSE_TCP_PACKET15 then
				rx_data_length <= rx_data_length - RESIZE(unsigned(rx_tcp_header_length), 16);
			elsif packet_handler_state = PARSE_TCP_PACKET16 then
				rx_data_length <= rx_data_length - RESIZE(unsigned(ip_packet_header_length), 16);
			end if;
			if packet_handler_state = PARSE_TCP_PACKET16 then
				rx_tcp_window_size(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET17 then
				rx_tcp_window_size(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET18 then
				rx_tcp_checksum(15 downto 8) <= rx_packet_rd_data;
			elsif packet_handler_state = PARSE_TCP_PACKET19 then
				rx_tcp_checksum(7 downto 0) <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET19 then
				tcp_option_addr <= rx_packet_ram_rd_addr + "00000000010"; -- skup 2 blanks after checksum
			elsif packet_handler_state = PARSE_TCP_PACKET26 then
				tcp_option_addr <= tcp_option_addr + 1;
			elsif packet_handler_state = PARSE_TCP_PACKET27 then
				tcp_option_addr <= tcp_option_addr + RESIZE(rx_tcp_option_length, 11);
			end if;
			if packet_handler_state = PARSE_TCP_PACKET22 then
				rx_tcp_option <= rx_packet_rd_data;
			end if;
			if packet_handler_state = PARSE_TCP_PACKET23 then
				rx_tcp_option_length <= unsigned(rx_packet_rd_data);
			end if;
			if packet_handler_state = PARSE_TCP_PACKET24 then
				rx_tcp_window_shift <= rx_packet_rd_data;
			end if;
		end if;
	end process;

	DHCP_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if packet_handler_state = HANDLE_DHCP_ACK1 then
				ip_addr <= dhcp_your_ip_addr;
				server_ip_addr <= dhcp_server_ip_addr;
			end if;
			if tx_packet_state = INIT_DHCP_DISCOVER_METADATA then
				expecting_dhcp_offer <= '1';
			elsif tx_packet_state = INIT_DHCP_REQUEST_METADATA then
				expecting_dhcp_offer <= '0';
			elsif tx_packet_state = CANCEL_DHCP_CONNECT_ST then
				expecting_dhcp_offer <= '0';
			end if;
			if tx_packet_state = INIT_DHCP_REQUEST_METADATA then
				expecting_dhcp_ack <= '1';
			elsif packet_handler_state = HANDLE_DHCP_ACK1 then
				expecting_dhcp_ack <= '0';
			elsif tx_packet_state = CANCEL_DHCP_CONNECT_ST then
				expecting_dhcp_ack <= '0';
			end if;
			if eth_state = TRIGGER_DHCP_DISCOVER then
				dhcp_addr_locked <= '0';
			elsif packet_handler_state = HANDLE_DHCP_ACK1 then
				dhcp_addr_locked <= '1';
			end if;
			if eth_state = TRIGGER_ARP_REQUEST then
				expecting_arp_reply <= '1';
			elsif packet_handler_state = HANDLE_ARP_REPLY1 then
				expecting_arp_reply <= '0';
			end if;
			if packet_handler_state = HANDLE_ARP_REPLY7 then
				static_addr_locked <= '1';
			elsif tx_packet_state = INIT_ARP_REQUEST_METADATA then
				static_addr_locked <= '0';
			elsif tx_packet_state = CANCEL_DHCP_CONNECT_ST then
				static_addr_locked <= '0';
			end if;
      end if;
   end process;	
				

--------------------- TX PACKET ------------------------------	

	TP_SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			tx_packet_state <= tx_packet_next_state;
      end if;
   end process;

	TP_NEXT_STATE_DECODE: process (tx_packet_state, send_arp_reply, send_arp_request, send_icmp_reply, 
												send_dhcp_discover, send_dhcp_request, frame_rd_cmplt, send_tcp_svn_packet,
													send_tcp_ack_packet, cancel_dhcp_connect, close_tcp_connection, cancel_tcp_connection, 
														packet_instruction, checksum_calc_done)
   begin
      tx_packet_next_state <= tx_packet_state;  --default is to stay in current state
      case (tx_packet_state) is
         when IDLE =>
				if send_arp_reply = '1' then
					tx_packet_next_state <= INIT_ARP_REPLY_METADATA;
				elsif send_arp_request = '1' then
					tx_packet_next_state <= INIT_ARP_REQUEST_METADATA;
				elsif send_icmp_reply = '1' then
					tx_packet_next_state <= INIT_ICMP_REPLY_METADATA;
				elsif send_dhcp_discover = '1' then
					tx_packet_next_state <= INIT_DHCP_DISCOVER_METADATA;
				elsif send_dhcp_request = '1' then
					tx_packet_next_state <= INIT_DHCP_REQUEST_METADATA;
				elsif send_tcp_svn_packet = '1' then
					tx_packet_next_state <= INIT_TCP_PACKET_METADATA;
				elsif send_tcp_ack_packet = '1' then
					tx_packet_next_state <= INIT_TCP_PACKET_METADATA;
				elsif cancel_dhcp_connect = '1' then
					tx_packet_next_state <= CANCEL_DHCP_CONNECT_ST;
				elsif close_tcp_connection = '1' then
					tx_packet_next_state <= TCP_CONNECTION_CLOSED; -- TODO send FIN packet!
				elsif cancel_tcp_connection = '1' then
					tx_packet_next_state <= CANCEL_TCP_CONNECTION_ST;
				end if;
			when CANCEL_DHCP_CONNECT_ST =>
				tx_packet_next_state <= IDLE;
			when CANCEL_TCP_CONNECTION_ST =>
				tx_packet_next_state <= IDLE;
			when TCP_CONNECTION_CLOSED =>
				tx_packet_next_state <= IDLE;
			when INIT_ARP_REPLY_METADATA =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when INIT_ARP_REQUEST_METADATA =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when INIT_ICMP_REPLY_METADATA =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when INIT_DHCP_DISCOVER_METADATA =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when INIT_DHCP_REQUEST_METADATA =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when INIT_TCP_PACKET_METADATA =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when READ_PACKET_BYTE0 =>
				tx_packet_next_state <= READ_PACKET_BYTE1;
			when READ_PACKET_BYTE1 =>
				if frame_rd_cmplt = '1' then
					tx_packet_next_state <= HANDLE_PACKET_INSTRUCTION0;
				end if;
			when HANDLE_PACKET_INSTRUCTION0 =>
				if packet_instruction = X"FF" then
					tx_packet_next_state <= COMPLETE;
				elsif packet_instruction = X"17" then
					tx_packet_next_state <= SET_RX_PACKET_ADDR_LOWER_BYTE;
				elsif packet_instruction = X"18" then
					tx_packet_next_state <= SET_RX_PACKET_ADDR_UPPER_BYTE;
				elsif packet_instruction = X"20" then
					tx_packet_next_state <= SET_CHECKSUM_LENGTH_LSB;
				elsif packet_instruction = X"21" then
					tx_packet_next_state <= SET_CHECKSUM_LENGTH_MSB;
				elsif packet_instruction = X"22" then
					tx_packet_next_state <= SET_CHECKSUM_START_ADDR_LSB;
				elsif packet_instruction = X"23" then
					tx_packet_next_state <= SET_CHECKSUM_START_ADDR_MSB;
				elsif packet_instruction = X"24" then
					tx_packet_next_state <= SET_CHECKSUM_WR_ADDR_LSB;
				elsif packet_instruction = X"25" then
					tx_packet_next_state <= SET_CHECKSUM_WR_ADDR_MSB;
				elsif packet_instruction = X"26" then
					tx_packet_next_state <= TRIG_CHECKSUM_CALC;
				elsif packet_instruction = X"29" then
					tx_packet_next_state <= MOVE_TX_PACKET_WR_ADDR;
				elsif packet_instruction = X"2E" then
					tx_packet_next_state <= SET_NEW_TRANSACTION_ID;
				elsif packet_instruction = X"50" then
					tx_packet_next_state <= SET_CHECKSUM_START_VAL_LSB;
				elsif packet_instruction = X"51" then
					tx_packet_next_state <= SET_CHECKSUM_START_VAL_MSB;
				elsif packet_instruction = X"52" then
					tx_packet_next_state <= TRIGGER_CHECKSUM_LOAD_INITIAL_VALUE;
				else
					tx_packet_next_state <= HANDLE_PACKET_INSTRUCTION1;
				end if;
			when HANDLE_PACKET_INSTRUCTION1 =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			
			when SET_RX_PACKET_ADDR_LOWER_BYTE =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when SET_RX_PACKET_ADDR_UPPER_BYTE =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			
			when SET_CHECKSUM_LENGTH_LSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when SET_CHECKSUM_LENGTH_MSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
				
			when SET_CHECKSUM_START_ADDR_LSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when SET_CHECKSUM_START_ADDR_MSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;		

			when SET_CHECKSUM_WR_ADDR_LSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when SET_CHECKSUM_WR_ADDR_MSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;		
			
			when TRIG_CHECKSUM_CALC =>
				tx_packet_next_state <= WAIT_FOR_CHECKSUM_CMPLT;
			when WAIT_FOR_CHECKSUM_CMPLT =>
				if checksum_calc_done = '1' then
					tx_packet_next_state <= READ_PACKET_BYTE0;
				end if;

			when MOVE_TX_PACKET_WR_ADDR =>
				tx_packet_next_state <= READ_PACKET_BYTE0;

			when SET_NEW_TRANSACTION_ID =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
				
			when SET_CHECKSUM_START_VAL_LSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when SET_CHECKSUM_START_VAL_MSB =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
			when TRIGGER_CHECKSUM_LOAD_INITIAL_VALUE =>
				tx_packet_next_state <= READ_PACKET_BYTE0;
				
			when COMPLETE =>
				tx_packet_next_state <= IDLE;
				
		end case;
	end process;
	
	packet_instruction <= frame_data(15 downto 8);
	
	with packet_instruction(6 downto 0) select 
		packet_data <= frame_data(7 downto 0) 							when "000"&X"0",
							mac_addr(7 downto 0) 							when "000"&X"1",
							mac_addr(15 downto 8) 							when "000"&X"2",
							mac_addr(23 downto 16) 							when "000"&X"3",
							mac_addr(31 downto 24) 							when "000"&X"4",
							mac_addr(39 downto 32) 							when "000"&X"5",
							mac_addr(47 downto 40) 							when "000"&X"6",
							rx_packet_source_mac(7 downto 0) 			when "000"&X"7",
							rx_packet_source_mac(15 downto 8) 			when "000"&X"8",
							rx_packet_source_mac(23 downto 16) 			when "000"&X"9",
							rx_packet_source_mac(31 downto 24) 			when "000"&X"A",
							rx_packet_source_mac(39 downto 32) 			when "000"&X"B",
							rx_packet_source_mac(47 downto 40) 			when "000"&X"C",
							ip_addr(7 downto 0) 								when "000"&X"D",
							ip_addr(15 downto 8) 							when "000"&X"E",
							ip_addr(23 downto 16) 							when "000"&X"F",
							ip_addr(31 downto 24) 							when "001"&X"0",
							arp_source_ip_addr(7 downto 0) 				when "001"&X"1",
							arp_source_ip_addr(15 downto 8) 				when "001"&X"2",
							arp_source_ip_addr(23 downto 16) 			when "001"&X"3",
							arp_source_ip_addr(31 downto 24) 			when "001"&X"4",
							ip_identification(7 downto 0)					when "001"&X"5",
							ip_identification(15 downto 8)				when "001"&X"6",
							X"00"													when "001"&X"7", -- set rx read lower byte
							X"00"													when "001"&X"8", -- set rx read upper byte
							rx_packet_rd_data2								when "001"&X"9",
							X"00"													when "010"&X"0", -- set checksum length lsb
							X"00"													when "010"&X"1", -- set checksum length msb
							X"00"													when "010"&X"2", -- set checksum start addr lsb
							X"00"													when "010"&X"3", -- set checksum start addr msb
							X"00"													when "010"&X"4", -- set checksum wr addr lsb
							X"00"													when "010"&X"5", -- set checksum wr addr msb
							X"00"													when "010"&X"6", -- trigger checksum calc
							checksum(7 downto 0)  							when "010"&X"7",
							checksum(15 downto 8)  							when "010"&X"8",
							X"00"													when "010"&X"9", -- set tx write addr to checksum wr addr
							dhcp_transaction_id(7 downto 0)				when "010"&X"A",
							dhcp_transaction_id(15 downto 8)				when "010"&X"B",
							dhcp_transaction_id(23 downto 16)			when "010"&X"C",
							dhcp_transaction_id(31 downto 24)			when "010"&X"D",
							X"00"													when "010"&X"E", -- set new transaction ID
							dhcp_server_ip_addr(7 downto 0)				when "010"&X"F",
							dhcp_server_ip_addr(15 downto 8)				when "011"&X"0",
							dhcp_server_ip_addr(23 downto 16)			when "011"&X"1",
							dhcp_server_ip_addr(31 downto 24)			when "011"&X"2",
							dhcp_your_ip_addr(7 downto 0)					when "011"&X"3",
							dhcp_your_ip_addr(15 downto 8)				when "011"&X"4",
							dhcp_your_ip_addr(23 downto 16)				when "011"&X"5",
							dhcp_your_ip_addr(31 downto 24)				when "011"&X"6",
							server_ip_addr(7 downto 0)						when "011"&X"7",
							server_ip_addr(15 downto 8)					when "011"&X"8",
							server_ip_addr(23 downto 16)					when "011"&X"9",
							server_ip_addr(31 downto 24)					when "011"&X"A",
							server_mac_addr(7 downto 0) 					when "011"&X"B",
							server_mac_addr(15 downto 8) 					when "011"&X"C",
							server_mac_addr(23 downto 16) 				when "011"&X"D",
							server_mac_addr(31 downto 24) 				when "011"&X"E",
							server_mac_addr(39 downto 32) 				when "011"&X"F",
							server_mac_addr(47 downto 40) 				when "100"&X"0",
							tcp_port(7 downto 0)								when "100"&X"1",
							tcp_port(15 downto 8)							when "100"&X"2",
							server_port(7 downto 0)							when "100"&X"3",
							server_port(15 downto 8)						when "100"&X"4",
							slv(tcp_sequence_number(7 downto 0))		when "100"&X"5",
							slv(tcp_sequence_number(15 downto 8))		when "100"&X"6",
							slv(tcp_sequence_number(23 downto 16))		when "100"&X"7",
							slv(tcp_sequence_number(31 downto 24))		when "100"&X"8",
							slv(tcp_acknowledge_number(7 downto 0))	when "100"&X"9",
							slv(tcp_acknowledge_number(15 downto 8))	when "100"&X"A",
							slv(tcp_acknowledge_number(23 downto 16))	when "100"&X"B",
							slv(tcp_acknowledge_number(31 downto 24))	when "100"&X"C",
							tcp_flags(7 downto 0)							when "100"&X"D",
							window_size(7 downto 0)							when "100"&X"E",
							window_size(15 downto 8)						when "100"&X"F",
							X"00"													when "101"&X"0", -- Set initial checksum value
							X"00"													when "101"&X"1", -- Set initial checksum value
							X"00"													when "101"&X"2", -- Load initial checksum value
							slv(tcp_ip_identification(7 downto 0))		when "101"&X"3",
							slv(tcp_ip_identification(15 downto 8))	when "101"&X"4",
							X"00"													when others;
							
	tcp_sequence_number_p1 <= tcp_sequence_number + 1;
	
	RANDOM_VALS_PROC: process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			ip_identification <= lfsr_val(15 downto 0);			-- TODO
			if tx_packet_state = SET_NEW_TRANSACTION_ID then
				dhcp_transaction_id <= lfsr_val;
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				tcp_ip_identification <= unsigned(lfsr_val(15 downto 0));
			elsif packet_handler_state = TRIGGER_TCP_ACK then
				tcp_ip_identification <= tcp_ip_identification + 1;
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				tcp_port <= lfsr_val(15 downto 0);
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				tcp_sequence_number <= unsigned(lfsr_val);
			elsif packet_handler_state = CHECK_TCP_SYN_ACK_PACKET2 then
				tcp_sequence_number <= tcp_sequence_number_p1;
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				tcp_acknowledge_number <= (others => '0');
			elsif packet_handler_state = CHECK_TCP_SYN_ACK_PACKET2 then
				tcp_acknowledge_number <= unsigned(rx_tcp_seq_number) + 1;
			elsif packet_handler_state = CHECK_TCP_PSH_ACK_PACKET3 then
				tcp_acknowledge_number <= tcp_acknowledge_number + RESIZE(rx_data_length, 32);
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				tcp_flags <= C_tcp_syn_flags;
			elsif packet_handler_state = TRIGGER_TCP_ACK then
				tcp_flags <= C_tcp_ack_flags;
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				window_size <= X"0400";
			end if;
			if eth_state = TRIGGER_NEW_TCP_CONNECTION then
				expecting_syn_ack <= '1';
			elsif packet_handler_state = CHECK_TCP_SYN_ACK_PACKET2 then
				expecting_syn_ack <= '0';
			elsif tx_packet_state = CANCEL_TCP_CONNECTION_ST then
				expecting_syn_ack <= '0';
			end if;
			if packet_handler_state = CHECK_TCP_SYN_ACK_PACKET2 then
				tcp_connection_active <= '1';
			elsif tx_packet_state = TCP_CONNECTION_CLOSED then
				tcp_connection_active <= '0';
			end if;
		end if;
	end process;
	
	FRAME_ADDR_LENGTH_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if tx_packet_state = INIT_ARP_REPLY_METADATA then
				tx_packet_frame_addr <= unsigned(C_arp_reply_frame_addr);
			elsif tx_packet_state = INIT_ARP_REQUEST_METADATA then
				tx_packet_frame_addr <= unsigned(C_arp_request_frame_addr);
			elsif tx_packet_state = INIT_ICMP_REPLY_METADATA then
				tx_packet_frame_addr <= unsigned(C_icmp_reply_frame_addr);
			elsif tx_packet_state = INIT_DHCP_DISCOVER_METADATA then
				tx_packet_frame_addr <= unsigned(C_dhcp_discover_frame_addr);
			elsif tx_packet_state = INIT_DHCP_REQUEST_METADATA then
				tx_packet_frame_addr <= unsigned(C_dhcp_request_frame_addr);
			elsif tx_packet_state = INIT_TCP_PACKET_METADATA then
				tx_packet_frame_addr <= unsigned(C_tcp_packet_frame_addr);
			elsif tx_packet_state = IDLE then
				tx_packet_frame_addr <= tx_packet_frame_addr;
			elsif tx_packet_state = READ_PACKET_BYTE0 then
				tx_packet_frame_addr <= tx_packet_frame_addr;
			elsif tx_packet_state = READ_PACKET_BYTE1 then
				tx_packet_frame_addr <= tx_packet_frame_addr;
			elsif tx_packet_state = HANDLE_PACKET_INSTRUCTION0 then
				tx_packet_frame_addr <= tx_packet_frame_addr;
			elsif tx_packet_state = WAIT_FOR_CHECKSUM_CMPLT then
				tx_packet_frame_addr <= tx_packet_frame_addr;
			elsif tx_packet_state = COMPLETE then
				tx_packet_frame_addr <= tx_packet_frame_addr;
			else
				tx_packet_frame_addr <= tx_packet_frame_addr + 1;
			end if;
			if tx_packet_state = INIT_ARP_REPLY_METADATA then
				tx_packet_length <= unsigned(C_arp_reply_length);
			elsif tx_packet_state = INIT_ARP_REQUEST_METADATA then
				tx_packet_length <= unsigned(C_arp_request_length);
			elsif tx_packet_state = INIT_ICMP_REPLY_METADATA then
				tx_packet_length <= unsigned(C_icmp_reply_length);
			elsif tx_packet_state = INIT_DHCP_DISCOVER_METADATA then
				tx_packet_length <= unsigned(C_dhcp_discover_length);
			elsif tx_packet_state = INIT_DHCP_REQUEST_METADATA then
				tx_packet_length <= unsigned(C_dhcp_request_length);
			elsif tx_packet_state = INIT_TCP_PACKET_METADATA then
				tx_packet_length <= unsigned(C_tcp_packet_length);
			end if;
			if tx_packet_state = INIT_ARP_REPLY_METADATA then
				tx_packet_end_pointer <= X"1000" + unsigned(C_arp_reply_length);
			elsif tx_packet_state = INIT_ARP_REQUEST_METADATA then
				tx_packet_end_pointer <= X"1000" + unsigned(C_arp_request_length);
			elsif tx_packet_state = INIT_ICMP_REPLY_METADATA then
				tx_packet_end_pointer <= X"1000" + unsigned(C_icmp_reply_length);
			elsif tx_packet_state = INIT_DHCP_DISCOVER_METADATA then
				tx_packet_end_pointer <= X"1000" + unsigned(C_dhcp_discover_length);
			elsif tx_packet_state = INIT_DHCP_REQUEST_METADATA then
				tx_packet_end_pointer <= X"1000" + unsigned(C_dhcp_discover_length);
			elsif tx_packet_state = INIT_TCP_PACKET_METADATA then
				tx_packet_end_pointer <= X"1000" + unsigned(C_tcp_packet_length);
			end if;
			if tx_packet_state = IDLE then
				doing_tx_packet_config <= '0';
			else
				doing_tx_packet_config <= '1';
			end if;
			if tx_packet_state = IDLE then
				tx_packet_ram_we_addr_buf <= "00000000000";
			elsif tx_packet_state = HANDLE_PACKET_INSTRUCTION1 then
				tx_packet_ram_we_addr_buf <= tx_packet_ram_we_addr_buf + 1;
			elsif tx_packet_state = MOVE_TX_PACKET_WR_ADDR then
				tx_packet_ram_we_addr_buf <= unsigned(checksum_wr_addr);
			end if;
			if tx_packet_state = COMPLETE then
				tx_packet_ready_from_transmission <= '1';
			elsif eth_state = HANDLE_TX_TRANSMIT17 then
				tx_packet_ready_from_transmission <= '0';
			end if;
			if tx_packet_state = SET_RX_PACKET_ADDR_LOWER_BYTE then
				rx_packet_rd2_addr(7 downto 0) <= unsigned(frame_data(7 downto 0));
			elsif tx_packet_state = SET_RX_PACKET_ADDR_UPPER_BYTE then
				rx_packet_rd2_addr(10 downto 8) <= unsigned(frame_data(2 downto 0));
			elsif tx_packet_state = HANDLE_PACKET_INSTRUCTION1 then
				rx_packet_rd2_addr <= rx_packet_rd2_addr + 1;
			end if;
      end if;
   end process;

	tx_packet_ram_data <= packet_data;
	tx_packet_ram_we <= '1' when tx_packet_state = HANDLE_PACKET_INSTRUCTION1 else '0';
	tx_packet_config_cmplt <= '1' when tx_packet_state = COMPLETE else '0';

	tx_packet_ram_we_addr <= unsigned(checksum_addr) when (tx_packet_state = WAIT_FOR_CHECKSUM_CMPLT) else tx_packet_ram_we_addr_buf;

	TX_PACKET_RAM : TDP_RAM
		Generic Map (	G_DATA_A_SIZE 	=> tx_packet_ram_data'length,
							G_ADDR_A_SIZE	=> tx_packet_ram_we_addr'length,
							G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
							G_INIT_ZERO		=> true,
							G_INIT_FILE		=> "")
		Port Map ( CLK_A_IN 	=> CLK_IN,
				 WE_A_IN 		=> tx_packet_ram_we,
				 ADDR_A_IN 		=> slv(tx_packet_ram_we_addr),
				 DATA_A_IN		=> tx_packet_ram_data,
				 DATA_A_OUT		=> tx_packet_rd_data2,
				 CLK_B_IN 		=> CLK_IN,
				 WE_B_IN 		=> '0',
				 ADDR_B_IN 		=> slv(tx_packet_ram_rd_addr),
				 DATA_B_IN 		=> X"00",
				 DATA_B_OUT 	=> tx_packet_rd_data);

	CHECKSUM_METADATA_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			if tx_packet_state = SET_CHECKSUM_LENGTH_LSB then
				checksum_count(7 downto 0) <= frame_data(7 downto 0);
			elsif tx_packet_state = SET_CHECKSUM_LENGTH_MSB then
				checksum_count(10 downto 8) <= frame_data(2 downto 0);
			elsif tx_packet_state = SET_CHECKSUM_START_ADDR_LSB then
				checksum_start_addr(7 downto 0) <= frame_data(7 downto 0);
			elsif tx_packet_state = SET_CHECKSUM_START_ADDR_MSB then
				checksum_start_addr(10 downto 8) <= frame_data(2 downto 0);
			elsif tx_packet_state = SET_CHECKSUM_WR_ADDR_LSB then
				checksum_wr_addr(7 downto 0) <= frame_data(7 downto 0);
			elsif tx_packet_state = SET_CHECKSUM_WR_ADDR_MSB then
				checksum_wr_addr(10 downto 8) <= frame_data(2 downto 0);
			end if;
			if tx_packet_state = SET_CHECKSUM_START_VAL_LSB then
				checksum_initial_value(7 downto 0) <= frame_data(7 downto 0);
			end if;
			if tx_packet_state = SET_CHECKSUM_START_VAL_MSB then
				checksum_initial_value(15 downto 8) <= frame_data(7 downto 0);
			end if;
			if tx_packet_state = TRIGGER_CHECKSUM_LOAD_INITIAL_VALUE then
				checksum_set_initial_value <= '1';
			else
				checksum_set_initial_value <= '0';
			end if;
		end if;
	end process;
	
	calc_checksum <= '1' when tx_packet_state = TRIG_CHECKSUM_CALC else '0';

	checksum_calc_mod : checksum_calc
    Port Map ( CLK_IN 					=> CLK_IN,
					RST_IN 					=> '0',
					CHECKSUM_CALC_IN 		=> calc_checksum,
					START_ADDR_IN 			=> checksum_start_addr,
					COUNT_IN 				=> checksum_count,
					VALUE_IN 				=> tx_packet_rd_data2,
					VALUE_ADDR_OUT 		=> checksum_addr,
					CHECKSUM_INIT_IN		=> checksum_initial_value,
					CHECKSUM_SET_INIT_IN	=> checksum_set_initial_value,
					CHECKSUM_OUT 			=> checksum,
					CHECKSUM_DONE_OUT 	=> checksum_calc_done);

------------------- PACKET DEFINITION ------------------------

	--Packet_Definition_Mod : Packet_Definition_LX9
	Packet_Definition_Mod : Packet_Definition
	  Port Map (
		 clka 	=> CLK_IN,
		 addra 	=> packet_definition_addr,
		 douta 	=> packet_definition_data);

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

------------------------- LFSR -------------------------------

	lfsr32_mod_inst : lfsr32_mod
		Port Map ( 	CLK_IN 		=> CLK_IN,
						SEED_IN 		=> X"00000000",
						SEED_EN_IN 	=> '0',
						VAL_OUT 		=> lfsr_val);

--------------------- TCP RX DATA ----------------------------

	tcp_data_rd_en <= TCP_RD_DATA_EN_IN;
	TCP_RD_DATA_AVAIL_OUT <= tcp_rd_data_available;
	TCP_RD_DATA_OUT <= tcp_rx_data_rd_data;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if tcp_rx_data_wr_addr_m1 /= tcp_rx_data_rd_addr then
				tcp_rd_data_available <= '1';
			else
				tcp_rd_data_available <= '0';
			end if;
			if tcp_data_rd_en = '1' then
				if tcp_rx_data_wr_addr_m1 /= tcp_rx_data_rd_addr then
					tcp_rx_data_rd_addr <= tcp_rx_data_rd_addr + 1;
				end if;
			end if;
			if tcp_rx_data_we = '1' then 
				tcp_rx_data_wr_addr <= tcp_rx_data_wr_addr + 1;
			end if;
		end if;
	end process;

	tcp_rx_data_wr_addr_m1 <= tcp_rx_data_wr_addr - 1;
	tcp_rx_data_we <= '1' when (packet_handler_next_state = CHECK_TCP_PSH_ACK_PACKET4) else '0';

	TCP_RX_DATA_RAM : TDP_RAM
		Generic Map (	G_DATA_A_SIZE 	=> rx_packet_rd_data'length,
							G_ADDR_A_SIZE	=> tcp_rx_data_wr_addr'length,
							G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
							G_INIT_ZERO		=> true,
							G_INIT_FILE		=> "")
		Port Map ( CLK_A_IN 	=> CLK_IN,
				 WE_A_IN 		=> tcp_rx_data_we,
				 ADDR_A_IN 		=> slv(tcp_rx_data_wr_addr),
				 DATA_A_IN		=> rx_packet_rd_data,
				 DATA_A_OUT		=> open,
				 CLK_B_IN 		=> CLK_IN,
				 WE_B_IN 		=> '0',
				 ADDR_B_IN 		=> slv(tcp_rx_data_rd_addr),
				 DATA_B_IN 		=> X"00",
				 DATA_B_OUT 	=> tcp_rx_data_rd_data);

	--- DATA I/O ---
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if ADDR_IN = X"00" then
				DATA_OUT <= "0000000" & network_interface_enabled;
			elsif ADDR_IN = X"01" then
				DATA_OUT <= mac_addr(47 downto 40);
			elsif ADDR_IN = X"02" then
				DATA_OUT <= mac_addr(39 downto 32);
			elsif ADDR_IN = X"03" then
				DATA_OUT <= mac_addr(31 downto 24);
			elsif ADDR_IN = X"04" then
				DATA_OUT <= mac_addr(23 downto 16);
			elsif ADDR_IN = X"05" then
				DATA_OUT <= mac_addr(15 downto 8);
			elsif ADDR_IN = X"06" then
				DATA_OUT <= mac_addr(7 downto 0);
			elsif ADDR_IN = X"07" then
				DATA_OUT <= "0000000" & dhcp_enable;
			elsif ADDR_IN = X"08" then
				DATA_OUT <= "000000" & static_addr_locked & dhcp_addr_locked;
			elsif ADDR_IN = X"09" then
				DATA_OUT <= ip_addr(31 downto 24);
			elsif ADDR_IN = X"0A" then
				DATA_OUT <= ip_addr(23 downto 16);
			elsif ADDR_IN = X"0B" then
				DATA_OUT <= ip_addr(15 downto 8);
			elsif ADDR_IN = X"0C" then
				DATA_OUT <= ip_addr(7 downto 0);
			elsif ADDR_IN = X"0D" then
				DATA_OUT <= cloud_ip_addr(31 downto 24);
			elsif ADDR_IN = X"0E" then
				DATA_OUT <= cloud_ip_addr(23 downto 16);
			elsif ADDR_IN = X"0F" then
				DATA_OUT <= cloud_ip_addr(15 downto 8);
			elsif ADDR_IN = X"10" then
				DATA_OUT <= cloud_ip_addr(7 downto 0);
			elsif ADDR_IN = X"11" then
				DATA_OUT <= "0000000" & tcp_connection_active;
			end if;
		end if;
	end process;

end Behavioral;

