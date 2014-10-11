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
           PS2C_INOUT 	: inout STD_LOGIC;
           PS2D_INOUT 	: inout STD_LOGIC;
           LED_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
           SSEG_OUT 		: out STD_LOGIC_VECTOR (7 downto 0);
           AN_OUT 		: out STD_LOGIC_VECTOR (3 downto 0);
           SW_IN 			: in STD_LOGIC_VECTOR (7 downto 0);
           BUTTON_IN 	: in STD_LOGIC_VECTOR (3 downto 0);
			  
			  vgaRed			: out STD_LOGIC_VECTOR (2 downto 0);
			  vgaGreen		: out STD_LOGIC_VECTOR (2 downto 0);
			  vgaBlue		: out STD_LOGIC_VECTOR (1 downto 0);
			  Hsync			: out STD_LOGIC;
			  Vsync			: out STD_LOGIC);
end top_ps2keyboard;

architecture Behavioral of top_ps2keyboard is

	COMPONENT PS2INTERFACE
	PORT (
		ps2_clk  : inout std_logic;
		ps2_data : inout std_logic;

		clk      : in std_logic;
		rst      : in std_logic;

		tx_data  : in std_logic_vector(7 downto 0);
		write    : in std_logic;
		
		rx_data  : out std_logic_vector(7 downto 0);
		read     : out std_logic;
		busy     : out std_logic;
		err      : out std_logic);
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

	COMPONENT blk_mem_gen_v7_2
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	  );
	END COMPONENT;

signal clk_25MHz, clk_50mhz : std_logic;
signal clk_1x, clk_1x_bufg :std_logic:='0';
signal clk0_2xout_tmp, clk0_2xout_bufg, clk0_div2out, clk0_div2out_bufg :std_logic:='0';

signal r, g, b 		: std_logic := '0';
signal font_addr		: std_logic_vector(11 downto 0);
signal font_data		: std_logic_vector(7 downto 0);

signal keyboard_data : std_logic_vector(15 downto 0) := (others => '0');

signal sseg_data : std_logic_vector(15 downto 0) := (others => '0');

begin

	LED_OUT <= SW_IN;
	
	ps2interface_inst : ps2interface
	PORT MAP (
		ps2_clk  => PS2C_INOUT,
		ps2_data => PS2D_INOUT,

		clk      => clk_25MHz,
		rst      => '0',

		tx_data  => (others => '0'),
		write    => '0',

		rx_data  => keyboard_data(7 downto 0),
		read     => open,
		busy     => open,
		err      => open);
	
	sseg_data <= "0000" & font_addr;
	
	sseg_inst : sseg
	PORT MAP (	
		CLK    	=> clk_25MHz,
		VAL_IN 	=> sseg_data,
		SSEG_OUT	=> SSEG_OUT,
		AN_OUT   => AN_OUT);

	clk_25MHz <= clk0_div2out_bufg;
	
 	U0_BUFG : BUFG
    port map (I => clk0_2xout_tmp, O => clk0_2xout_bufg);
	U02_BUFG : BUFG
    port map (I => clk0_div2out, O => clk0_div2out_bufg);

	DCM_SP_inst : DCM_SP
   generic map (
      CLKDV_DIVIDE => 2.0,                   -- CLKDV divide value (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
      CLKFX_DIVIDE => 1,                     -- Divide value on CLKFX outputs - D - (1-32)
      CLKFX_MULTIPLY => 2,                   -- Multiply value on CLKFX outputs - M - (2-32)
      CLKIN_DIVIDE_BY_2 => FALSE,            -- CLKIN divide by two (TRUE/FALSE)
      CLKIN_PERIOD => 20.0,                  -- Input clock period specified in nS
      CLKOUT_PHASE_SHIFT => "NONE",          -- Output phase shift (NONE, FIXED, VARIABLE)
      CLK_FEEDBACK => "2X",                  -- Feedback source (NONE, 1X, 2X)
      DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS", -- SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
      DFS_FREQUENCY_MODE => "LOW",           -- Unsupported - Do not change value
      DLL_FREQUENCY_MODE => "LOW",           -- Unsupported - Do not change value
      DSS_MODE => "NONE",                    -- Unsupported - Do not change value
      DUTY_CYCLE_CORRECTION => TRUE,         -- Unsupported - Do not change value
      FACTORY_JF => X"c080",                 -- Unsupported - Do not change value
      PHASE_SHIFT => 0,                      -- Amount of fixed phase shift (-255 to 255)
      STARTUP_WAIT => FALSE                  -- Delay configock frequency clock output
		)
   port map (
      CLK2X180 => open, 				-- 1-bit output: 2X clock frequency, 180 degree clock output
      CLK90 	=> open,       		-- 1-bit output: 90 degree clock output
      CLKDV 	=> clk0_div2out,     -- 1-bit output: Divided clock output
      CLKFX 	=> open,       		-- 1-bit output: Digital Frequency Synthesizer output (DFS)
      CLKFX180 => open, 				-- 1-bit output: 180 degree CLKFX output
      LOCKED 	=> open,     			-- 1-bit output: DCM_SP Lock Output
      PSDONE 	=> open,     			-- 1-bit output: Phase shift done output
      STATUS 	=> open,     			-- 8-bit output: DCM_SP status output
      CLKFB 	=> clk0_2xout_bufg,  -- 1-bit input: Cl DONE until DCM_SP LOCKED (TRUE/FALSE)
      CLK0 		=> open,        		-- 1-bit output: 0 degree clock output
      CLK180 	=> open,     			-- 1-bit output: 180 degree clock output
      CLK270 	=> open,     			-- 1-bit output: 270 degree clock output
      CLK2X 	=> clk0_2xout_tmp,   -- 1-bit output: 2X clock feedback input
      CLKIN 	=> CLK_IN,       		-- 1-bit input: Clock input
      DSSEN 	=> '0',       			-- 1-bit input: Unsupported, specify to GND.
      PSCLK 	=> '0',       			-- 1-bit input: Phase shift clock input
      PSEN 		=> '0',         		-- 1-bit input: Phase shift enable
      PSINCDEC => '0', 					-- 1-bit input: Phase shift increment/decrement input
      RST 		=> '0'            	-- 1-bit input: Active high reset input
   );

	vgaRed <= r&r&r;
	vgaGreen <= g&g&g;
	vgaBlue <= b&b;
		
	vga80x40_inst : vga80x40
	PORT MAP (	
		 reset       =>  '0',
		 clk25MHz    => clk_25MHz,
		 TEXT_A      => open,
		 TEXT_D      => keyboard_data(7 downto 0),
		 FONT_A      => font_addr,
		 FONT_D      => font_data,
		 --
		 ocrx        => X"10",
		 ocry        => X"10",
		 octl        => "11100010",
		 --
		 R           => r,
		 G           => g,
		 B           => b,
		 hsync       => Hsync,
		 vsync       => Vsync);
		 
	blk_mem_gen_v7_2_inst : blk_mem_gen_v7_2
	  PORT MAP (
		 clka 	=> clk_25MHz,
		 wea 		=> "0",
		 addra 	=> font_addr,
		 dina 	=> (others => '0'),
		 douta 	=> font_data);
		 
end Behavioral;

