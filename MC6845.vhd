------------------------------------------------------------------------------
--
--  MC6845 - Motorola 6845 Cathode Ray Tube Controller (CRTC) VHDL core
--  based on UM6845R for Amstrad CPC
--  Copyright (C) 2018 Sorgelig
-- 
--  File <MC6845.vhd> (c) 2018 by Denis Reischl
--
--  EisernSchild/MC6845 is licensed under the
--  GNU General Public License v3.0
--
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.ALL;

-- The M6845 has 48 external signals; 16 inputs and 32 outputs.
entity MC6845 is
	port(

	-- CPU INTERFACE SIGNALS
		DI     : in std_logic_vector(7 downto 0);  -- Input Data bus input (8-bits)
		R_nW   : in std_logic;                     -- Read not write, data transfer direction (1=read, 0=write)
		nCS    : in std_logic;                     -- Not chip select, enables CPU data transfer, active low
		RS     : in std_logic;                     -- Register select, when low the address register is selected, when high one of the 18 control registers is selected
		ENABLE : in std_logic;                     -- Enable, used as a strobe signal in CPU read or write operations
		DO     : out std_logic_vector(7 downto 0); -- Data bus output (8-bits)
		NVDL   : out std_logic;                    -- Not valid data, can be used, in combination with DI0-7 & DR0-7, to generate a bidirectional data bus, active low

	-- CRT INTERFACE SIGNALS
		CLOCK  : in std_logic;                      -- Clock input, defines character timing
		HSYNC  : out std_logic;                     -- Horizontal synchronization, active high
		VSYNC  : out std_logic;                     -- Vertical synchronization, active high
		DE     : out std_logic;                     -- Enable display (DE) , defines the display period in horizontal and vertical raster scanning, active high
		MA     : out std_logic_vector(13 downto 0); -- Refresh memory address lines (16K max.)
		RA     : out std_logic_vector(4 downto 0);  -- Raster address lines
		ECURS  : out std_logic;                     -- Enable cursor, used to display the cursor, active high
		LPSTB  : in std_logic;                      -- Light pen strobe, on a low to high transition the refresh memory address is stored in the light pen register. Must be high for at least 1 period of CLK

	-- OTHER INTERFACE SIGNALS
		nRESET : in std_logic; -- Reset, when low the M6845 is reset after 3 clocks
		NTST   : in std_logic; -- Used during testing for fault cover improvement

		-- from UM6845R left : 
		--	input            CLKEN,
		--	input            CRTC_TYPE,
		FIELD : out std_logic
		
	);
end MC6845;

architecture CRTC of MC6845 is

	-- 6845 registers
	signal addr             :  std_logic_vector(4 downto 0);  -- Address Register        4:0
	signal R0_h_total       :  std_logic_vector(7 downto 0);  -- Horizontal Total        7:0
	signal R1_h_displayed   :  std_logic_vector(7 downto 0);  -- Horizontal Displayed    7:0
	signal R2_h_sync_pos    :  std_logic_vector(7 downto 0);  -- H. Sync Position        7:0
	signal R3_v_sync_width  :  std_logic_vector(3 downto 0);  -- Sync Width              3:0
	signal R3_h_sync_width  :  std_logic_vector(3 downto 0);  -- Sync Width              3:0
	signal R4_v_total       :  std_logic_vector(6 downto 0);  -- Vertical Total          6:0
	signal R5_v_total_adj   :  std_logic_vector(4 downto 0);  -- V. Total Adjust         4:0
	signal R6_v_displayed   :  std_logic_vector(6 downto 0);  -- Vertical Displayed      6:0
	signal R7_v_sync_pos    :  std_logic_vector(6 downto 0);  -- V. Sync Position        6:0
	variable R8_skew          :  std_logic_vector(1 downto 0);  -- Interlace Mode and Skew 1:0
	signal R8_interlace     :  std_logic_vector(1 downto 0);  -- Interlace Mode and Skew 1:0
	signal R9_v_max_line    :  std_logic_vector(4 downto 0);  -- Max Scan Line Address   4:0
	signal R10_cursor_mode  :  std_logic_vector(1 downto 0);  -- Cursor Mode             1:0
	signal R10_cursor_start :  std_logic_vector(4 downto 0);  -- Cursor Start            4:0
	signal R11_cursor_end   :  std_logic_vector(4 downto 0);  -- Cursor End              4:0
	signal R12_start_addr_h :  std_logic_vector(5 downto 0);  -- Start Address H         7:0 (5:0)
	signal R13_start_addr_l :  std_logic_vector(7 downto 0);  -- Start Address L         7:0
	signal R14_cursor_h     :  std_logic_vector(5 downto 0);  -- Cursor H                7:0 (5:0) 
	signal R15_cursor_l     :  std_logic_vector(7 downto 0);  -- Cursor L                7:0
	signal R16_lightpen_h   :  std_logic_vector(5 downto 0);  -- Light Pen H             7:0 (5:0)
	signal R17_lightpen_l   :  std_logic_vector(7 downto 0);  -- Light Pen L             7:0
	
	-- from UM6845R: 
	signal CRTC_TYPE : std_logic := '0';
	
	signal hde, vde : std_logic; -- horizontal / vertical display enabled
	signal interlace : std_logic_vector(4 downto 0);
	signal in_adj : std_logic;
	signal hcc_last : std_logic;
	signal hcc, hcc_next : std_logic_vector(7 downto 0);
	
	signal line_last, line_new : std_logic;	
	signal line_h, line_max, line_next : std_logic_vector(4 downto 0);

	signal row_last, row_new : std_logic;
	signal row, row_next : std_logic_vector(6 downto 0);
	signal row_addr : std_logic_vector(13 downto 0);
	
	signal frame_adj, frame_new : std_logic;
		
	signal nField : std_logic;
	
	signal CRTC0_reload, CRTC1_reload : std_logic;
	
	signal de_a : std_logic_vector(3 downto 0);
	signal dde : std_logic_vector(1 downto 0);
	
	signal h_sync, v_sync : std_logic;
	
begin

-- assign 
	FIELD <= not nField and interlace(0);

	MA <= row_addr + hcc;
	RA <= line_h when (nField = '0' or interlace(0) = '1') else "00000";
	interlace <= "00001" when not R8_interlace = 0 else (others => '0');
	
	HSYNC <= h_sync;
	VSYNC <= v_sync;

-- assign display enabled
	DE <= de_a(to_integer(unsigned(R8_skew)));-- TODO !! and (not CRTC_TYPE & not CRTC_TYPE));
	de_a <= ("0" & dde(1 downto 0) & "1") when (hde = '1' and vde = '1' and R6_v_displayed > 0) else ("0" & dde(1 downto 0) & "0");
	process (CLOCK) begin if rising_edge(CLOCK) then dde <= dde(0) & de_a(0); end if; end process;
	
	hcc_last  <= '1' when (hcc = R0_h_total) else '0'; -- TODO !!??       && (CRTC_TYPE || R0_h_total); // always false if !R0_h_total on CRTC0 
	hcc_next <= x"00" when (hcc_last = '1') else (hcc + x"1");
	
	line_max <= ((R5_v_total_adj - x"1") and not interlace) when (in_adj = '1') else (R9_v_max_line and not interlace);
	line_last <= '1' when ((line_h = line_max) or line_max = 0) else '0';
	line_next <= "00000" when (line_last = '1') else ((line_h + x"1" + interlace) and interlace);
	line_new <= hcc_last;
	

	row_last <= '1' when ((row = R4_v_total) or R4_v_total = 0) else '0';
	row_next <= "0000000" when (row_last = '1' and not frame_adj = '1') else row + x"1";
	row_new  <= '1' when ((line_new = '1') and (line_last = '1')) else '0';

	frame_adj <= '1' when ((row_last = '1') and not (in_adj = '1') and not R5_v_total_adj = 0) else '0';
	frame_new <= '1' when ((row_new = '1') and (row_last = '1' or in_adj = '1') and not frame_adj = '1') else '0';
	
	CRTC1_reload <= '1' when (CRTC_TYPE = '1' and line_last = '0' and row = 0 and hcc_next = 0) else '0'; -- CRTC1 reloads addr on every line of 1st row
	CRTC0_reload <= '1' when (CRTC_TYPE = '0' and line_new = '1' and R4_v_total = 0 and  R9_v_max_line = 0) else '0';

	
-- data output
	process (ENABLE, RS, nCS, addr, CRTC_TYPE)
	begin
		DO <= x"FF";
		if ((ENABLE = '1') and (nCS = '0')) then
			if (RS = '1') then
				case addr is
					when x"0A" => DO <= ("0" & R10_cursor_mode & R10_cursor_start);
					when x"0B" => DO <= ("000" & R11_cursor_end);
					when x"0C" => if (CRTC_TYPE = '1') then DO <= x"00"; else DO <= ("00" & R12_start_addr_h); end if;
					when x"0D" => if (CRTC_TYPE = '1') then DO <= x"00"; else DO <= R13_start_addr_l; end if;
					when x"0E" => DO <= "00" & R14_cursor_h;
					when x"0F" => DO <= R15_cursor_l;
					when x"1F" => if (CRTC_TYPE = '1') then DO <= x"FF"; else DO <= x"00"; end if;
					when others => DO <= (others => '0');
				end case;
			elsif (CRTC_TYPE = '1') then
				if (vde = '1') then DO <= x"00"; else DO <= x"20"; end if; -- status for CRTC1
			end if;
		end if;
	end process;

-- data input
	process (CLOCK)
	begin
		if ((ENABLE = '1') and (nCS = '0') and (R_nW = '0')) then
			if (RS = '0') then 
				addr <= DI(4 downto 0);
			else
				case addr is
					when x"00" => R0_h_total <= DI;
					when x"01" => R1_h_displayed <= DI;
					when X"02" => R2_h_sync_pos <= DI;
					when x"03" => R3_v_sync_width <= DI(7 downto 4); R3_h_sync_width <= DI(3 downto 0); -- ?? (7 downto 4) empty ??
					when x"04" => R4_v_total <= DI(6 downto 0);
					when x"05" => R5_v_total_adj <= DI(4 downto 0);
					when x"06" => R6_v_displayed <= DI(6 downto 0);
					when x"07" => R7_v_sync_pos <= DI(6 downto 0);
					when x"08" => R8_skew := DI(5 downto 4); R8_interlace <= DI(1 downto 0);
					when x"09" => R9_v_max_line <= DI(4 downto 0);
					when x"0A" => R10_cursor_mode <= DI(6 downto 5); R10_cursor_start <= DI(4 downto 0);
					when x"0B" => R11_cursor_end <= DI(4 downto 0);
					when x"0C" => R12_start_addr_h <= DI(5 downto 0);
					when x"0D" => R13_start_addr_l <= DI(7 downto 0);
					when x"0E" => R14_cursor_h <= DI(5 downto 0);
					when x"0F" => R15_cursor_l <= DI(7 downto 0);
				end case;
			end if;
		end if;
	end process;
	
-- counters
	process (CLOCK)
	begin
		if (not nReset = '1') then
			hcc <= (others => '0');
			line_h <= (others => '0');
			row <= (others => '0');
			in_adj <= '0';
			nField <= '0';
		elsif rising_edge(CLOCK) then
			hcc <= hcc_next;
			if (line_new = '1') then line_h <= line_next; end if;
			if (row_new = '1') then
				if (frame_adj = '1') then 
					in_adj <= '1';
				elsif (frame_new = '1') then
					in_adj <= '0';
					row <= "0000000";
					if (nField = '0' and  R8_interlace(0) = '1') then nField <= '1'; else nField <= '0'; end if;
				else
					row <= row_next;
				end if;				
			end if;
		end if;		
	end process;
	
-- address
	process (CLOCK)
	begin
		if rising_edge(CLOCK) then
			if (hcc_next = R1_h_displayed and line_last = '1') then row_addr <= row_addr + R1_h_displayed; end if;
			if (frame_new = '1' or CRTC0_reload = '1' or CRTC1_reload = '1') then row_addr <= R12_start_addr_h & R13_start_addr_l; end if;
		end if;		
	end process;
	
-- horizontal output
	process (CLOCK)
		variable hsc : std_logic_vector(3 downto 0) := "0000";
	begin
		if (not nReset = '1') then
			hsc := (others => '0');
			hde <= '0';
			h_sync <= '0';
		elsif rising_edge(CLOCK) then
			if (line_new = '1') then hde <= '1'; end if;
			if (hcc_next = R1_h_displayed) then hde <= '0'; end if;
			
			if (hsc > 0) then hsc := hsc - x"1"; 
			elsif (hcc_next = R2_h_sync_pos) then
				if (R3_h_sync_width > 0) then
					h_sync <= '1';
					hsc := R3_h_sync_width - x"1";
				end if; 
			end if;
		end if;		
	end process;
	
-- vertical output
	process (CLOCK)
		variable vsc : std_logic_vector(3 downto 0) := "0000";
		variable old_hs : std_logic := '0';
	begin
		if (not nReset = '1') then
			vsc := (others => '0');
			vde <= '0';
			v_sync <= '0';
		elsif rising_edge(CLOCK) then
			if (row_new = '1') then 
				if (frame_new = '1')           then vde <= '1'; end if;
				if (row_next = R6_v_displayed) then vde <= '0'; end if;
			end if;
			
			-- separate 2 concatenated VSYNCs
			if (h_sync = '1') then old_hs := '1'; else old_hs := '0'; end if;
			if (old_hs = '1' and h_sync = '0' and vsc = 0) then v_sync <= '0'; end if;
			
			if ((nField = '1' and (hcc_next = ("0" & R0_h_total(7 downto 1)))) or (nField = '0' and line_new = '1')) then
				if (vsc > 0) then vsc := vsc - x"1";
				elsif ((nField = '1' and (row = R7_v_sync_pos and line_h > 0)) or (nField = '0' and (row_next = R7_v_sync_pos and line_last = '1'))) then
					v_sync <= '1';
					if (CRTC_TYPE = '1') then vsc := 0 - x"1"; else vsc := R3_v_sync_width - x"1"; end if;
				else
					v_sync <= '0';
				end if; 
			end if;
		end if;		
	end process;

end CRTC;
	