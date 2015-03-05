----------------------------------------------------------------------------------
-- Company: 
-- Engineer: CW
-- 
-- Create Date:    21:25:31 10/06/2014 
-- Design Name: 
-- Module Name:    hw_client - Behavioral 
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

library UNISIM;
use UNISIM.VComponents.all;

entity vault is
    Port ( 	CLK_IN 		: in STD_LOGIC;

				LED_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
				SSEG_OUT 	: out STD_LOGIC_VECTOR (7 downto 0);
				SSEG_EN_OUT : out STD_LOGIC_VECTOR (3 downto 0);
				SW_IN 		: in STD_LOGIC_VECTOR (7 downto 0);
				BUTTON_IN 	: in STD_LOGIC_VECTOR (5 downto 0);
				
				SDI			: in STD_LOGIC;
				SDO			: out STD_LOGIC;
				SCLK 			: out STD_LOGIC;
				CS				: out STD_LOGIC;
				INT			: in STD_LOGIC;
				RESET			: out STD_LOGIC;
				
				SD_MISO		: out  STD_LOGIC;
				SD_MOSI		: out  STD_LOGIC;
				SD_CLK		: out  STD_LOGIC;
				SD_CS			: out  STD_LOGIC
				
				);
end vault;

architecture Behavioral of vault is

	COMPONENT clk_mod
		 Port ( CLK_100MHz_IN 	: in  STD_LOGIC;
				  CLK_25Mhz_OUT 	: out  STD_LOGIC;
				  CLK_100Mhz_OUT 	: out  STD_LOGIC);
	END COMPONENT;
	
	COMPONENT sseg
	PORT (	
		CLK    : in STD_LOGIC;
		VAL_IN  	: in STD_LOGIC_VECTOR (15 downto 0);
		SSEG_OUT	: out STD_LOGIC_VECTOR(7 downto 0);
		AN_OUT   : out STD_LOGIC_VECTOR(3 downto 0));
	END COMPONENT;

	COMPONENT led_mod is
    Port ( CLK_IN 				: in  STD_LOGIC;
           LED_STATE_IN 		: in  STD_LOGIC_VECTOR (2 downto 0);
			  ERROR_CODE_IN		: in	STD_LOGIC_VECTOR (4 downto 0);
			  ERROR_CODE_EN_IN	: in	STD_LOGIC;
           LEDS_OUT 				: out  STD_LOGIC_VECTOR (1 downto 0);
			  CLK_1HZ_OUT			: out STD_LOGIC);
	END COMPONENT;

	COMPONENT eth_mod is
    Port ( CLK_IN 	: in  STD_LOGIC;
           RESET_IN 	: in  STD_LOGIC;
			  
			  -- Command interface
			  INIT_ENC28J60 	: in 	STD_LOGIC;
			  DHCP_CONNECT 	: in 	STD_LOGIC;
			  TCP_CONNECT 		: in 	STD_LOGIC;
			  ERROR_OUT 		: out  STD_LOGIC_VECTOR (7 downto 0);
			  
			  -- Data Interface
			  ADDR_IN	: in  STD_LOGIC_VECTOR (7 downto 0);
			  DATA_OUT	: out  STD_LOGIC_VECTOR (7 downto 0);
			  
			  DEBUG_IN 	: in STD_LOGIC_VECTOR (2 downto 0);
			  DEBUG_OUT	: out  STD_LOGIC_VECTOR (15 downto 0);
			  
           -- TCP Connection Interface
			  TCP_RD_DATA_AVAIL_OUT : out STD_LOGIC;
			  TCP_RD_DATA_EN_IN 		: in STD_LOGIC;
			  TCP_RD_DATA_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
			  
			  CLK_1HZ_IN	: in STD_LOGIC;
			  
			  -- Eth SPI interface
			  SDI_OUT 	: out  STD_LOGIC;
           SDO_IN 	: in  STD_LOGIC;
           SCLK_OUT 	: out  STD_LOGIC;
           CS_OUT 	: out  STD_LOGIC;
			  INT_IN		: in STD_LOGIC);
	END COMPONENT;

subtype slv is std_logic_vector;

signal clk_25MHz, clk_100MHz : std_logic;
signal clk_1hz : std_logic;

signal char_addr, font_addr	: std_logic_vector(11 downto 0);
signal char_data, font_data	: std_logic_vector(7 downto 0);
signal debug_addr	: std_logic_vector(11 downto 0);
signal debug_data	: std_logic_vector(7 downto 0);
signal debug_i		: std_logic_vector(2 downto 0);
signal r, g, b 					: std_logic := '0';
signal octl							: std_logic_vector(7 downto 0);
signal ocrx, ocry 				: std_logic_vector(7 downto 0) := (others => '0');

signal frame_addr : std_logic_vector(23 downto 1) := (others => '0');
signal frame_data : std_logic_vector(15 downto 0) := (others => '0');
signal frame_rd, frame_rd_cmplt : std_logic := '0';

signal sseg_data : std_logic_vector(15 downto 0) := (others => '0');
signal debug_we : std_logic := '0';
signal debug_wr_addr : unsigned(11 downto 0) := (others => '0');
signal debug_wr_data : std_logic_vector(7 downto 0) := (others => '0');
signal buttons, buttons_prev, buttons_edge	: std_logic_vector(5 downto 0) := (others => '0');
signal debounce_count								: unsigned(15 downto 0) := (others => '0');

signal data_bus, addr_bus 	: std_logic_vector(7 downto 0) := (others => '0');
signal eth_command 			: std_logic_vector(3 downto 0);
signal eth_command_err		: std_logic_vector(7 downto 0);
signal eth_command_en, eth_command_cmplt : std_logic;
	
signal sdi_buf, sdo_buf, sclk_buf, sclk_buf_n, sclk_oddr, cs_buf : std_logic;

signal clk_div_counter : unsigned(7 downto 0);
signal tcp_rd_en : std_logic;

begin
	
	clk_mod_Inst : clk_mod
	PORT MAP ( 	CLK_100MHz_IN 	=> CLK_IN,
					CLK_25Mhz_OUT 	=> clk_25MHz,
					CLK_100Mhz_OUT => clk_100MHz);
	
--------------------------- DEBUG LOGIC ------------------------------
	
	LED_OUT(4 downto 2) <= (others => '0');
	--LED_OUT(7 downto 4) <= sseg_data(15 downto 12);
	LED_OUT(7 downto 5) <= debug_i;
	
	SD_MISO 	<= '0';
	SD_MOSI 	<= '0';
	SD_CLK 	<= '0';
	SD_CS 	<= '0';
	
	OBUF_inst_0: OBUF generic map ( DRIVE => 12, IOSTANDARD => "DEFAULT", SLEW => "FAST") port map (I => sdi_buf, O => SDO);
	IBUF_inst_0: IBUF port map (I => SDI, O => sdo_buf);
	OBUF_inst_1: OBUF generic map ( DRIVE => 12, IOSTANDARD => "DEFAULT", SLEW => "FAST") port map (I => sclk_oddr, O => SCLK);
	OBUF_inst_2: OBUF generic map ( DRIVE => 12, IOSTANDARD => "DEFAULT", SLEW => "FAST") port map (I => cs_buf, O => CS);

	sclk_buf_n <= not(sclk_buf);
	
	ODDR2_CLK: ODDR2
   port map (
      Q => sclk_oddr, 	-- 1-bit output data
      C0 => sclk_buf, 	-- 1-bit clock input
      C1 => sclk_buf_n, -- 1-bit clock input
      CE => '1',  		-- 1-bit clock enable input
      D0 => '1',   		-- 1-bit data input (associated with C0)
      D1 => '0',   		-- 1-bit data input (associated with C1)
      R => '0',    		-- 1-bit reset input
      S => '0'     		-- 1-bit set input
   );

	sseg_inst : sseg
	PORT MAP (	
		CLK    	=> clk_25MHz,
		VAL_IN 	=> sseg_data,
		SSEG_OUT	=> SSEG_OUT,
		AN_OUT   => SSEG_EN_OUT);
	
	process(clk_25MHz)
	begin
		if rising_edge(clk_100MHz) then
			debounce_count <= debounce_count + 1;
			buttons_prev <= buttons;
			if debounce_count = X"0000" then
				buttons <= BUTTON_IN;
			end if;
			for i in 0 to 5 loop
				if buttons_prev(i) = '0' and buttons(i) = '1' then
					buttons_edge(i) <= '1';
				else
					buttons_edge(i) <= '0';
				end if;
			end loop;
		end if;
	end process;

--------------------------- UI I/O ------------------------------

	led_mod_inst : led_mod
    Port Map ( CLK_IN 				=> clk_25MHz,
					LED_STATE_IN 		=> "001",
					ERROR_CODE_IN		=> SW_IN(4 downto 0),
					ERROR_CODE_EN_IN	=> '0',
					LEDS_OUT 			=> LED_OUT(1 downto 0),
					
					CLK_1HZ_OUT			=> clk_1hz);
				
------------------------- Ethernet I/O --------------------------------

	RESET <= '0';
	debug_i <= buttons(2)&buttons(1)&buttons(0);

	eth_mod_inst : eth_mod
		 Port Map ( CLK_IN 	=> clk_100MHz,
						RESET_IN => '0',
				  
					  -- Command interface
					  INIT_ENC28J60 	=> buttons_edge(3),
					  DHCP_CONNECT 	=> buttons_edge(4),
					  TCP_CONNECT 		=> buttons_edge(5),
					  ERROR_OUT 		=> eth_command_err,
					  
					  -- Data Interface
					  ADDR_IN 	=> addr_bus,
					  DATA_OUT 	=> data_bus,
					  
					  DEBUG_IN	=> debug_i,
					  DEBUG_OUT	=> sseg_data,
					  
					  -- TCP Connection Interface
					  TCP_RD_DATA_AVAIL_OUT => open,
					  TCP_RD_DATA_EN_IN 		=> tcp_rd_en,
					  TCP_RD_DATA_OUT 		=> open,
					  
					  CLK_1HZ_IN	=> clk_1hz,
					  
					  -- Eth SPI interface
					  SDI_OUT 	=> sdi_buf,
					  SDO_IN 	=> sdo_buf,
					  SCLK_OUT 	=> sclk_buf,
					  CS_OUT 	=> cs_buf,
					  INT_IN 	=> INT);
					  
	process(clk_25MHz)
	begin
		if rising_edge(clk_100MHz) then
			if clk_div_counter = X"00" then
				clk_div_counter <= unsigned(SW_IN);
			else
				clk_div_counter <= clk_div_counter - 1;
			end if;
			if clk_div_counter = X"00" then
				tcp_rd_en <= '1';
			else
				tcp_rd_en <= '0';
			end if;
		end if;
	end process;
							

end Behavioral;

