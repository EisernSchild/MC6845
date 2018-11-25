----------------------------------------------------------------------------

----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.ALL;

entity emu is port
(
	-- Master input clock
	CLK_50M          : in    std_logic;

	-- Async reset from top-level module.
	-- Can be used as initial reset.
	RESET            : in    std_logic;

	-- Must be passed to hps_io module
	HPS_BUS          : inout std_logic_vector(44 downto 0);

	-- Base video clock. Usually equals to CLK_SYS.
	CLK_VIDEO        : out   std_logic;

	-- Multiple resolutions are supported using different CE_PIXEL rates.
	-- Must be based on CLK_VIDEO
	CE_PIXEL         : out   std_logic;

	-- Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	VIDEO_ARX        : out   std_logic_vector(7 downto 0);
	VIDEO_ARY        : out   std_logic_vector(7 downto 0);

	-- VGA
	VGA_R            : out   std_logic_vector(7 downto 0);
	VGA_G            : out   std_logic_vector(7 downto 0);
	VGA_B            : out   std_logic_vector(7 downto 0);
	VGA_HS           : out   std_logic; -- positive pulse!
	VGA_VS           : out   std_logic; -- positive pulse!
	VGA_DE           : out   std_logic; -- = not (VBlank or HBlank)

	-- LED
	LED_USER         : out   std_logic; -- 1 - ON, 0 - OFF.

	-- b[1]: 0 - LED status is system status ORed with b[0]
	--       1 - LED status is controled solely by b[0]
	-- hint: supply 2'b00 to let the system control the LED.
	LED_POWER        : out   std_logic_vector(1 downto 0);
	LED_DISK         : out   std_logic_vector(1 downto 0);

	-- AUDIO
	AUDIO_L          : out   std_logic_vector(15 downto 0);
	AUDIO_R          : out   std_logic_vector(15 downto 0);
	AUDIO_S          : out   std_logic;                    -- 1 - signed audio samples, 0 - unsigned
	AUDIO_MIX        : out   std_logic_vector(1 downto 0); -- 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	TAPE_IN          : in    std_logic;

	-- SD-SPI
	SD_SCK           : out   std_logic := 'Z';
	SD_MOSI          : out   std_logic := 'Z';
	SD_MISO          : in    std_logic;
	SD_CS            : out   std_logic := 'Z';
	SD_CD            : in    std_logic;

	-- High latency DDR3 RAM interface
	-- Use for non-critical time purposes
	DDRAM_CLK        : out   std_logic;
	DDRAM_BUSY       : in    std_logic;
	DDRAM_BURSTCNT   : out   std_logic_vector(7 downto 0);
	DDRAM_ADDR       : out   std_logic_vector(28 downto 0);
	DDRAM_DOUT       : in    std_logic_vector(63 downto 0);
	DDRAM_DOUT_READY : in    std_logic;
	DDRAM_RD         : out   std_logic;
	DDRAM_DIN        : out   std_logic_vector(63 downto 0);
	DDRAM_BE         : out   std_logic_vector(7 downto 0);
	DDRAM_WE         : out   std_logic;

	-- SDRAM interface with lower latency
	SDRAM_CLK        : out   std_logic;
	SDRAM_CKE        : out   std_logic;
	SDRAM_A          : out   std_logic_vector(12 downto 0);
	SDRAM_BA         : out   std_logic_vector(1 downto 0);
	SDRAM_DQ         : inout std_logic_vector(15 downto 0);
	SDRAM_DQML       : out   std_logic;
	SDRAM_DQMH       : out   std_logic;
	SDRAM_nCS        : out   std_logic;
	SDRAM_nCAS       : out   std_logic;
	SDRAM_nRAS       : out   std_logic;
	SDRAM_nWE        : out   std_logic
);
end emu;

architecture basic of emu is
-- menu constant strings
	constant CONF_STR : string :=
		"XXX;;" &
		"-;" &
		"FS,ROM;" &
		"-;";
	
	constant CONF_STR2 : string :=
		"AB,Save Slot,1,2,3,4;";

	constant CONF_STR3 : string :=
		"6,Load state;";

	constant CONF_STR4 : string :=
		"7,Save state;" &
		"V,v0.01.";
		
-- "sys/pll.v" module definition in VHDL
	component pll is
	port (
		refclk   : in  std_logic; -- clk
		rst      : in  std_logic; -- reset
		outclk_0 : out std_logic; -- clk
		outclk_1 : out std_logic; -- clk
		outclk_2 : out std_logic; -- clk
		locked   : out std_logic  -- export
	);
	end component pll;
		
-- "sys/hps_io.v" module definition in VHDL		
	component hps_io generic
	(
		STRLEN : integer := 0;
		PS2DIV : integer := 1000;
		WIDE   : integer := 0;
		VDNUM  : integer := 1;
		PS2WE  : integer := 0
	);
	port
	(
		CLK_SYS           : in  std_logic;
		HPS_BUS           : inout std_logic_vector(44 downto 0);

		conf_str          : in  std_logic_vector(8*STRLEN-1 downto 0);

		buttons           : out std_logic_vector(1 downto 0);
		forced_scandoubler: out std_logic;

		joystick_0        : out std_logic_vector(15 downto 0);
		joystick_1        : out std_logic_vector(15 downto 0);
		joystick_analog_0 : out std_logic_vector(15 downto 0);
		joystick_analog_1 : out std_logic_vector(15 downto 0);
		status            : out std_logic_vector(31 downto 0);

		sd_lba            : in  std_logic_vector(31 downto 0);
		sd_rd             : in  std_logic;
		sd_wr             : in  std_logic;
		sd_ack            : out std_logic;
		sd_conf           : in  std_logic;
		sd_ack_conf       : out std_logic;

		sd_buff_addr      : out std_logic_vector(8 downto 0);
		sd_buff_dout      : out std_logic_vector(7 downto 0);
		sd_buff_din       : in  std_logic_vector(7 downto 0);
		sd_buff_wr        : out std_logic;

		img_mounted       : out std_logic;
		img_size          : out std_logic_vector(63 downto 0);
		img_readonly      : out std_logic;

		ioctl_download    : out std_logic;
		ioctl_index       : out std_logic_vector(7 downto 0);
		ioctl_wr          : out std_logic;
		ioctl_addr        : out std_logic_vector(24 downto 0);
		ioctl_dout        : out std_logic_vector(7 downto 0);
		ioctl_wait        : in  std_logic;
		
		RTC               : out std_logic_vector(64 downto 0);
		TIMESTAMP         : out std_logic_vector(32 downto 0);

		ps2_kbd_clk_out   : out std_logic;
		ps2_kbd_data_out  : out std_logic;
		ps2_kbd_clk_in    : in  std_logic;
		ps2_kbd_data_in   : in  std_logic;

		ps2_kbd_led_use   : in  std_logic_vector(2 downto 0);
		ps2_kbd_led_status: in  std_logic_vector(2 downto 0);

		ps2_mouse_clk_out : out std_logic;
		ps2_mouse_data_out: out std_logic;
		ps2_mouse_clk_in  : in  std_logic;
		ps2_mouse_data_in : in  std_logic;

		ps2_key           : out std_logic_vector(10 downto 0);
		ps2_mouse         : out std_logic_vector(24 downto 0)
	);
	end component hps_io;
	
-- module "video.sv" definition in VHDL
	component video is port
	(                                    
		clk : in std_logic;                
		reset_n : in std_logic;
		
		VGA_R4 : in std_logic_vector(3 downto 0);
		VGA_G4 : in std_logic_vector(3 downto 0);
		VGA_B4 : in std_logic_vector(3 downto 0);  
		
		VGA_HS : out std_logic;
		VGA_VS : out std_logic;
		VGA_DE : out std_logic;
		VGA_R : out std_logic_vector(7 downto 0);
		VGA_G : out std_logic_vector(7 downto 0);
		VGA_B : out std_logic_vector(7 downto 0)                                               
	);
	end component video;
	
-- User io helper : convert string to std_logic_vector to be given to user_io
	function to_slv(s: string) return std_logic_vector is 
	  constant ss: string(1 to s'length) := s; 
	  variable rval: std_logic_vector(1 to 8 * s'length); 
	  variable p: integer; 
	  variable c: integer; 
	begin
	  for i in ss'range loop
		 p := 8 * i;
		 c := character'pos(ss(i));
		 rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
	  end loop; 
	  return rval; 
	end function; 
	
-- data fields
	signal status : std_logic_vector(31 downto 0);
	signal clock_locked : std_logic;
	signal Clk_85M, Clk_21M : std_logic;
	-- video
	signal V_HS, V_VS, V_DE: std_logic;
	signal linecount : std_logic_vector(11 downto 0);
	
begin
	
-- assigning audio
	AUDIO_S   <= '0';
	AUDIO_L   <= (others => '0');
	AUDIO_R   <= (others => '0');
	AUDIO_MIX <= "00";
	
-- assigning LEDs
	LED_USER  <= '0';
	LED_DISK  <= "00";
	LED_POWER <= "00";
	
-- assigning video streching, pixel enabled and clock
	VIDEO_ARX <= x"10";
	VIDEO_ARY <= x"09";
	CLK_VIDEO <= Clk_85M;
	CE_PIXEL <= '1';
	VGA_HS <= not V_HS;
	VGA_VS <= not V_VS;
	VGA_DE <= V_DE;
	
-- assigning DDRAM (zero)
	DDRAM_CLK      <= '0';
	DDRAM_BURSTCNT <= (others => '0');
	DDRAM_ADDR     <= (others => '0');
	DDRAM_DIN      <= (others => '0');
	DDRAM_BE       <= (others => '0');
	DDRAM_RD       <= '0';
	DDRAM_WE       <= '0';
		
-- assigning SD card SPI mode (z-high impedance)
	SD_SCK         <= 'Z';
	SD_MOSI        <= 'Z';
	SD_CS          <= 'Z';
	
-- sys/hps_io implementation (User io)
	hps : hps_io
	generic map (STRLEN => (CONF_STR'length) + (CONF_STR2'length) + (CONF_STR3'length) + (CONF_STR4'length))
	port map (
		clk_sys => Clk_21M,
		HPS_BUS => HPS_BUS,
		conf_str => to_slv(CONF_STR & CONF_STR2 & CONF_STR3 & CONF_STR4),
		status => status,

		--left blank
		ioctl_wait         => '0',
		sd_lba             => (others => '0'),
		sd_rd              => '0',
		sd_wr              => '0',
		sd_conf            => '0',
		sd_buff_din        => (others => '0'),
		ps2_kbd_led_use    => "000",
		ps2_kbd_led_status => "000",
		ps2_kbd_clk_in     => '0',
		ps2_kbd_data_in    => '0',
		ps2_mouse_clk_in   => '0',
		ps2_mouse_data_in  => '0'
	);

	
-- sys/pll implementation =>phase-locked loop )
	mainpll : pll
	port map(
		refclk   => CLK_50M,
		rst      => '0',
		outclk_0 => Clk_85M,
		outclk_1 => SDRAM_CLK,
		outclk_2 => Clk_21M,
		locked   => clock_locked
	);
	
-- generate line counter
	generate_lc : process(V_DE)
	begin
		if rising_edge(V_DE) then
			linecount <= linecount + 1;
		end if;
	end process generate_lc;
	
-- module file "video.sv" implementation
	video1 : video
	port map
	(                                    
		clk => Clk_85M,                
		reset_n => '1',
		
		VGA_R4 => linecount(3 downto 0),
		VGA_G4 => linecount(7 downto 4),
		VGA_B4 => linecount(11 downto 8),		

		VGA_HS => V_HS,
		VGA_VS => V_VS,
		VGA_DE => V_DE,
		VGA_R => VGA_R,
		VGA_G => VGA_G,
		VGA_B => VGA_B
	);
	
end basic;