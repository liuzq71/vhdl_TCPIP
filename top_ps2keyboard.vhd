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

entity hw_client is
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

				SF_DATA			: inout std_logic_vector(15 downto 0);
				SF_ADDR			: out std_logic_vector(23 downto 1);
				SF_CS_BAR		: out std_logic;
				SF_WR_BAR		: out std_logic;
				SF_OE_BAR		: out std_logic;
				SF_RESET_BAR	: out std_logic;
				SF_STATUS		: in std_logic;

				SDI			: in STD_LOGIC;
				SDO			: out STD_LOGIC;
				SCLK 			: out STD_LOGIC;
				CS				: out STD_LOGIC;
				INT			: in STD_LOGIC;
				RESET			: out STD_LOGIC);
end hw_client;

architecture Behavioral of hw_client is

	COMPONENT clk_mod
		 Port ( CLK_50MHz_IN 	: in  STD_LOGIC;
				  CLK_25Mhz_OUT 	: out  STD_LOGIC;
				  CLK_100Mhz_OUT 	: out STD_LOGIC);
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
				  DEBUG_OUT			: out STD_LOGIC_VECTOR(7 downto 0);
				  DEBUG_OUT2		: out STD_LOGIC_VECTOR(7 downto 0));
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

	COMPONENT led_mod is
    Port ( CLK_IN 				: in  STD_LOGIC;
           LED_STATE_IN 		: in  STD_LOGIC_VECTOR (2 downto 0);
			  ERROR_CODE_IN		: in	STD_LOGIC_VECTOR (4 downto 0);
			  ERROR_CODE_EN_IN	: in	STD_LOGIC;
           LEDS_OUT 				: out  STD_LOGIC_VECTOR (1 downto 0));
	END COMPONENT;
	
	COMPONENT sf_mod is
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
	END COMPONENT;

	COMPONENT eth_mod is
    Port ( CLK_IN 	: in  STD_LOGIC;
			  CLK2_IN 	: in  STD_LOGIC;
           RESET_IN 	: in  STD_LOGIC;
			  
			  -- Command interface
           COMMAND_IN			: in  STD_LOGIC_VECTOR (7 downto 0);
			  COMMAND_EN_IN		: in 	STD_LOGIC;
           COMMAND_CMPLT_OUT 	: out STD_LOGIC;
           ERROR_OUT 			: out  STD_LOGIC_VECTOR (7 downto 0);
			  DEBUG_IN 				: in STD_LOGIC;
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
	END COMPONENT;

subtype slv is std_logic_vector;

signal clk_25MHz, clk_100MHz : std_logic;

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

begin

	RESET <= SW_IN(7);
	
	clk_mod_Inst : clk_mod
	PORT MAP ( 	CLK_50MHz_IN 	=> CLK_IN,
					CLK_25Mhz_OUT 	=> clk_25MHz,
					CLK_100Mhz_OUT => clk_100MHz);
	
--------------------------- DEBUG LOGIC ------------------------------
	
	sseg_inst : sseg
	PORT MAP (	
		CLK    	=> clk_25MHz,
		VAL_IN 	=> sseg_data,
		SSEG_OUT	=> SSEG_OUT,
		AN_OUT   => AN_OUT);
	
	led_mod_inst : led_mod
    Port Map ( CLK_IN 				=> clk_25MHz,
					LED_STATE_IN 		=> "001",
					ERROR_CODE_IN		=> "11001",
					ERROR_CODE_EN_IN	=> '0',
					LEDS_OUT 			=> open); -- LED_OUT(1 downto 0));
	
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

	vgaRed <= r&r&r;
	vgaGreen <= g&g&g;
	vgaBlue <= b&b;
	octl <= "11100111";
	
	vga80x40_inst : vga80x40
	PORT MAP (	
		 reset       =>  '0',
		 clk25MHz    => clk_25MHz,
		 TEXT_A      => debug_addr, --char_addr,
		 TEXT_D      => debug_data, --char_data,
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
				DEBUG_OUT			=> open,
				DEBUG_OUT2			=> debug_wr_data);
				
	debug_buf : TDP_RAM
	Generic Map ( G_DATA_A_SIZE 	=> debug_data'length,
					  G_ADDR_A_SIZE	=> debug_addr'length,
					  G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
					  G_INIT_FILE		=> "./coe_dir/ascii_space.coe")
   Port Map ( CLK_A_IN 		=> clk_25MHz,
				  WE_A_IN 		=> '0',
				  ADDR_A_IN 	=> debug_addr,
				  DATA_A_IN		=> X"00",
				  DATA_A_OUT	=> debug_data,
				  CLK_B_IN 		=> clk_25MHz,
				  WE_B_IN 		=> debug_we,
				  ADDR_B_IN 	=> slv(debug_wr_addr),
				  DATA_B_IN 	=> "00000000",
				  DATA_B_OUT 	=> open);

------------------------- Ethernet Config --------------------------------

	eth_mod_inst : eth_mod
		 Port Map ( CLK_IN 	=> clk_25MHz,
						CLK2_IN	=> clk_100MHz,
						RESET_IN => '0',
				  
					  -- Command interface
					  COMMAND_IN			=> SW_IN,
					  COMMAND_EN_IN		=> buttons_edge(1),
					  COMMAND_CMPLT_OUT 	=> LED_OUT(1),
					  ERROR_OUT 			=> open,
					  DEBUG_IN				=> buttons(2),
					  DEBUG_OUT				=> sseg_data,
					  
					  -- Flash mod ctrl interface
					  FRAME_ADDR_OUT 				=> frame_addr,
					  FRAME_DATA_IN 				=> frame_data,
					  FRAME_DATA_RD_OUT 			=> frame_rd,
					  FRAME_DATA_RD_CMPLT_IN 	=> frame_rd_cmplt,
					  
					  -- Eth SPI interface
					  SDI_OUT 	=> SDO,
					  SDO_IN 	=> SDI,
					  SCLK_OUT 	=> SCLK,
					  CS_OUT 	=> CS,
					  INT_IN 	=> INT);

------------------------- STRATA FLASH --------------------------------

	LED_OUT(7 downto 2) <= (others => '0');

	sf_mod_inst : sf_mod
    Port Map ( 	CLK_IN 				=> clk_25MHz,
						RESET_IN 			=> '0',
			  
					  -- Command interface
					  INIT_IN 				=> buttons_edge(0),
					  INIT_CMPLT_OUT		=> LED_OUT(0),
					  ERROR_OUT				=> open,
					  
					  -- Ethernet command interface
					  ADDR_IN				=> frame_addr,
					  DATA_OUT 				=> frame_data,
					  RD_IN					=> frame_rd,
					  RD_CMPLT_OUT			=> frame_rd_cmplt,
					  
					  -- Flash interface
					  SF_DATA_IN 			=> SF_DATA,
					  SF_ADDR_OUT 			=> SF_ADDR,
					  SF_CS_BAR_OUT 		=> SF_CS_BAR,
					  SF_OE_BAR_OUT 		=> SF_OE_BAR,
					  SF_WR_BAR_OUT		=> SF_WR_BAR,
					  SF_RESET_BAR_OUT 	=> SF_RESET_BAR,
					  SF_STATUS_IN 		=> SF_STATUS);

end Behavioral;

