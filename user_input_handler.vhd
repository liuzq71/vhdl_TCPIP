----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:39:01 10/19/2014 
-- Design Name: 
-- Module Name:    user_input_handler - Behavioral 
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

entity user_input_handler is
    Port ( CLK_IN 			: in  STD_LOGIC;
           RX_IN 				: in  STD_LOGIC;
           TX_OUT 			: out  STD_LOGIC;
           TEXT_ADDR_IN 	: in  STD_LOGIC_VECTOR (11 downto 0);
           TEXT_DATA_OUT 	: out STD_LOGIC_VECTOR (7 downto 0);
           FONT_ADDR_IN 	: in  STD_LOGIC_VECTOR (11 downto 0);
           FONT_DATA_OUT 	: out STD_LOGIC_VECTOR (7 downto 0);
           CURSORPOS_X_OUT : out STD_LOGIC_VECTOR (7 downto 0);
           CURSORPOS_Y_OUT : out STD_LOGIC_VECTOR (7 downto 0);
			  DEBUG_OUT			: out STD_LOGIC_VECTOR(7 downto 0);
			  DEBUG_OUT2		: out STD_LOGIC_VECTOR(7 downto 0));
end user_input_handler;

architecture Behavioral of user_input_handler is

	COMPONENT uart
	Generic (
		CLK_FREQ	: integer := 50;		-- Main frequency (MHz)
		SER_FREQ	: integer := 9600		-- Baud rate (bps)
	);
	Port (
		-- Control
		clk			: in	std_logic;							-- Main clock
		rst			: in	std_logic;							-- Main reset
		-- External Interface
		rx			: in	std_logic;								-- RS232 received serial data
		tx			: out	std_logic;								-- RS232 transmitted serial data
		-- RS232/UART Configuration
		par_en		: in	std_logic;							-- Parity bit enable
		-- uPC Interface
		tx_req		: in	std_logic;							-- Request SEND of data
		tx_end		: out	std_logic;							-- Data SENDED
		tx_data		: in	std_logic_vector(7 downto 0);	-- Data to transmit
		rx_ready		: out	std_logic;							-- Received data ready to uPC read
		rx_data		: out	std_logic_vector(7 downto 0)	-- Received data 
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

	COMPONENT FONT_MEM
	  PORT (
		 clka : IN STD_LOGIC;
		 wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		 addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
		 dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0));
	END COMPONENT;
	
subtype slv is std_logic_vector;

constant C_backspace_cmnd : std_logic_vector(7 downto 0) := X"80";
constant C_esc_cmnd : std_logic_vector(7 downto 0) 		:= X"81";
constant C_enter_cmnd : std_logic_vector(7 downto 0) 		:= X"82";

constant C_space_char : std_logic_vector(7 downto 0) := X"20";

constant C_max_char			: std_logic_vector(11 downto 0) := X"C2F"; -- 3119 (zero indexed)
constant C_page_height 		: std_logic_vector(7 downto 0) := X"26"; -- 39 (zero indexed)
constant C_page_width  		: std_logic_vector(7 downto 0) := X"4F"; -- 80 (zero indexed)
constant C_page_width_p1 	: std_logic_vector(7 downto 0) := X"50"; -- 80

signal char_buf_wr, char_cmd_wr : std_logic := '0';
signal char_buf_wr_addr : unsigned(11 downto 0) := (others => '0');
signal char_buf_wr_data : std_logic_vector(7 downto 0) := (others => '0');
signal ocrx, ocry : unsigned(7 downto 0) := (others => '0');

signal keyboard_data, keyboard_data_buf : std_logic_vector(7 downto 0) := (others => '0');
signal keyboard_rd : std_logic := '0';

signal char_buf_x_coord : unsigned(7 downto 0);

signal debug2 : unsigned(7 downto 0) := (others => '0');

type HANDLE_KEYBOARD_ST is (	IDLE,
										HANDLE_CHARACTER_S0,
										HANDLE_CHARACTER_S1,
										HANDLE_COMMAND,
										HANDLE_BACKSPACE_S0,
										HANDLE_BACKSPACE_S1,
										HANDLE_ENTER_S0,
										HANDLE_ENTER_S1);

signal hk_state, hk_next_state : HANDLE_KEYBOARD_ST := IDLE;

begin

	debug2 <= unsigned(keyboard_data);

	---- CONVERT UART DATA TO KEYBOARD DATA ----

	uart_inst : uart
	GENERIC MAP (
		CLK_FREQ	=> 25,
		SER_FREQ	=> 9600)
	Port Map (
		clk		=> CLK_IN,
		rst		=> '0',
		rx			=> RX_IN,
		tx			=> TX_OUT,
		par_en	=> '1',
		tx_req	=> '0',
		tx_end	=> open,
		tx_data	=> (others => '0'),
		rx_ready	=> keyboard_rd,
		rx_data	=> keyboard_data);

	---- HANDLE KEYBOARD DATA ----

   SYNC_PROC: process(CLK_IN)
   begin
      if rising_edge(CLK_IN) then
			hk_state <= hk_next_state;
      end if;
   end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if hk_state = IDLE and keyboard_rd = '1' then
				keyboard_data_buf <= keyboard_data;
			end if;
		end if;
	end process;
 
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if hk_state = HANDLE_CHARACTER_S0 then
				char_buf_wr <= '1';
			elsif hk_state = HANDLE_BACKSPACE_S1 then
				char_buf_wr <= '1';
			else
				char_buf_wr <= '0';
			end if;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if hk_state = HANDLE_CHARACTER_S0 then
				char_buf_wr_data <= keyboard_data_buf;
			elsif hk_state = HANDLE_BACKSPACE_S1 then
				char_buf_wr_data <= C_space_char;
			end if;
		end if;
	end process;

	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if hk_state = HANDLE_CHARACTER_S1 then
				char_buf_wr_addr <= char_buf_wr_addr + 1;
			elsif hk_state = HANDLE_BACKSPACE_S0 then
				char_buf_wr_addr <= char_buf_wr_addr - 1;
			elsif hk_state = HANDLE_ENTER_S1 then
				char_buf_wr_addr <= char_buf_wr_addr + RESIZE(char_buf_x_coord, 12);
			end if;
		end if;
	end process;
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if hk_state = HANDLE_ENTER_S0 then
				char_buf_x_coord <= unsigned(C_page_width_p1) - unsigned(ocrx);
			end if;
		end if;
	end process;
 
   NEXT_STATE_DECODE: process (hk_state, keyboard_rd, keyboard_data(7), keyboard_data_buf)
   begin
      hk_next_state <= hk_state;  --default is to stay in current state
      case (hk_state) is
         when IDLE =>
            if keyboard_rd = '1' then
					if keyboard_data(7) = '0' then
						if slv(char_buf_wr_addr) /= C_max_char then
							hk_next_state <= HANDLE_CHARACTER_S0;
						else
							hk_next_state <= IDLE;
						end if;
					else
						hk_next_state <= HANDLE_COMMAND;
					end if;
            end if;
         when HANDLE_CHARACTER_S0 =>
            hk_next_state <= HANDLE_CHARACTER_S1;
			when HANDLE_CHARACTER_S1 =>
            hk_next_state <= IDLE;
         when HANDLE_COMMAND =>
				if keyboard_data_buf = C_backspace_cmnd then
					if slv(char_buf_wr_addr) /= X"00" then
						hk_next_state <= HANDLE_BACKSPACE_S0;
					else
						hk_next_state <= IDLE;
					end if;
				elsif keyboard_data_buf = C_enter_cmnd then
					hk_next_state <= HANDLE_ENTER_S0;
				else
					hk_next_state <= IDLE;
				end if;
			when HANDLE_BACKSPACE_S0 =>
				hk_next_state <= HANDLE_BACKSPACE_S1;
			when HANDLE_BACKSPACE_S1 =>
				hk_next_state <= IDLE;
			when HANDLE_ENTER_S0 =>
				hk_next_state <= HANDLE_ENTER_S1;
			when HANDLE_ENTER_S1 =>
				hk_next_state <= IDLE;
         when others =>
            hk_next_state <= IDLE;
      end case;      
   end process;


	DEBUG_OUT <= slv(char_buf_x_coord);
	DEBUG_OUT2 <= slv(debug2);
	
	---- HANDLE CURSOR POSITION ----	

	CURSORPOS_X_OUT <= slv(ocrx);
	CURSORPOS_Y_OUT <= slv(ocry);
	
	process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
			if hk_state = HANDLE_CHARACTER_S1 then
				if slv(ocrx) = C_page_width and slv(ocry) /= C_page_height then
					ocrx <= X"00";
				else
					ocrx <= ocrx + 1;
				end if;
				if slv(ocrx) = C_page_width then
					if slv(ocry) /= C_page_height then
						ocry <= ocry + 1;
					end if;
				end if;
			elsif hk_state = HANDLE_BACKSPACE_S1 then
				if slv(ocrx) = X"00" and slv(ocry) /= X"00" then
					ocrx <= unsigned(C_page_width);
				else
					ocrx <= ocrx - 1;
				end if;
				if slv(ocrx) = X"00" then
					if ocry /= X"00" then
						ocry <= ocry - 1;
					end if;
				end if;
			elsif hk_state = HANDLE_ENTER_S0 and slv(ocry) /= C_page_height then
				ocrx <= X"00";
				ocry <= ocry + 1;
			end if;
		end if;
	end process;

	---- SCREEN MEMORY ----

	char_buf : TDP_RAM
	Generic Map ( G_DATA_A_SIZE 	=> TEXT_DATA_OUT'length,
					  G_ADDR_A_SIZE	=> TEXT_ADDR_IN'length,
					  G_RELATION		=> 0, --log2(SIZE_A/SIZE_B)
					  G_INIT_FILE		=> "./coe_dir/ascii_space.coe")
   Port Map ( CLK_A_IN 		=> CLK_IN,
				  WE_A_IN 		=> '0',
				  ADDR_A_IN 	=> TEXT_ADDR_IN,
				  DATA_A_IN		=> X"00",
				  DATA_A_OUT	=> TEXT_DATA_OUT,
				  CLK_B_IN 		=> CLK_IN,
				  WE_B_IN 		=> char_buf_wr,
				  ADDR_B_IN 	=> slv(char_buf_wr_addr),
				  DATA_B_IN 	=> char_buf_wr_data,
				  DATA_B_OUT 	=> open);

	Font_Mem_inst : FONT_MEM
	  PORT MAP (
		 clka 	=> CLK_IN,
		 wea 		=> "0",
		 addra 	=> FONT_ADDR_IN,
		 dina 	=> (others => '0'),
		 douta 	=> FONT_DATA_OUT);

end Behavioral;

