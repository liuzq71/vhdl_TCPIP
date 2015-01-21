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
				RX_IN 		: in  STD_LOGIC;
				TX_OUT 		: out  STD_LOGIC;
				LED_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
				SSEG_OUT 	: out STD_LOGIC_VECTOR (7 downto 0);
				AN_OUT 		: out STD_LOGIC_VECTOR (3 downto 0);
				SW_IN 		: in STD_LOGIC_VECTOR (7 downto 0);
				BUTTON_IN 	: in STD_LOGIC_VECTOR (3 downto 0);

				vgaRed		: out STD_LOGIC_VECTOR (2 downto 0);
				vgaGreen		: out STD_LOGIC_VECTOR (2 downto 0);
				vgaBlue		: out STD_LOGIC_VECTOR (1 downto 0);
				Hsync			: out STD_LOGIC;
				Vsync			: out STD_LOGIC;
				
				SDI			: in STD_LOGIC;
				SDO			: out STD_LOGIC;
				SCLK 			: out STD_LOGIC;
				CS				: out STD_LOGIC;
				INT			: in STD_LOGIC;
				RESET			: out STD_LOGIC);
end vault;

architecture Behavioral of vault is

	COMPONENT clk_mod
		 Port ( CLK_50MHz_IN 	: in  STD_LOGIC;
				  CLK_25Mhz_OUT 	: out  STD_LOGIC);
	END COMPONENT;
	
	COMPONENT sseg
	PORT (	
		CLK    : in STD_LOGIC;
		VAL_IN  	: in STD_LOGIC_VECTOR (15 downto 0);
		SSEG_OUT	: out STD_LOGIC_VECTOR(7 downto 0);
		AN_OUT   : out STD_LOGIC_VECTOR(3 downto 0));
	END COMPONENT;

	COMPONENT vga80x40
	  PORT (
		 reset       : in  std_logic;
		 clk25MHz    : in  std_logic;
		 TEXT_A      : out std_logic_vector(11 downto 0);
		 TEXT_D      : in  std_logic_vector(07 downto 0);
		 FONT_A      : out std_logic_vector(11 downto 0);
		 FONT_D      : in  std_logic_vector(07 downto 0);
		 --
		 ocrx        : in  std_logic_vector(07 downto 0);
		 ocry        : in  std_logic_vector(07 downto 0);
		 octl        : in  std_logic_vector(07 downto 0);
		 --
		 R           : out std_logic;
		 G           : out std_logic;
		 B           : out std_logic;
		 hsync       : out std_logic;
		 vsync       : out std_logic);   
	END COMPONENT;
	
	COMPONENT user_input_handler
		 PORT ( CLK_IN 			: in  STD_LOGIC;
				  
				  RX_IN 				: in  STD_LOGIC;
				  TX_OUT 			: out  STD_LOGIC;
				  
				  TEXT_ADDR_IN 	: in  STD_LOGIC_VECTOR (11 downto 0);
				  TEXT_DATA_OUT 	: out  STD_LOGIC_VECTOR (7 downto 0);
				  FONT_ADDR_IN 	: in  STD_LOGIC_VECTOR (11 downto 0);
				  FONT_DATA_OUT 	: out  STD_LOGIC_VECTOR (7 downto 0);
				  CURSORPOS_X_OUT : out  STD_LOGIC_VECTOR (7 downto 0);
				  CURSORPOS_Y_OUT : out  STD_LOGIC_VECTOR (7 downto 0);
				  
				  ADDR_OUT				: out STD_LOGIC_VECTOR(7 downto 0);
				  DATA_IN				: in STD_LOGIC_VECTOR(7 downto 0);
				  
				  ETH_COMMAND_OUT			: out STD_LOGIC_VECTOR(3 downto 0);
				  ETH_COMMAND_EN_OUT		: out STD_LOGIC;
				  ETH_COMMAND_CMPLT_IN	: in STD_LOGIC;
				  ETH_COMMAND_ERR_IN		: in STD_LOGIC_VECTOR(7 downto 0);
				  
				  CLK_1HZ_IN	: in STD_LOGIC;
				  
				  DEBUG_OUT		: out STD_LOGIC_VECTOR(7 downto 0);
				  DEBUG_OUT2	: out STD_LOGIC_VECTOR(7 downto 0));
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
           COMMAND_IN			: in  STD_LOGIC_VECTOR (3 downto 0);
			  COMMAND_EN_IN		: in 	STD_LOGIC;
           COMMAND_CMPLT_OUT 	: out STD_LOGIC;
           ERROR_OUT 			: out  STD_LOGIC_VECTOR (7 downto 0);
			  
			  -- Data Interface
			  ADDR_IN	: in  STD_LOGIC_VECTOR (7 downto 0);
			  DATA_OUT	: out  STD_LOGIC_VECTOR (7 downto 0);
			  
			  DEBUG_IN 	: in STD_LOGIC;
			  DEBUG_OUT	: out  STD_LOGIC_VECTOR (15 downto 0);
			  
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
	END COMPONENT;

subtype slv is std_logic_vector;

signal clk_25MHz : std_logic;

signal clk_1hz : std_logic;

signal char_addr, font_addr	: std_logic_vector(11 downto 0);
signal char_data, font_data	: std_logic_vector(7 downto 0);
signal debug_addr	: std_logic_vector(11 downto 0);
signal debug_data	: std_logic_vector(7 downto 0);
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
signal buttons, buttons_prev, buttons_edge	: std_logic_vector(3 downto 0) := (others => '0');
signal debounce_count								: unsigned(15 downto 0) := (others => '0');

signal data_bus, addr_bus 	: std_logic_vector(7 downto 0) := (others => '0');
signal eth_command 			: std_logic_vector(3 downto 0);
signal eth_command_err		: std_logic_vector(7 downto 0);
signal eth_command_en, eth_command_cmplt : std_logic;
	
begin
	
	clk_mod_Inst : clk_mod
	PORT MAP ( 	CLK_50MHz_IN 	=> CLK_IN,
					CLK_25Mhz_OUT 	=> clk_25MHz);
	
--------------------------- DEBUG LOGIC ------------------------------
	
	LED_OUT(7 downto 3) <= (others => '0');
	
	sseg_inst : sseg
	PORT MAP (	
		CLK    	=> clk_25MHz,
		VAL_IN 	=> sseg_data,
		SSEG_OUT	=> SSEG_OUT,
		AN_OUT   => AN_OUT);
	
	process(clk_25MHz)
	begin
		if rising_edge(clk_25MHz) then
			debounce_count <= debounce_count + 1;
			buttons_prev <= buttons;
			if debounce_count = X"0000" then
				buttons <= BUTTON_IN;
			end if;
			if buttons_prev(0) = '0' and buttons(0) = '1' then
				buttons_edge(0) <= '1';
			else
				buttons_edge(0) <= '0';
			end if;
			if buttons_prev(1) = '0' and buttons(1) = '1' then
				buttons_edge(1) <= '1';
			else
				buttons_edge(1) <= '0';
			end if;
			if buttons_prev(2) = '0' and buttons(2) = '1' then
				buttons_edge(2) <= '1';
			else
				buttons_edge(2) <= '0';
			end if;
			if buttons_prev(3) = '0' and buttons(3) = '1' then
				buttons_edge(3) <= '1';
			else
				buttons_edge(3) <= '0';
			end if;
		end if;
	end process;

--------------------------- UI I/O ------------------------------

	led_mod_inst : led_mod
    Port Map ( CLK_IN 				=> clk_25MHz,
					LED_STATE_IN 		=> "001",
					ERROR_CODE_IN		=> "11001",
					ERROR_CODE_EN_IN	=> '0',
					LEDS_OUT 			=> LED_OUT(1 downto 0),
					
					CLK_1HZ_OUT			=> clk_1hz);

	vgaRed <= r&r&r;
	vgaGreen <= g&g&g;
	vgaBlue <= b&b;
	octl <= "11100111";
	
	vga80x40_inst : vga80x40
	PORT MAP (	
		 reset       =>  '0',
		 clk25MHz    => clk_25MHz,
		 TEXT_A      => char_addr,
		 TEXT_D      => char_data,
		 FONT_A      => font_addr,
		 FONT_D      => font_data,

		 ocrx        => slv(ocrx),
		 ocry        => slv(ocry),
		 octl        => octl,

		 R           => r,
		 G           => g,
		 B           => b,
		 hsync       => Hsync,
		 vsync       => Vsync);

	user_input_handler_inst : user_input_handler
	PORT MAP (	
				CLK_IN 				=> clk_25MHz,
				RX_IN 				=> RX_IN,
				TX_OUT 				=> TX_OUT,
				
				TEXT_ADDR_IN 		=> char_addr,
				TEXT_DATA_OUT 		=> char_data,
				FONT_ADDR_IN 		=> font_addr,
				FONT_DATA_OUT 		=> font_data,
				CURSORPOS_X_OUT 	=> ocrx,
				CURSORPOS_Y_OUT 	=> ocry,
				
				ADDR_OUT					=> addr_bus,
				DATA_IN					=> data_bus,
				
				ETH_COMMAND_OUT		=> eth_command,
			   ETH_COMMAND_EN_OUT	=> eth_command_en,
				ETH_COMMAND_CMPLT_IN	=> eth_command_cmplt,
				ETH_COMMAND_ERR_IN	=> eth_command_err,
				
				CLK_1HZ_IN	=> clk_1hz,
				
				DEBUG_OUT			=> open,
				DEBUG_OUT2			=> open);
				
------------------------- Ethernet I/O --------------------------------

	sseg_data(15 downto 8) <= addr_bus;
	sseg_data(7 downto 0) <= data_bus;
	RESET <= '0';

	eth_mod_inst : eth_mod
		 Port Map ( CLK_IN 	=> clk_25MHz,
						RESET_IN => '0',
				  
					  -- Command interface
					  COMMAND_IN			=> eth_command,
					  COMMAND_EN_IN		=> eth_command_en,
					  COMMAND_CMPLT_OUT 	=> eth_command_cmplt,
					  ERROR_OUT 			=> eth_command_err,
					  
					  -- Data Interface
					  ADDR_IN 	=> addr_bus,
					  DATA_OUT 	=> data_bus,
					  
					  DEBUG_IN	=> buttons(1),
					  DEBUG_OUT	=> open,
					  
					  -- TCP Connection Interface
					  TCP_RD_DATA_AVAIL_OUT => LED_OUT(2),
					  TCP_RD_DATA_EN_IN 		=> buttons(2),
					  TCP_RD_DATA_OUT 		=> open,
					  
					  -- Eth SPI interface
					  SDI_OUT 	=> SDO,
					  SDO_IN 	=> SDI,
					  SCLK_OUT 	=> SCLK,
					  CS_OUT 	=> CS,
					  INT_IN 	=> INT);

end Behavioral;

