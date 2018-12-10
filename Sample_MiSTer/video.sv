//--------------------------------------------------------------------------


//--------------------------------------------------------------------------
//
// --------------------------------------------------------------------
// File <video.sv> is based upon file <vga_generator.v> from "HDMI_TX"
// DE10 nano example code
// Copyright (c) 2007 by Terasic Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Terasic Technologies Inc
//                     356 Fu-Shin E. Rd Sec. 1. JhuBei City,
//                     HsinChu County, Taiwan
//                     302
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// --------------------------------------------------------------------

// define to use MiSTer video mixer
`define VIDEO_MIXER
`ifdef VIDEO_MIXER
reg  HBlank, VBlank, HSync, VSync;
`endif

module video
(                                    
  input						clk,                
  input						reset_n,
  
  input 			[3:0]		VGA_R4,
  input			[3:0]		VGA_G4,
  input			[3:0]		VGA_B4,
  
  output reg            CE_PIXEL, 
  output	reg				VGA_HS,             
  output	reg				VGA_VS,           
  output	reg				VGA_DE,
  output	reg	[7:0]		VGA_R,
  output	reg	[7:0]		VGA_G,
  output	reg	[7:0]		VGA_B                                                 
);

//=======================================================
//   Mode selection
//=======================================================
wire [11:0] h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp; 

//-- video mode (256x256)
//--
//-- Horizontal : 
//-- Total time for each line       31.778	µs = 320
//-- Front porch               (A)   0.636	µs =   8
//-- Sync pulse length         (B)   3.813	µs =  40
//-- Back porch                (C)   1.907	µs =  16
//-- Active video              (D)	 25.422	µs = 256
//
//-- Vertical :
//-- Total time for each frame      16.683	ms = 288
//-- Front porch               (A)   0.318	ms =   8
//-- Sync pulse length         (B)   0.064	ms =   8 
//-- Back porch                (C)   1.048	ms =  16
//-- Active video              (D)  15.253	ms = 256

assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {12'd256,	12'd8, 12'd40, 12'd16, 12'd256, 12'd8, 12'd8, 12'd16}; 
	
 //=====Mode:640x350		70		25.175	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	16,	96,	48,	350,	37,	2,	60};	 	 
 //=====Mode:640x350		85		31.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	32,	64,  	96,	350,	32,	3,	60};  	 
 //=====Mode:640x400		70		25.175	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	16,	96,  	48,	400,	12,	2,	35}; 	 	 
 //=====Mode:640x400		85		31.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	32,	64,	96,	400,	1,		3,	41}; 	 	 
 //=====Mode:640x480		60		25.175	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {12'd640,	12'd16,	12'd96,	12'd48,	12'd480,	12'd10,	12'd2,	12'd33}; 	 	 
 //=====Mode:640x480		73		31.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	24,	40,	128,	480,	9,		2,	29}; 	 	 
 //=====Mode:640x480		75		31.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	16,	64,	120,	480,	1,		3,	16}; 	 	 
 //=====Mode:640x480		85		36			assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	56,	56,	80,	480,	1,		3,	25};  	 
 //=====Mode:640x480		100	43.16		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {640,	40,	64,	104,	480,	1,		3,	25}; 	 	 
 //=====Mode:720x400		85		35.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {720,	36,	72,	108,	400,	1,		3,	42}; 	 	 
 //=====Mode:768x576		60		34.96		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {768,	24,	80,	104,	576,	1,		3,	17}; 	 	 
 //=====Mode:768x576		72		42.93		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {768,	32,	80,	112,	576,	1,		3,	21}; 	 	 
 //=====Mode:768x576		75		45.51		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {768,	40,	80,	120,	576,	1,		3,	22}; 	 	 
 //=====Mode:768x576		85		51.84		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {768,	40,	80,	120,	576,	1,		3,	25}; 	 	 
 //=====Mode:768x576		100	62.57		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {768,	48,	80,	128,	576,	1,		3,	31}; 	 	 
 //=====Mode:800x600		56		36			assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {800,	24,	72,	128,	600,	1,		2,	22}; 	 	 
 //=====Mode:800x600		60		40			assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {800,	40,	128,	88,	600,	1,		4,	23}; 	 	 
 //=====Mode:800x600		75		49.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {800,	16,	80,	160,	600,	1,		3,	21}; 	 	 
 //=====Mode:800x600		72		50			assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {800,	56,	120,	64,	600,	37,	6,	23}; 	 	 
 //=====Mode:800x600		85		56.25		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {800,	32,	64,	152,	600,	1,		3,	27}; 	 	 
 //=====Mode:800x600		100	68.18		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {800,	48,	88,	136,	600,	1,		3,	32}; 	 	 
 //=====Mode:1024x768	43		44.9		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1024,	8,		176,	56,	768,	0,		8,	41}; 	 	 
 //=====Mode:1024x768	60		65			assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1024,	24,	136,	160,	768,	3,		6,	29}; 	 	 
 //=====Mode:1024x768	70		75			assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1024,	24,	136,	144,	768,	3,		6,	29};  	 
 //=====Mode:1024x768	75		78.8		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1024,	16,	96,	176,	768,	1,		3,	28}; 	 	 
 //=====Mode:1024x768	85		94.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1024,	48,	96,	208,	768,	1,		3,	36}; 	 	 
 //=====Mode:1024x768	100	113.31	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1024,	72,	112,	184,	768,	1,		3,	42}; 	 	 
 //=====Mode:1152x864	75		108		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1152,	64,	128,	256,	864,	1,		3,	32}; 	 	 
 //=====Mode:1152x864	85		119.65	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1152,	72,	128,	200,	864,	1,		3,	39}; 	 	 
 //=====Mode:1152x864	100	143.47	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1152,	80,	128,	208,	864,	1,		3,	47}; 	 	 
 //=====Mode:1152x864	60		81.62		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1152,	64,	120,	184,	864,	1,		3,	27};	 	 
 //=====Mode:1280x1024	60		108		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	48,	112,	248,	1024,	1,		3,	38}; 	 	 
 //=====Mode:1280x1024	75		135		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	16,	144,	248,	1024,	1,		3,	38}; 	 	 
 //=====Mode:1280x1024	85		157.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	64,	160,	224,	1024,	1,		3,	44}; 	 	 
 //=====Mode:1280x1024	100	190.96	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	96,	144,	240,	1024,	1,		3,	57}; 	 	 
 //=====Mode:1280x800	60		83.46		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	64,	136,	200,	800,	1,		3,	24}; 	 	 
 //=====Mode:1280x960	60		102.1	 	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {12'd1280,	12'd80,	12'd136,	12'd216,	12'd960,	12'd1, 12'd3,	12'd30}; 	 	 
 //=====Mode:1280x960	72		124.54	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	88,	136,	224,	960,	1,		3,	37}; 	 	 
 //=====Mode:1280x960	75		129.86	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	88,	136,	224,	960,	1,		3,	38}; 	 	 
 //=====Mode:1280x960	85		148.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	64,	160,	224,	960,	1,		3,	47}; 	 	 
 //=====Mode:1280x960	100	178.99	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1280,	96,	144,	240,	960,	1,		3,	53}; 	 	 
 //=====Mode:1368x768	60		85.86		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1368,	72,	144,	216,	768,	1,		3,	23}; 	 	 
 //=====Mode:1400x1050	60		122.61	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1400,	88,	152,	240,	1050,	1,		3,	33}; 	 	 
 //=====Mode:1400x1050	72		149.34	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1400,	96,	152,	248,	1050,	1,		3,	40}; 	 	 
 //=====Mode:1400x1050	75		155.85	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1400,	96,	152,	248,	1050,	1,		3,	42}; 	 	 
 //=====Mode:1400x1050	85		179.26	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1400,	104,	152,	256,	1050,	1,		3,	49}; 	 	 
 //=====Mode:1400x1050	100	214.39	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1400,	112,	152,	264,	1050,	1,		3,	58}; 	 	 
 //=====Mode:1440x900	60		106.47	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1440,	80,	152,	232,	900,	1,		3,	28}; 	 	 
 //=====Mode:1600x1200	60		162		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1600,	64,	192,	304,	1200,	1,		3,	46}; 	 	 
 //=====Mode:1600x1200	65		175.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1600,	64,	192,	304,	1200,	1,		3,	46}; 	 	 
 //=====Mode:1600x1200	70		189		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1600,	64,	192,	304,	1200,	1,		3,	46}; 	 	 
 //=====Mode:1600x1200	75		202.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1600,	64,	192,	304,	1200,	1,		3,	46}; 	 	 
 //=====Mode:1600x1200	85		229.5		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1600,	64,	192,	304,	1200,	1,		3,	46}; 	 	 
 //=====Mode:1600x1200	100	280.64	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1600,	128,	176,	304,	1200,	1,		3,	67}; 	 	 
 //=====Mode:1680x1050	60		147.14	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1680,	104,	184,	288,	1050,	1,		3,	33}; 	 	 
 //=====Mode:1792x1344	60		204.8		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1792,	128,	200,	328,	1344,	1,		3,	46}; 	 	 
 //=====Mode:1792x1344	75		261		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1792,	96,	216,	352,	1344,	1,		3,	69}; 	 	 
 //=====Mode:1856x1392	60		218.3		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1856,	96,	224,	352,	1392,	1,		3,	43}; 	 	 
 //=====Mode:1856x1392	75		288		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1856,	128,	224,	352,	1392,	1,		3,	104}; 	 	 
 //=====Mode:1920x1200	60		193.16	assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1920,	128,	208,	336,	1200,	1,		3,	38}; 	 	 
 //=====Mode:1920x1440	60		234		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1920,	128,	208,	344,	1440,	1,		3,	56}; 	 	 
 //=====Mode:1920x1440	75		297		assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {1920,	144,	224,	352,	1440,	1,		3,	56}; 	 	

//=======================================================
//   Assign timing constant  
//
//   h_total : total - 1
//   h_sync : sync - 1
//   h_start : sync + back porch - 1 - 2(delay)
//   h_end : h_start + active
//   v_total : total - 1
//   v_sync : sync - 1
//   v_start : sync + back porch - 1
//   v_end : v_start + active
//   v_active_14 : v_start + 1/4 active
//   v_active_24 : v_start + 2/4 active
//   v_active_34 : v_start + 3/4 active
//=======================================================
wire [11:0] h_total, h_sync, h_start, h_end; 
wire [11:0] v_total, v_sync, v_start, v_end; 
wire [11:0] v_active_14, v_active_24, v_active_34, v_active4;
assign h_total = h_display + h_fp + h_pulse + h_bp - 1;
assign h_sync = h_pulse - 1;
assign h_start = h_pulse + h_bp - 1 - 2;
assign h_end = h_display + h_pulse + h_bp - 1 - 2; 
assign v_total = v_display + v_fp + v_pulse + v_bp - 1;
assign v_sync = v_pulse - 1;
assign v_start = v_pulse + v_bp - 1;
assign v_end = v_display + v_pulse + v_bp - 1;
assign v_active_14 = v_pulse + v_bp - 1 + (v_display >> 2);
assign v_active_24 = v_pulse + v_bp - 1 + (v_display >> 1);
assign v_active_34 = v_pulse + v_bp - 1 + (v_display >> 2) + (v_display >> 1);

//=======================================================
//  Signal declarations
//=======================================================
reg	[11:0]	h_count;
reg	[7:0]		pixel_x;
reg	[11:0]	v_count;
wire  [11:0]   X, Y;
reg				h_act; 
reg				h_act_d;
reg				v_act; 
reg				v_act_d; 
reg				pre_vga_de;
wire				h_max, hs_end, hr_start, hr_end;
wire				v_max, vs_end, vr_start, vr_end;
wire				v_act_14, v_act_24, v_act_34;
reg				boarder;
reg	[3:0]		color_mode;
assign X = h_end - h_count;
assign Y = v_count - v_start;

//=======================================================
//  Structural coding
//=======================================================
assign h_max = h_count == h_total;
assign hs_end = h_count >= h_sync;
assign hr_start = h_count == h_start; 
assign hr_end = h_count == h_end;
assign v_max = v_count == v_total;
assign vs_end = v_count >= v_sync;
assign vr_start = v_count == v_start; 
assign vr_end = v_count == v_end;
assign v_act_14 = v_count == v_active_14; 
assign v_act_24 = v_count == v_active_24; 
assign v_act_34 = v_count == v_active_34;

//============= horizontal control signals
always @ (posedge clk or negedge reset_n)
	if (!reset_n)
	begin
		h_act_d	<=	1'b0;
		h_count	<=	12'b0;
		pixel_x	<=	8'b0;
`ifdef VIDEO_MIXER
`else
		VGA_HS	<=	1'b1;
`endif
		h_act		<=	1'b0;
	end
	else
	begin
		h_act_d	<=	h_act;

		if (h_max)
			h_count	<=	12'b0;
		else
			h_count	<=	h_count + 12'b1;

		if (h_act_d)
			pixel_x	<=	pixel_x + 8'b1;
		else
			pixel_x	<=	8'b0;

`ifdef VIDEO_MIXER
		if (hs_end && !h_max)
			HSync <=	1'b1;
		else
			HSync	<=	1'b0;
`else
		if (hs_end && !h_max)
			VGA_HS	<=	1'b1;
		else
			VGA_HS	<=	1'b0;
`endif

		if (hr_start)
			h_act		<=	1'b1;
		else if (hr_end)
			h_act		<=	1'b0;
	end

//============= vertical control signals
always@(posedge clk or negedge reset_n)
	if(!reset_n)
	begin
		v_act_d		<=	1'b0;
		v_count		<=	12'b0;
`ifdef VIDEO_MIXER
`else
		VGA_VS		<=	1'b1;
`endif
		v_act			<=	1'b0;
		color_mode	<=	4'b0;
	end
	else 
	begin		
		if (h_max)
		begin		  
			v_act_d	  <=	v_act;
		  
			if (v_max)
				v_count	<=	12'b0;
			else
				v_count	<=	v_count + 12'b000000000001;

`ifdef VIDEO_MIXER
			if (vs_end && !v_max)
				VSync	<=	1'b1;
			else
				VSync	<=	1'b0;
`else
			if (vs_end && !v_max)
				VGA_VS	<=	1'b1;
			else
				VGA_VS	<=	1'b0;
`endif

			if (vr_start)
				v_act <=	1'b1;
			else if (vr_end)
				v_act <=	1'b0;

			if (vr_start)
				color_mode[0] <=	1'b1;
			else if (v_act_14)
				color_mode[0] <=	1'b0;

			if (v_act_14)
				color_mode[1] <=	1'b1;
			else if (v_act_24)
				color_mode[1] <=	1'b0;
		    
			if (v_act_24)
				color_mode[2] <=	1'b1;
			else if (v_act_34)
				color_mode[2] <=	1'b0;
		    
			if (v_act_34)
				color_mode[3] <=	1'b1;
			else if (vr_end)
				color_mode[3] <=	1'b0;
		end
	end


//============= pixel mux
always @(posedge clk or negedge reset_n)
begin
	if (!reset_n)
	begin
`ifdef VIDEO_MIXER
`else
		VGA_DE		<=	1'b0;
		pre_vga_de	<=	1'b0;
		boarder		<=	1'b0;		
`endif	
	end
	else
	begin		
`ifdef VIDEO_MIXER
`else
		VGA_DE		<=	pre_vga_de;
		pre_vga_de	<=	v_act && h_act;
		
		if ((!h_act_d&&h_act) || hr_end || (!v_act_d&&v_act) || vr_end)
			boarder	<=	1'b1;
		else
			boarder	<=	1'b0;  

		if (boarder)
			{VGA_R, VGA_G, VGA_B} <= {8'hFF,8'hFF,8'hFF};
		else
		begin
			VGA_R <= {VGA_R4, VGA_R4};
			VGA_G <= {VGA_G4, VGA_G4};
			VGA_B <= {VGA_B4, VGA_B4};
		end			
`endif
	end
end

`ifdef VIDEO_MIXER
assign HBlank = !h_act;
assign VBland = !v_act;
video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0)) video_mixer
(
	.*,
	.clk_sys(clk),
	.ce_pix(1),
	.ce_pix_out(CE_PIXEL),

	.scanlines(2'h00),
	.hq2x(0),
	.scandoubler(0),
	.mono(0),

	.R({VGA_R4, VGA_R4}),
	.G({VGA_G4, VGA_G4}),
	.B({VGA_B4, VGA_B4})
);
`endif

endmodule