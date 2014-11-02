----------------------------------------------------------------------------------
-- Company: 
-- Engineer: CW
-- 
-- Create Date:    21:25:31 10/06/2014 
-- Design Name: 
-- Module Name:    top_ps2keyboard - Behavioral 
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

entity top_ps2keyboard is
    Port ( CLK_IN 		: in STD_LOGIC;
           RX_IN 			: in  STD_LOGIC;
           TX_OUT 		: out  STD_LOGIC;
           LED_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
           SSEG_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
           AN_OUT 		: out STD_LOGIC_VECTOR (3 downto 0);
           SW_IN 			: in STD_LOGIC_VECTOR (7 downto 0);
           BUTTON_IN 	: in STD_LOGIC_VECTOR (3 downto 0);
			  
			  vgaRed			: out STD_LOGIC_VECTOR (2 downto 0);
			  vgaGreen		: out STD_LOGIC_VECTOR (2 downto 0);
			  vgaBlue		: out STD_LOGIC_VECTOR (1 downto 0);
			  Hsync			: out STD_LOGIC;
			  Vsync			: out STD_LOGIC;
			  
			  RESET			: out STD_LOGIC);
end top_ps2keyboard;

architecture Behavioral of top_ps2keyboard is

	COMPONENT CLK_Mod
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
				  DEBUG_OUT			: out STD_LOGIC_VECTOR(7 downto 0);
				  DEBUG_OUT2		: out STD_LOGIC_VECTOR(7 downto 0));
	END COMPONENT;

	COMPONENT spi_master
    Generic (   
        N : positive := 32;                                             -- 32bit serial word length is default
        CPOL : std_logic := '0';                                        -- SPI mode selection (mode 0 default)
        CPHA : std_logic := '0';                                        -- CPOL = clock polarity, CPHA = clock phase.
        PREFETCH : positive := 2;                                       -- prefetch lookahead cycles
        SPI_2X_CLK_DIV : positive := 5);                                -- for a 100MHz sclk_i, yields a 10MHz SCK
    Port (  
        sclk_i : in std_logic := 'X';                                   -- high-speed serial interface system clock
        pclk_i : in std_logic := 'X';                                   -- high-speed parallel interface system clock
        rst_i : in std_logic := 'X';                                    -- reset core
        ---- serial interface ----
        spi_ssel_o : out std_logic;                                     -- spi bus slave select line
        spi_sck_o : out std_logic;                                      -- spi bus sck
        spi_mosi_o : out std_logic;                                     -- spi bus mosi output
        spi_miso_i : in std_logic := 'X';                               -- spi bus spi_miso_i input
        ---- parallel interface ----
        di_req_o : out std_logic;                                       -- preload lookahead data request line
        di_i : in  std_logic_vector (N-1 downto 0) := (others => 'X');  -- parallel data in (clocked on rising spi_clk after last bit)
        wren_i : in std_logic := 'X';                                   -- user data write enable, starts transmission when interface is idle
        wr_ack_o : out std_logic;                                       -- write acknowledge
        do_valid_o : out std_logic;                                     -- do_o data valid signal, valid during one spi_clk rising edge.
        do_o : out  std_logic_vector (N-1 downto 0);                    -- parallel output (clocked on rising spi_clk after last bit)
        --- debug ports: can be removed or left unconnected for the application circuit ---
        sck_ena_o : out std_logic;                                      -- debug: internal sck enable signal
        sck_ena_ce_o : out std_logic;                                   -- debug: internal sck clock enable signal
        do_transfer_o : out std_logic;                                  -- debug: internal transfer driver
        wren_o : out std_logic;                                         -- debug: internal state of the wren_i pulse stretcher
        rx_bit_reg_o : out std_logic;                                   -- debug: internal rx bit
        state_dbg_o : out std_logic_vector (3 downto 0);                -- debug: internal state register
        core_clk_o : out std_logic;
        core_n_clk_o : out std_logic;
        core_ce_o : out std_logic;
        core_n_ce_o : out std_logic;
        sh_reg_dbg_o : out std_logic_vector (N-1 downto 0)              -- debug: internal shift register
    );                      
	END COMPONENT;

subtype slv is std_logic_vector;

signal clk_25MHz : std_logic;

signal char_addr, font_addr	: std_logic_vector(11 downto 0);
signal char_data, font_data	: std_logic_vector(7 downto 0);
signal r, g, b 					: std_logic := '0';
signal octl							: std_logic_vector(7 downto 0);
signal ocrx, ocry 				: std_logic_vector(7 downto 0) := (others => '0');

signal sseg_data : std_logic_vector(15 downto 0) := (others => '0');

begin

	RESET <= '1';
	
	CLK_Mod_Inst : CLK_Mod
	PORT MAP ( 	CLK_50MHz_IN 	=> CLK_IN,
					CLK_25Mhz_OUT 	=> clk_25MHz);
	
-----------------------------------------------
	
	sseg_inst : sseg
	PORT MAP (	
		CLK    	=> clk_25MHz,
		VAL_IN 	=> sseg_data,
		SSEG_OUT	=> SSEG_OUT,
		AN_OUT   => AN_OUT);

-----------------------------------------------

	vgaRed <= r&r&r;
	vgaGreen <= g&g&g;
	vgaBlue <= b&b;
	octl <= "11100" & SW_IN(2 downto 0);
	
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
				DEBUG_OUT			=> sseg_data(7 downto 0),
				DEBUG_OUT2			=> LED_OUT);


end Behavioral;

