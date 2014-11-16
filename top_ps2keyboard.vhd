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
			  
			  SDI				: out STD_LOGIC;
			  SDO				: in STD_LOGIC;
			  SCLK 			: out STD_LOGIC;
			  CS				: out STD_LOGIC;
			  RESET			: out STD_LOGIC);
end hw_client;

architecture Behavioral of hw_client is

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
				  DEBUG_OUT			: out STD_LOGIC_VECTOR(7 downto 0);
				  DEBUG_OUT2		: out STD_LOGIC_VECTOR(7 downto 0));
	END COMPONENT;

	COMPONENT spi_master
    Generic (   
        N : positive := 16;                                             -- 8bit serial word length is default
        CPOL : std_logic := '0';                                        -- SPI mode selection (mode 0 default)
        CPHA : std_logic := '0';                                        -- CPOL = clock polarity, CPHA = clock phase.
        PREFETCH : positive := 2;                                       -- prefetch lookahead cycles
        SPI_2X_CLK_DIV : positive := 5);                                -- for a 100MHz sclk_i, yields a 10MHz SCK
    Port (
        sclk_i : in std_logic := 'X';                                   -- high-speed serial interface system clock
        pclk_i : in std_logic := 'X';                                   -- high-speed parallel interface system clock
        rst_i : in std_logic := 'X';                                    -- reset core
        ---- serial interface ----
        spi_ssel_o 	: out std_logic;                                     -- spi bus slave select line
        spi_sck_o 	: out std_logic;                                      -- spi bus sck
        spi_mosi_o 	: out std_logic;                                     -- spi bus mosi output
        spi_miso_i 	: in std_logic := 'X';                               -- spi bus spi_miso_i input
        ---- parallel interface ----
        di_req_o 		: out std_logic;                                       -- preload lookahead data request line
        di_i 			: in  std_logic_vector (N-1 downto 0) := (others => 'X');  -- parallel data in (clocked on rising spi_clk after last bit)
        wren_i 		: in std_logic := 'X';                                   -- user data write enable, starts transmission when interface is idle
        wr_ack_o 		: out std_logic;                                       -- write acknowledge
        do_valid_o 	: out std_logic;                                     -- do_o data valid signal, valid during one spi_clk rising edge.
        do_o 			: out  std_logic_vector (N-1 downto 0)                     -- parallel output (clocked on rising spi_clk after last bit)
    );                      
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

signal clk_25MHz : std_logic;

signal char_addr, font_addr	: std_logic_vector(11 downto 0);
signal char_data, font_data	: std_logic_vector(7 downto 0);
signal debug_addr	: std_logic_vector(11 downto 0);
signal debug_data	: std_logic_vector(7 downto 0);
signal r, g, b 					: std_logic := '0';
signal octl							: std_logic_vector(7 downto 0);
signal ocrx, ocry 				: std_logic_vector(7 downto 0) := (others => '0');

signal sseg_data : std_logic_vector(15 downto 0) := (others => '0');

signal di_req_o, di_req_o_p 		: std_logic := '0';
signal sw_p, sw_pp, spi_we 		: std_logic := '0';
signal do_valid_o, do_valid_o_p 	: std_logic := '0';
signal debug_we : std_logic := '0';
signal debug_wr_addr : unsigned(11 downto 0) := (others => '0');
signal debug_wr_data : std_logic_vector(7 downto 0) := (others => '0');
signal do_o, tmp : std_logic_vector(15 downto 0);

begin

	RESET <= SW_IN(0);
	
	clk_mod_Inst : clk_mod
	PORT MAP ( 	CLK_50MHz_IN 	=> CLK_IN,
					CLK_25Mhz_OUT 	=> clk_25MHz);
	
---------------------------------------------------------
	
	sseg_inst : sseg
	PORT MAP (	
		CLK    	=> clk_25MHz,
		VAL_IN 	=> sseg_data,
		SSEG_OUT	=> SSEG_OUT,
		AN_OUT   => AN_OUT);
		
	sseg_data <= do_o;

---------------------------------------------------------

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

---------------------------------------------------------

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

---------------------------------------------------------

	LED_OUT(7 downto 4) <= debug_wr_data(3 downto 0);
	LED_OUT(3 downto 1) <= "000";

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			di_req_o_p <= di_req_o;
			if di_req_o_p = '0' and di_req_o = '1' then
				LED_OUT(0) <= '1';
			elsif SW_IN(2) = '1' then
				LED_OUT(0) <= '0';
			end if;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			sw_p <= SW_IN(3);
			sw_pp <= sw_p;
			if sw_pp = '0' and sw_p = '1' then
				spi_we <= '1';
			elsif SW_IN(2) = '1' then
				spi_we <= '0';
			end if;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			do_valid_o_p <= do_valid_o;
			if do_valid_o_p = '0' and do_valid_o = '1' then
				debug_we <= '1';
			else
				debug_we <= '0';
			end if;
			if debug_we = '1' then
				debug_wr_addr <= debug_wr_addr + 1;
			end if;
		end if;
	end process;

	spi_master_inst : spi_master
    Generic Map (   
        N 					=> 16,			-- 8bit serial word length is default
        CPOL 				=> '0',			-- SPI mode selection (mode 0 default)
        CPHA 				=> '0',			-- CPOL = clock polarity, CPHA = clock phase.
        PREFETCH 			=> 2,				-- prefetch lookahead cycles
        SPI_2X_CLK_DIV 	=> 10)			-- for a 25MHz sclk_i, yields a 1.25MHz SCK
    Port Map (
        sclk_i 		=> clk_25MHz,		-- high-speed serial interface system clock
        pclk_i 		=> clk_25MHz,		-- high-speed parallel interface system clock
        rst_i 			=> SW_IN(1),		-- reset core
		  
        ---- serial interface ----
        spi_ssel_o 	=> CS,                              -- spi bus slave select line
        spi_sck_o 	=> SCLK,                            -- spi bus sck
        spi_mosi_o 	=> SDI,                             -- spi bus mosi output
        spi_miso_i 	=> SDO,                            	-- spi bus spi_miso_i input
        
		  ---- parallel interface ----
        di_req_o 		=> di_req_o,  	-- preload lookahead data request line
        di_i 			=> tmp, 	-- parallel data in (clocked on rising spi_clk after last bit)
        wren_i 		=> spi_we,		-- user data write enable, starts transmission when interface is idle
        wr_ack_o 		=> open,			-- write acknowledge
        do_valid_o 	=> do_valid_o, -- do_o data valid signal, valid during one spi_clk rising edge.
        do_o 			=> do_o        -- parallel output (clocked on rising spi_clk after last bit)
    );

	tmp <= SW_IN(7 downto 4) & debug_wr_data(3 downto 0) & "00000000";

	debug_buf : TDP_RAM
	Generic Map ( G_DATA_A_SIZE 	=> debug_data'length,
					  G_ADDR_A_SIZE	=> debug_addr'length,
					  G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
					  G_INIT_FILE		=> "./coe_dir/ascii_space.coe")
   Port Map ( CLK_A_IN 		=> CLK_IN,
				  WE_A_IN 		=> '0',
				  ADDR_A_IN 	=> debug_addr,
				  DATA_A_IN		=> X"00",
				  DATA_A_OUT	=> debug_data,
				  CLK_B_IN 		=> CLK_IN,
				  WE_B_IN 		=> debug_we,
				  ADDR_B_IN 	=> slv(debug_wr_addr),
				  DATA_B_IN 	=> "00000000",
				  DATA_B_OUT 	=> open);

end Behavioral;

