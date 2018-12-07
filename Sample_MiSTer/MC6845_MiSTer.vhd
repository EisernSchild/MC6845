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
	
-- entity "crtc6845.vhd" definition
	component crtc6845 is port 
	(
		MA     : out STD_LOGIC_VECTOR (13 downto 0);
		RA     : out STD_LOGIC_VECTOR (4 downto 0);
		HSYNC  : out STD_LOGIC;
		VSYNC  : out STD_LOGIC;
		DE     : out STD_LOGIC;
		CURSOR : out STD_LOGIC;
		LPSTBn : in STD_LOGIC;
		E      : in STD_LOGIC;
		RS     : in STD_LOGIC;
		CSn    : in STD_LOGIC;
		RW     : in STD_LOGIC;
		D      : inout STD_LOGIC_VECTOR (7 downto 0);
		RESETn : in STD_LOGIC;
		CLK    : in STD_LOGIC;
		-- not standard
		REG_INIT: in STD_LOGIC;
		--
		Hend: inout STD_LOGIC;
		HS: inout STD_LOGIC;
		CHROW_CLK: inout STD_LOGIC;
		Vend: inout STD_LOGIC;
		SLadj: inout STD_LOGIC;
		H: inout STD_LOGIC;
		V: inout STD_LOGIC;
		CURSOR_ACTIVE: inout STD_LOGIC;
		VERT_RST: inout STD_LOGIC
	 );
	end component crtc6845;
		
-- module "UM6845R.v" definition in VHDL
	component UM6845R is port
	(
		CLOCK : in std_logic;    
		CLKEN : in std_logic;    
		nRESET : in std_logic;    
		CRTC_TYPE : in std_logic;    

		ENABLE : in std_logic;    
		nCS : in std_logic;    
		R_nW : in std_logic;    
		RS : in std_logic;    
		DI : in std_logic_vector(7 downto 0);  
		DO : out std_logic_vector(7 downto 0);
		
		VSYNC : out std_logic;
		HSYNC : out std_logic;
		DE : out std_logic;
		FIELD : out std_logic;

		MA : out std_logic_vector(13 downto 0);
		RA : out std_logic_vector(4 downto 0)
	);
	end component UM6845R;

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
	signal Clk_VGA, Clk_temp : std_logic;
	-- video
	signal V_HS, V_VS, V_DE: std_logic;
	signal linecount : std_logic_vector(11 downto 0);
	
-- "UM6845R.v" assigned fields
	signal CLOCK : std_logic;    
	signal CLKEN : std_logic;    
	signal nRESET : std_logic;    
	signal CRTC_TYPE : std_logic;    
	
	signal ENABLE : std_logic;    
	signal nCS : std_logic;    
	signal R_nW : std_logic;    
	signal DI : std_logic_vector(7 downto 0);  
	signal DO : std_logic_vector(7 downto 0);
	
	signal VSYNC : std_logic;
	signal HSYNC : std_logic;
	signal DE : std_logic;
	signal FIELD : std_logic;
	
	signal MA : std_logic_vector(13 downto 0);
	signal RA : std_logic_vector(4 downto 0);
		
	signal CURSOR :  STD_LOGIC;
	signal LPSTBn :  STD_LOGIC;
	signal E      :  STD_LOGIC;
	signal RS     :  STD_LOGIC;
	signal CSn    :  STD_LOGIC;
	signal RW     :  STD_LOGIC;
	signal D      :  STD_LOGIC_VECTOR(7 downto 0);
	signal RESETn :  STD_LOGIC;
	
	-- not standard
	signal REG_INIT: STD_LOGIC;
	--
	signal Hend: STD_LOGIC;
	signal HS: STD_LOGIC;
	signal CHROW_CLK: STD_LOGIC;
	signal Vend: STD_LOGIC;
	signal SLadj: STD_LOGIC;
	signal H: STD_LOGIC;
	signal V: STD_LOGIC;
	signal CURSOR_ACTIVE: STD_LOGIC;
	signal VERT_RST: STD_LOGIC;

	-- test
	signal ROW_IND : std_logic;
	signal HCC : std_logic_vector(7 downto 0);
	
	shared variable init_counter: integer := 0;

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
	CLK_VIDEO <= Clk_VGA;
	CE_PIXEL <= '1';
	VGA_HS <= not V_HS;
	VGA_VS <= not V_VS;
	VGA_DE <= V_DE;
--	VGA_HS <= not HSYNC;
--	VGA_VS <= not VSYNC;
--	VGA_DE <= not DE;
	
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
		clk_sys => Clk_temp,
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
		outclk_0 => Clk_VGA,
		outclk_1 => SDRAM_CLK,
		outclk_2 => Clk_temp,
		locked   => clock_locked
	);
	
-- generate line counter
	generate_lc : process(HSYNC)
	begin
		if rising_edge(HSYNC) then
			linecount <= linecount + 1;
		end if;
		if (DE = '0') then
			linecount <= (others => '0');
		end if;		 
	end process generate_lc;
	
-- module file "video.sv" implementation
	video1 : video
	port map
	(                                    
		clk => Clk_VGA,                
		reset_n => '1',
		
		VGA_R4 => RA(3 downto 0), -- HCC(7 downto 4), -- ROW_IND & "000", -- linecount(3 downto 0),
		VGA_G4 => H & "000", -- linecount(7 downto 4),
		VGA_B4 => linecount(3 downto 0),		

		VGA_HS => V_HS,
		VGA_VS => V_VS,
		VGA_DE => V_DE,
		VGA_R => VGA_R,
		VGA_G => VGA_G,
		VGA_B => VGA_B
	);
	
	-- create clock CLKEN
	process (Clk_VGA)
		variable counter : std_logic_vector(2 downto 0) := "000";
		variable E_counter : integer := 0;
	begin
		if rising_edge(Clk_VGA) then
			counter := counter + 1;
			E_counter := E_counter +1;
			if (counter = "100") then CLKEN <= '1'; else CLKEN <= '0'; end if;
			if ((E_counter > 10) and (E_counter < 30)) then E <= '1';
			elsif ((E_counter > 50) and (E_counter < 70)) then E <= '0';
			else E <= '1'; end if;
		end if;		 
	end process;
	
-- module file "UM6845R.v" implementation
--	CRTC_TYPE <= '1';
--	ENABLE <= '1';    
--	
--	UM6845R1 : UM6845R
--	port map
--	(
--		CLOCK => Clk_VGA, -- CLOCK,   
--		CLKEN => CLKEN,    
--		nRESET => '1', -- nRESET,  
--		CRTC_TYPE => CRTC_TYPE,  
--
--		ENABLE => ENABLE, 
--		nCS => nCS ,
--		R_nW => R_nW,
--		RS => RS,
--		DI => DI,
--		DO => DO,
--		
--		VSYNC  => VSYNC,
--		HSYNC  => HSYNC,
--		DE => DE,
--		FIELD => FIELD,
--
--		MA  => MA,
--		RA  => RA
--	);

-- entity "crtc6845.vhd" implementation
	REG_INIT <= '1';

	crtc6845i : crtc6845
	port map 
	(
		MA  => MA,
		RA  => RA,
		HSYNC  => HSYNC,
		VSYNC  => VSYNC,
		DE => DE,
		CURSOR => CURSOR,
		LPSTBn => LPSTBn,
		E => E,
		RS => RS,
		CSn => CSn,
		RW => RW,
		D => D,
		RESETn => '1', -- RESETn,
		CLK => CLKEN,
		-- not standard
		REG_INIT => REG_INIT,
		--
		Hend => Hend,
		HS => HS,
		CHROW_CLK => CHROW_CLK,
		Vend => Vend,
		SLadj => SLadj,
		H => H,
		V => V,
		CURSOR_ACTIVE => CURSOR_ACTIVE,
		VERT_RST => VERT_RST
	);
	
	
-- video mode (256x256)
--
-- Horizontal : 
-- Total time for each line       31.778	µs = 320
-- Front porch               (A)   0.636	µs =   8
-- Sync pulse length         (B)   3.813	µs =  40
-- Back porch                (C)   1.907	µs =  16
-- Active video              (D)	 25.422	µs = 256

-- Vertical :
-- Total time for each frame      16.683	ms = 288
-- Front porch               (A)   0.318	ms =   8
-- Sync pulse length         (B)   0.064	ms =   8
-- Back porch                (C)   1.048	ms =  16
-- Active video              (D)  15.253	ms = 256
	
-- test process
	-- video mode (256x256) : 

	-- R0_h_total      40 28 - 40*8 = 320 pixel
	-- R1_h_displayed  32 20 - 32*8 = 256 pixel
	-- R2_h_sync_pos   33 21 - 33*8 = 264 pixel
	-- R3_v_sync_width 03 03 -  3*8 =  24 pixel
	-- R4_v_total      36 24 - 36*8 = 288 pixel
	-- R5_v_total_adj  00 00 - 0 pixel
	-- R6_v_displayed  32 20 - 32*8 = 256 pixel
	-- R7_v_sync_pos   32 20 - 32*8 = 256 pixel
	-- R9_v_max_line   07 07
	-- All other registers are cleared
	

--		process (CLKEN)
--		begin
--			if rising_edge(CLKEN) then
--				case init_counter is
--						when 0 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"00";
--						when 1 => 	CSn <= '0'; -- reg 0
--											RW <= '0';
--											RS <= '1';
--											D <= x"28";
--						when 2 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"01";
--						when 3 => 	CSn <= '0'; -- reg 1
--											RW <= '0';
--											RS <= '1';
--											D <= x"20";
--						when 4 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"02";
--						when 5 => 	CSn <= '0'; -- reg 2
--											RW <= '0';
--											RS <= '1';
--											D <= x"21";
--						when 6 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"03";
--						when 7 => 	CSn <= '0'; -- reg 3
--											RW <= '0';
--											RS <= '1';
--											D <= x"03";
--						when 8 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"04";
--						when 9 => 	CSn <= '0'; -- reg 4
--											RW <= '0';
--											RS <= '1';
--											D <= x"24";
--						when 10 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"05";
--						when 11 => 	CSn <= '0'; -- reg 5
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 12 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"06";
--						when 13 => 	CSn <= '0'; -- reg 6
--											RW <= '0';
--											RS <= '1';
--											D <= x"20";
--						when 14 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"07";
--						when 15 => 	CSn <= '0'; -- reg 7
--											RW <= '0';
--											RS <= '1';
--											D <= x"20";
--						when 16 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"08";
--						when 17 => 	CSn <= '0'; -- reg 8
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 18 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"09";
--						when 19 => 	CSn <= '0'; -- reg 9
--											RW <= '0';
--											RS <= '1';
--											D <= x"07";
--						when 20 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"0A";
--						when 21 => 	CSn <= '0'; -- reg 10
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 22 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"0B";
--						when 23 => 	CSn <= '0'; -- reg 11
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 24 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"0C";
--						when 25 => 	CSn <= '0'; -- reg 12
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 26 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"0D";
--						when 27 => 	CSn <= '0'; -- reg 13
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 28 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"0E";
--						when 29 => 	CSn <= '0'; -- reg 14
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when 30 => 	CSn <= '0'; 
--											RW <= '0';
--											RS <= '0';
--											D <= x"0F";
--						when 31 => 	CSn <= '0'; -- reg 15
--											RW <= '0';
--											RS <= '1';
--											D <= x"00";
--						when others => 	CSn <= '0'; -- read, no write
--											RW <= '1';
--											RS <= '0';
--											D <= x"00";
--						
--						
--						
--					end case;
--					if (init_counter < 5000) then init_counter := init_counter + 1; end if;
--			end if;		
--		end process;
		
end basic;