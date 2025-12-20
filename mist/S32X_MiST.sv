//============================================================================
//  S32X top-level for MiST
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module S32X_MiST
(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 0;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

// remove this if the 2nd chip is actually used
//`ifdef DUAL_SDRAM
//assign SDRAM2_A = 13'hZZZZ;
//assign SDRAM2_BA = 0;
//assign SDRAM2_DQML = 1;
//assign SDRAM2_DQMH = 1;
//assign SDRAM2_CKE = 0;
//assign SDRAM2_CLK = 0;
//assign SDRAM2_nCS = 1;
//assign SDRAM2_DQ = 16'hZZZZ;
//assign SDRAM2_nCAS = 1;
//assign SDRAM2_nRAS = 1;
//assign SDRAM2_nWE = 1;
//`endif

`include "build_id.v"

assign LED  = ~(ioctl_download | bk_ena);

//           1111111111222222222233333333334444444444555555555566
// 01234567890123456789012345678901234567890123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
parameter CONF_STR = {
	"S32X;;",
	"F1,32XMD BINGEN;",
	"S0U,SAV,Load;",
	`SEP
	"O67,Region,JP,US,EU;",
	"O9,Auto Region,Header,Disabled;",
	"ORS,Priority,US>EU>JP,EU>US>JP,US>JP>EU,JP>US>EU;",

	"P1,Audio & Video;",
	"P1O23,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"P1OT,Border,No,Yes;",
	"P1OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
	"P1OB,FM Chip,YM2612,YM3438;",
	"P1ON,HiFi PCM,No,Yes;",

	"P2,Input;",
	"P2O4,Swap Joysticks,No,Yes;",
	"P2O5,6 Buttons Mode,No,Yes;",
	"P2OWY,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
	"P2-;",
	"P2OIJ,Mouse,None,Port1,Port2;",
	"P2OK,Mouse Flip Y,No,Yes;",
	//"P2Oef,Gun Control,Disabled,Joy1,Joy2,Mouse;",
	//"P2Og,Gun Fire,Joy,Mouse;",
	//"P2Ohi,Cross,Small,Medium,Big,None;",

	"P3,Miscellaneous;",
	"P3OV,Sprite Limit,Normal,High;",

//	"P4,Debug;",
//	"P4Oa,VDP_MD_EN,On,Off;",
//	"P4Ob,VDP_32X_EN,On,Off;",
	`SEP
	"T1,Write SAV;",
	"T0,Reset;",
	"V,v1.0.",`BUILD_DATE
};

wire  [1:0] st_region = status[7:6];
wire        st_auto_region = ~status[9];

wire  [1:0] scanlines = status[3:2];
wire        st_border = status[29];

wire        joyswap = status[4];
wire  [2:0] st_multitap = status[34:32];

//debug
wire      VDP_MD_EN = 1;//~status[36];
wire      VDP_32X_EN = 1;//~status[37];
reg       VDP_BGA_EN = 1;
reg       VDP_BGB_EN = 1;
reg       VDP_SPR_EN = 1;
reg [1:0] VDP_BG_GRID_EN = '0;
reg       VDP_SPR_GRID_EN = 0;
reg       DBG_PAUSE_EN = 0;
reg       EN_GEN_FM = 1;
reg       EN_GEN_PSG = 1;
reg       EN_32X_PWM = 1;

////////////////////   CLOCKS   ///////////////////

wire pll_locked;
wire clk_ram, clk_sys;

pll pll
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.c0(SDRAM_CLK),
	.c1(clk_ram),
	.c2(clk_sys),
	.locked(pll_locked)
);


wire pll_locked2;
wire clk_ram2;
pll pll2
(
`ifdef USE_CLOCK_50
	.inclk0(CLOCK_50),
`else
	.inclk0(CLOCK_27),
`endif
	.c0(SDRAM2_CLK),
	.c1(clk_ram2),
	.c2(),
	.locked(pll_locked2)
);
assign SDRAM2_CKE = 1;

reg reset;
always @(posedge clk_sys) begin
	reset <= buttons[1] | status[0];
end

//////////////////   MiST I/O   ///////////////////
wire [31:0] joy_0;
wire [31:0] joy_1;
wire [31:0] joy_2;
wire [31:0] joy_3;
wire [31:0] joy_4;

wire [31:0] joystick_analog_0;
wire [31:0] joystick_analog_1;

wire  [1:0] buttons;
wire [63:0] status;
wire [63:0] RTC_time;
wire        ypbpr;
wire        scandoubler_disable;
wire        no_csync;

wire  [8:0] mouse_x;
wire  [8:0] mouse_y;
wire  [7:0] mouse_flags;  // YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
wire        mouse_strobe;

wire        key_strobe;
wire        key_pressed;
wire        key_extended;
wire  [7:0] key_code;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        sd_buff_rd;
wire        img_mounted;
wire [31:0] img_size;

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

wire [24:0] mouse = { mouse_strobe_level, mouse_y[7:0], mouse_x[7:0], mouse_flags };
reg         mouse_strobe_level;
wire [10:0] conf_str_addr;
reg   [7:0] conf_str_char;

always @(posedge clk_sys) begin
	conf_str_char <= CONF_STR[(($size(CONF_STR)>>3) - conf_str_addr - 1)<<3 +:8];
	if (mouse_strobe) mouse_strobe_level <= ~mouse_strobe_level;
end

user_io #(.FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14)), .SD_IMAGES(1)) user_io
(
	.clk_sys(clk_sys),
	.clk_sd(clk_sys),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_CLK(SPI_SCK),
	.SPI_MOSI(SPI_DI),
	.SPI_MISO(SPI_DO),

	.conf_addr(conf_str_addr),
	.conf_chr(conf_str_char),

	.status(status),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.buttons(buttons),
	.rtc(RTC_time),
	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.joystick_2(joy_2),
	.joystick_3(joy_3),
	.joystick_4(joy_4),

	.joystick_analog_0(joystick_analog_0),
	.joystick_analog_1(joystick_analog_1),

	.mouse_x(mouse_x),
	.mouse_y(mouse_y),
	.mouse_flags(mouse_flags),
	.mouse_strobe(mouse_strobe),

	.key_strobe(key_strobe),
	.key_code(key_code),
	.key_pressed(key_pressed),
	.key_extended(key_extended),

`ifdef USE_HDMI
	.i2c_start      (i2c_start      ),
	.i2c_read       (i2c_read       ),
	.i2c_addr       (i2c_addr       ),
	.i2c_subaddr    (i2c_subaddr    ),
	.i2c_dout       (i2c_dout       ),
	.i2c_din        (i2c_din        ),
	.i2c_ack        (i2c_ack        ),
	.i2c_end        (i2c_end        ),
`endif

	.sd_conf(1'b0),
	.sd_sdhc(1'b1),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack_x(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_dout(sd_buff_dout),
	.sd_din(sd_buff_din),
	.sd_dout_strobe(sd_buff_wr),
	.sd_din_strobe(sd_buff_rd),
	.img_mounted(img_mounted),
	.img_size(img_size)
);

wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;

data_io #(.DOUT_16(1'b1), .USE_QSPI(QSPI)) data_io
(
	.clk_sys(clk_sys),
	.SPI_SCK(SPI_SCK),
	.SPI_DI(SPI_DI),
	.SPI_DO(SPI_DO),
	.SPI_SS2(SPI_SS2),
	.SPI_SS4(SPI_SS4),
`ifdef USE_QSPI
	.QSCK(QSCK),
	.QCSn(QCSn),
	.QDAT(QDAT),
`endif
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
);

//////////////////////////  ROM DETECT  /////////////////////////////////
wire rom_download = ioctl_download && ioctl_index[5:1] == 0;
wire [3:0] hrgn = ioctl_dout[3:0] - 4'd7;

reg cart_hdr_ready = 0;
reg hdr_j = 0, hdr_u = 0, hdr_e = 0;
reg  [1:0] region_req;

wire [1:0] region = st_auto_region ? region_req : st_region;
wire       PAL = region[1];

always @(posedge clk_sys) begin
	reg old_ready;

	old_ready <= cart_hdr_ready;
	if(~old_ready & cart_hdr_ready) begin
		//if(status[8]) begin
			case(status[28:27])
				0: if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else if(hdr_j) region_req <= 0;
					else region_req <= 1;
				
				1: if(hdr_e) region_req <= 2;
					else if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else region_req <= 2;
				
				2: if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else if(hdr_e) region_req <= 2;
					else region_req <= 1;

				3: if(hdr_j) region_req <= 0;
					else if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else region_req <= 0;
			endcase
		/*
		end
		else begin
			region_set <= |ioctl_index;
			region_req <= ioctl_index[7:6];
		end
		*/
	end
end

reg [24:0] rom_sz;
reg s32x_rom = 0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= rom_download;

	if(~old_download && rom_download) begin
		{hdr_j,hdr_u,hdr_e} <= 0;
		s32x_rom <= ~|ioctl_index[7:6];
	end
	
	if(old_download && ~rom_download) begin
		cart_hdr_ready <= 0;
		rom_sz <= ioctl_addr[24:0] + 2'd2;
	end

	if(ioctl_wr & rom_download) begin
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_dout[7:0] == "J") hdr_j <= 1;
			else if(ioctl_dout[7:0] == "U") hdr_u <= 1;
			else if(ioctl_dout[7:0] == "E") hdr_e <= 1;
			else if(ioctl_dout[7:0] >= "0" && ioctl_dout[7:0] <= "9") {hdr_e, hdr_u, hdr_j} <= {ioctl_dout[3], ioctl_dout[2], ioctl_dout[0]};
			else if(ioctl_dout[7:0] >= "A" && ioctl_dout[7:0] <= "F") {hdr_e, hdr_u, hdr_j} <= {      hrgn[3],       hrgn[2],       hrgn[0]};
		end
		if(ioctl_addr == 'h1F2) begin
			if(ioctl_dout[7:0] == "J") hdr_j <= 1;
			else if(ioctl_dout[7:0] == "U") hdr_u <= 1;
			else if(ioctl_dout[7:0] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_dout[15:8] == "J") hdr_j <= 1;
			else if(ioctl_dout[15:8] == "U") hdr_u <= 1;
			else if(ioctl_dout[15:8] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h200) cart_hdr_ready <= 1;
	end
end

reg [3:0] eeprom_map = '0;
reg realtec_map = 0;
//reg fifo_quirk = 0;
reg noram_quirk = 0;
reg pier_quirk = 0;
reg svp_quirk = 0;
reg fmbusy_quirk = 0;
reg schan_quirk = 0;
reg [2:0] sf_map = '0;
reg gun_type = 0;
reg [7:0] gun_sensor_delay = 8'd44;
always @(posedge clk_sys) begin
	reg [87:0] cart_id;
	reg [15:0] crc = '0;
	reg [31:0] realtec_id = '0;
	reg old_download;
	old_download <= rom_download;

	if(~old_download && rom_download) {/*fifo_quirk,*/eeprom_map,realtec_map,noram_quirk,pier_quirk,svp_quirk,fmbusy_quirk,schan_quirk,sf_map} <= 0;

	if(ioctl_wr & rom_download) begin
		if(ioctl_addr == 'h180) cart_id[87:72] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h182) cart_id[71:56] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h184) cart_id[55:40] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h186) cart_id[39:24] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h188) cart_id[23:08] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h18A) cart_id[07:00] <= ioctl_dout[7:0];
		if(ioctl_addr == 'h18E) crc <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h190) begin
			if     (cart_id[63:0] == "T-50446 ") eeprom_map        <= 4'b0001; 	// John Madden Football 93
			else if(cart_id[63:0] == "T-50516 ") eeprom_map        <= 4'b0001; 	// John Madden Football 93 Championship Edition
			else if(cart_id[63:0] == "T-50396 ") eeprom_map        <= 4'b0001; 	// NHLPA Hockey 93
			else if(cart_id[63:0] == "T-50176 ") eeprom_map        <= 4'b0001; 	// Rings of Power
			else if(cart_id[63:0] == "T-50606 ") eeprom_map        <= 4'b0001; 	// Bill Walsh College Football
			else if(cart_id[63:0] == "MK-1215 ") eeprom_map        <= 4'b0010; 	// Evander Real Deal Holyfield's Boxing
			else if(cart_id[63:0] == "G-4060  ") eeprom_map        <= 4'b0010; 	// Wonder Boy
			else if(cart_id[63:0] == "00001211") eeprom_map        <= 4'b0010; 	// Sports Talk Baseball
			else if(cart_id[63:0] == "MK-1228 ") eeprom_map        <= 4'b0010; 	// Greatest Heavyweights
			else if(cart_id[63:0] == "G-5538  ") eeprom_map        <= 4'b0010; 	// Greatest Heavyweights JP
			else if(cart_id[63:0] == "00004076") eeprom_map        <= 4'b0010; 	// Honoo no Toukyuuji Dodge Danpei
			else if(cart_id[63:0] == "T-12046 ") eeprom_map        <= 4'b0010; 	// Mega Man - The Wily Wars 
			else if(cart_id[63:0] == "T-12053 ") eeprom_map        <= 4'b0010; 	// Rockman Mega World 
			else if(cart_id[63:0] == "G-4524  ") eeprom_map        <= 4'b0010; 	// Ninja Burai Densetsu
			else if(cart_id[63:0] == "00054503") eeprom_map        <= 4'b0010; 	// Game Toshokan
			else if(cart_id[63:0] == "T-81033 ") eeprom_map        <= 4'b0011; 	// NBA Jam (J)
			else if(cart_id[63:0] == "T-081326") eeprom_map        <= 4'b0011; 	// NBA Jam (U)(E)
			else if(cart_id[63:0] == "T-081276") eeprom_map        <= 4'b1011; 	// NFL Quarterback Club
			else if(cart_id[63:0] == "T-81406 ") eeprom_map        <= 4'b1011; 	// NBA Jam TE
			else if(cart_id[63:0] == "T-081586") eeprom_map        <= 4'b1100; 	// NFL Quarterback Club '96
			else if(cart_id[63:0] == "T-81576 ") eeprom_map        <= 4'b1101; 	// College Slam
			else if(cart_id[63:0] == "T-81476 ") eeprom_map        <= 4'b1101; 	// Frank Thomas Big Hurt Baseball
			else if(cart_id[63:0] == "T-8104B ") eeprom_map        <= 4'b1011; 	// NBA Jam TE (32X)
			else if(cart_id[63:0] == "T-8102B ") eeprom_map        <= 4'b1011; 	// NFL Quarterback Club (32X)
			else if(cart_id[63:0] == "T-113016") noram_quirk       <= 1; 			// Puggsy fake ram check
//			else if(cart_id[63:0] == "T-89016 ") fifo_quirk        <= 1; 			// Clue
			else if(cart_id[63:0] == "T-574023") pier_quirk        <= 1; 			// Pier Solar Reprint
			else if(cart_id[63:0] == "T-574013") pier_quirk        <= 1; 			// Pier Solar 1st Edition
			else if(cart_id[63:0] == "MK-1229 ") svp_quirk         <= 1; 			// Virtua Racing EU/US
			else if(cart_id[63:0] == "G-7001  ") svp_quirk         <= 1; 			// Virtua Racing JP
			else if(cart_id[63:0] == "T-35036 ") fmbusy_quirk      <= 1; 			// Hellfire US
			else if(cart_id[63:0] == "T-25073 ") fmbusy_quirk      <= 1; 			// Hellfire JP
			else if(cart_id[63:0] == "MK-1137-") fmbusy_quirk      <= 1; 			// Hellfire EU
			else if(cart_id[63:0] == "T-68???-") schan_quirk       <= 1; 			// Game no Kanzume Otokuyou
			else if(cart_id[87:40] == "SF-001")  sf_map            <= {crc == 16'h3E08,2'b01}; // Beggar Prince (Unl), Beggar Prince rev 1 (Unl)
			else if(cart_id[87:40] == "SF-002")  sf_map            <= {1'b1,2'b10}; // Legend of Wukong (Unl)
			else if(cart_id[87:40] == "SF-004")  sf_map            <= {1'b1,2'b11}; // Star Odyssey (Unl)
			
			// Lightgun device and timing offsets
			if(cart_id[63:0] == "MK-1533 ") begin						  // Body Count
				gun_type  <= 0;
				gun_sensor_delay <= 8'd100;
			end
			else if(cart_id[63:0] == "T-95096-") begin				  // Lethal Enforcers
				gun_type  <= 1;
				gun_sensor_delay <= 8'd52;
			end
			else if(cart_id[63:0] == "T-95136-") begin				  // Lethal Enforcers II
				gun_type  <= 1;
				gun_sensor_delay <= 8'd30;
			end
			else if(cart_id[63:0] == "MK-1658 ") begin				  // Menacer 6-in-1
				gun_type  <= 0;
				gun_sensor_delay <= 8'd120;
			end
			else if(cart_id[63:0] == "T-081156") begin				  // T2: The Arcade Game
				gun_type  <= 0;
				gun_sensor_delay <= 8'd126;
			end
			else begin
				gun_type  <= 0;
				gun_sensor_delay <= 8'd44;
			end
		end
		
		if(ioctl_addr == 'h7E100) realtec_id[31:16] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h7E102) realtec_id[15: 0] <= {ioctl_dout[7:0],ioctl_dout[15:8]};
		if(ioctl_addr == 'h7E104) begin
			if (realtec_id == "SEGA") realtec_map <= 1; // Earth Defend, Funny World & Balloon Boy, Whac-a-Critter
		end
	end
end

//Genesis
wire [23:1] GEN_VA;
wire [15:0] GEN_VDI, GEN_VDO;
wire        GEN_RNW, GEN_LDS_N, GEN_UDS_N;
wire        GEN_AS_N, GEN_DTACK_N, GEN_ASEL_N;
wire        GEN_RAS2_N, GEN_CAS2_N;
wire        EXT_ROM_N;
wire        EXT_FDC_N;
wire        GEN_VCLK_CE;
wire        GEN_CE0_N;
wire        GEN_LWR_N, GEN_UWR_N, GEN_CAS0_N;
wire        GEN_ROM_CE_N;
wire        GEN_RAM_CE_N;
wire        GEN_TIME_N;

//wire [15:0] GEN_MEM_DO;
wire        GEN_MEM_BUSY;

wire [7:0] color_lut[16] = '{
	8'd0,   8'd27,  8'd49,  8'd71,
	8'd87,  8'd103, 8'd119, 8'd130,
	8'd146, 8'd157, 8'd174, 8'd190,
	8'd206, 8'd228, 8'd255, 8'd255
};

wire [3:0] GEN_R, GEN_G, GEN_B;
wire YS_N;
wire EDCLK;
wire vs,hs;
wire gen_hblank, vblank;
wire interlace;
wire [1:0] resolution;
wire [15:0] laudio, raudio;

wire [15:0] WRAM_Q;
wire [15:1] WRAM_A;
wire [15:0] WRAM_D;
wire        WRAM_CS;
wire        WRAM_LDS;
wire        WRAM_UDS;
wire        WRAM_WE;

gen gen
(
	.RESET_N(~reset),
	.MCLK(clk_sys),
	
	.VA(GEN_VA),
	.VDI(GEN_VDI),
	.VDO(GEN_VDO),
	.RNW(GEN_RNW),
	.LDS_N(GEN_LDS_N),
	.UDS_N(GEN_UDS_N),
	.AS_N(GEN_AS_N),
	.DTACK_N(GEN_DTACK_N),
	.ASEL_N(GEN_ASEL_N),
	.VCLK_CE(GEN_VCLK_CE),
	.CE0_N(GEN_CE0_N),
	.RAS2_N(GEN_RAS2_N),
	.CAS2_N(GEN_CAS2_N),
	.ROM_N(EXT_ROM_N),
	.FDC_N(EXT_FDC_N),
	.CART_N(0),
	.DISK_N(1),
	.LWR_N(GEN_LWR_N),
	.UWR_N(GEN_UWR_N),
	.CAS0_N(GEN_CAS0_N),
	.TIME_N(GEN_TIME_N),

	.WRAM_Q(WRAM_Q),
	.WRAM_A(WRAM_A),
	.WRAM_D(WRAM_D),
	.WRAM_CS(WRAM_CS),
	.WRAM_LDS(WRAM_LDS),
	.WRAM_UDS(WRAM_UDS),
	.WRAM_WE(WRAM_WE),

	.LOADING(rom_download),
	.EXPORT(|region),
	.PAL(PAL),

	.RED(GEN_R),
	.GREEN(GEN_G),
	.BLUE(GEN_B),
	.YS_N(YS_N),
	.EDCLK(EDCLK),
	.VS(vs),
	.HS(hs),
	.HBL(gen_hblank),
	.VBL(vblank),
	.BORDER(st_border),
	.DOT_CE(),
	.FIELD(VGA_F1),
	.INTERLACE(interlace),
	.RESOLUTION(resolution),

	.J3BUT(~status[5]),
	.JOY_1({m_fire1, m_up1, m_down1, m_left1, m_right1}),
	.JOY_2({m_fire2, m_up2, m_down2, m_left2, m_right2}),
	.JOY_3({m_fire3, m_up3, m_down3, m_left3, m_right3}),
	.JOY_4({m_fire4, m_up4, m_down4, m_left4, m_right4}),
	.JOY_5(),
	.MULTITAP(st_multitap),

	.MOUSE(mouse),
	.MOUSE_OPT(status[20:18]),

	.GUN_OPT(),
	.GUN_TYPE(),
	.GUN_SENSOR(),
	.GUN_A(),
	.GUN_B(),
	.GUN_C(),
	.GUN_START(),

	.SERJOYSTICK_IN(SERJOYSTICK_IN),
	.SERJOYSTICK_OUT(SERJOYSTICK_OUT),
	.SER_OPT(SER_OPT),

	.EN_GEN_FM(EN_GEN_FM),
	.EN_GEN_PSG(EN_GEN_PSG),
	.EN_32X_PWM(EN_32X_PWM),
	.EN_HIFI_PCM(status[23]), // Option "N"
	.LADDER(~status[8]),
	.LPF_MODE(status[15:14]),
	.FMBUSY_QUIRK(fmbusy_quirk),

	.EXT_SL(S32X_SL),
	.EXT_SR(S32X_SR),

	.DAC_LDATA(laudio),
	.DAC_RDATA(raudio),

	.OBJ_LIMIT_HIGH(status[31]),

	.MEM_RDY(~GEN_MEM_BUSY),
	.GG_RESET(code_download && ioctl_wr && !ioctl_addr),
	.GG_EN(1'b0),
	.GG_CODE(),
	.GG_AVAILABLE(gg_available),
	
	.PAUSE_EN(DBG_PAUSE_EN),
	.BGA_EN(VDP_BGA_EN),
	.BGB_EN(VDP_BGB_EN),
	.SPR_EN(VDP_SPR_EN),
	.BG_GRID_EN(VDP_BG_GRID_EN),
	.SPR_GRID_EN(VDP_SPR_GRID_EN)
);

assign GEN_MEM_BUSY = !GEN_RAS2_N                  ? 1'b0 : 
                      WRAM_CS                      ? sdr_busy[0] :
                      CART_SRAM_RD || CART_SRAM_WR ? sdr_busy[2] : 
							                                sdr_busy[1];

assign GEN_VDI = s32x_rom ? S32X_VDO : CART_VDO;
assign GEN_DTACK_N = S32X_DTACK_N & CART_DTACK_N;

// 32X
wire [23:1] S32X_CA;
wire [15:0] S32X_CDO;
wire [15:0] S32X_CDI;
wire        S32X_CASEL_N;
wire        S32X_CLWR_N;
wire        S32X_CUWR_N;
wire        S32X_CCE0_N;
wire        S32X_CCAS0_N;
wire        S32X_CCAS2_N;

wire [15:0] S32X_VDO;
wire        S32X_DTACK_N;

wire [17:1] S32X_SDR_A;
wire [15:0] S32X_SDR_DO;
reg  [15:0] S32X_SDR_DI;
wire        S32X_SDR_CS;
wire        S32X_SDR_RFRSH;
wire  [1:0] S32X_SDR_WE;
wire        S32X_SDR_RD;
wire        S32X_SDR_WAIT;

wire [15:0] S32X_MEM_DO;
wire        S32X_ROM_WAIT;

wire [15:0] S32X_FB0_A;
wire [15:0] S32X_FB0_DI;
wire [15:0] S32X_FB0_DO;
wire  [1:0] S32X_FB0_WE;
wire        S32X_FB0_RD;
wire [15:0] S32X_FB1_A;
wire [15:0] S32X_FB1_DI;
wire [15:0] S32X_FB1_DO;
wire  [1:0] S32X_FB1_WE;
wire        S32X_FB1_RD;
	
wire  [4:0] S32X_R;
wire  [4:0] S32X_G;
wire  [4:0] S32X_B;
wire        S32X_YSO_N;
wire        S32X_HBLANK;

wire [15:0] S32X_SL;
wire [15:0] S32X_SR;

S32X #(
	.USE_ROM_WAIT(1),
	.USE_ASYNC_FB(0)
) S32X
(
	.RST_N(~(reset | rom_download)),
	.CLK(clk_sys),

	.VCLK(GEN_VCLK_CE),
	.VA(GEN_VA),
	.VDI(GEN_VDO),
	.VDO(S32X_VDO),
	.AS_N(GEN_AS_N),
	.DTACK_N(S32X_DTACK_N),
	.LWR_N(GEN_LWR_N),
	.UWR_N(GEN_UWR_N),
	.CE0_N(GEN_CE0_N),
	.CAS0_N(GEN_CAS0_N),
	.CAS2_N(GEN_CAS2_N),
	.ASEL_N(GEN_ASEL_N),
	.VRES_N(1'b1),
	.MRES_N(1'b1),
	.CART_N(1'b0),
	
	.VSYNC_N(vs),
	.HSYNC_N(hs),
	.EDCLK(EDCLK),
	.YS_N(YS_N),
	.PAL(PAL),
	
	.CA(S32X_CA),
	.CDI(S32X_CDI),
	.CDO(S32X_CDO),
	.CASEL_N(S32X_CASEL_N),
	.CLWR_N(S32X_CLWR_N),
	.CUWR_N(S32X_CUWR_N),
	.CCE0_N(S32X_CCE0_N),
	.CCAS0_N(S32X_CCAS0_N),
	.CCAS2_N(S32X_CCAS2_N),
	.ROM_WAIT(S32X_ROM_WAIT),
	
	.SDR_A(S32X_SDR_A),
	.SDR_DI(S32X_SDR_DI),
	.SDR_DO(S32X_SDR_DO),
	.SDR_CS(S32X_SDR_CS),
	.SDR_RFRSH(S32X_SDR_RFRSH),
	.SDR_WE(S32X_SDR_WE),
	.SDR_RD(S32X_SDR_RD),
	.SDR_WAIT(S32X_SDR_WAIT),
	
	.FB0_A(S32X_FB0_A),
	.FB0_DI(S32X_FB0_DI),
	.FB0_DO(S32X_FB0_DO),
	.FB0_WE(S32X_FB0_WE),
	.FB0_RD(S32X_FB0_RD),
	.FB1_A(S32X_FB1_A),
	.FB1_DI(S32X_FB1_DI),
	.FB1_DO(S32X_FB1_DO),
	.FB1_WE(S32X_FB1_WE),
	.FB1_RD(S32X_FB1_RD),
	
	.R(S32X_R),
	.G(S32X_G),
	.B(S32X_B),
	.HBL(S32X_HBLANK),
	.YSO_N(S32X_YSO_N),

	.PWM_L(S32X_SL),
	.PWM_R(S32X_SR)
);
assign S32X_CDI = CART_VDO;
assign S32X_ROM_WAIT = (CART_SRAM_RD || CART_SRAM_WR) ? sdr_busy[2] : sdr_busy[1];


//Cart
wire [15:0] CART_VDO;
wire        CART_DTACK_N;

wire [23:1] CART_ROM_A;
wire [15:0] CART_ROM_DI;
wire [15:0] CART_ROM_DO;
wire        CART_ROM_WRL;
wire        CART_ROM_WRH;
wire        CART_ROM_RD;

wire [15:1] CART_SRAM_A;
wire  [7:0] CART_SRAM_DI;
wire  [7:0] CART_SRAM_DO;
wire        CART_SRAM_WR;
wire        CART_SRAM_RD;
CART cart
(
	.CLK(clk_sys),
	.RST_N(~(reset || rom_download)),
	
	.VCLK(GEN_VCLK_CE),
	.VA(!s32x_rom ? GEN_VA : S32X_CA),
	.VDI(!s32x_rom ? GEN_VDO : S32X_CDO),
	.VDO(CART_VDO),
	.AS_N(GEN_AS_N),
	.DTACK_N(CART_DTACK_N),
	.LWR_N(!s32x_rom ? GEN_LWR_N : S32X_CLWR_N),
	.UWR_N(!s32x_rom ? GEN_UWR_N : S32X_CUWR_N),
	.CE0_N(!s32x_rom ? GEN_CE0_N : S32X_CCE0_N),
	.CAS0_N(!s32x_rom ? GEN_CAS0_N : S32X_CCAS0_N),
	.CAS2_N(!s32x_rom ? GEN_CAS2_N : S32X_CCAS2_N),
	.ASEL_N(!s32x_rom ? GEN_ASEL_N : S32X_CASEL_N),
	.TIME_N(GEN_TIME_N),
	
	.ROM_A(CART_ROM_A),
	.ROM_DI(CART_ROM_DI),
	.ROM_DO(CART_ROM_DO),
	.ROM_RD(CART_ROM_RD),
	.ROM_WRL(CART_ROM_WRL),
	.ROM_WRH(CART_ROM_WRH),
	
	.SRAM_A(CART_SRAM_A),
	.SRAM_DI(CART_SRAM_DI),
	.SRAM_DO(CART_SRAM_DO),
	.SRAM_RD(CART_SRAM_RD),
	.SRAM_WR(CART_SRAM_WR),
	
	.rom_sz(rom_sz),
	.s32x(s32x_rom),
	.eeprom_map(eeprom_map),
	.noram_quirk(noram_quirk),
	.realtec_map(realtec_map),
	.sf_map(sf_map)
);
assign CART_ROM_DI = sdr_do[1];
assign CART_SRAM_DI = sdr_do[2][7:0];

always @(posedge clk_sys) begin
	reg old_busy;
	
	old_busy <= sdr_busy[3];
	if(rom_download & ioctl_wr) ioctl_wait <= 1;
	if(old_busy & ~sdr_busy[3]) ioctl_wait <= 0;
end

assign WRAM_Q = sdr_do[0][15:0];

wire sdr_busy[4];
wire [15:0] sdr_do[4];
sdram sdram
(
	.*,
	.SDRAM_CLK(),
	.init(~pll_locked),
	.clk(clk_ram),

	//SDRAM
	.addr0({9'b100000000,WRAM_A}), // 1000000-100FFFF
	.din0(WRAM_D),
	.dout0(sdr_do[0]),
	.rd0(WRAM_CS & ~WRAM_WE),
	.wr0({2{WRAM_CS & WRAM_WE}} & {WRAM_UDS, WRAM_LDS}),
	.busy0(sdr_busy[0]),

	//CART ROM
	.addr1({1'b0,CART_ROM_A[23:1]}),
	.din1(CART_ROM_DO),
	.dout1(sdr_do[1]),
	.rd1(CART_ROM_RD | CART_ROM_WRL | CART_ROM_WRH),
	.wr1({CART_ROM_WRH,CART_ROM_WRL} & {2{schan_quirk}}),
	.busy1(sdr_busy[1]),

	//CART SRAM
	.addr2({9'b110000000,CART_SRAM_A[15:1]}),	//CART RAM 1800000-180FFFF
	.din2({8'hFF,CART_SRAM_DO}),
	.dout2(sdr_do[2]),
	.rd2(CART_SRAM_RD),
	.wr2({2{CART_SRAM_WR}}),
	.busy2(sdr_busy[2]),
	
	//ROM/BRAM Load/Save
	.addr3(rom_download ? {1'b0,ioctl_addr[23:1]} : {9'b110000000,sd_lba[6:0],tmpram_addr}),
	.din3(rom_download ? {ioctl_dout[7:0],ioctl_dout[15:8]} : {tmpram_dout[7:0],tmpram_dout[15:8]}),
	.dout3(sdr_do[3]),
	.rd3(rom_download ? 1'b0 : (tmpram_req & ~bk_loading)),
	.wr3(rom_download ? {2{ioctl_wait}} : {2{tmpram_req & bk_loading}}),
	.busy3(sdr_busy[3])
);

wire        sdr_rd;
wire  [1:0] sdr_we;
assign sdr_rd = S32X_SDR_RD & S32X_SDR_CS;
assign sdr_we = S32X_SDR_WE & {2{S32X_SDR_CS}};

sdram_sh2 sdram_sh2
(
	.SDRAM_A(SDRAM2_A),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_DQML(SDRAM2_DQML),
	.SDRAM_DQMH(SDRAM2_DQMH),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_nCAS(SDRAM2_nCAS),

	.init_n(pll_locked2),
	.clk(clk_ram2),
	.rst(reset | rom_download),

	.port1_rfrsh(S32X_SDR_CS & S32X_SDR_RFRSH),
	.port1_a(S32X_SDR_A),
	.port1_d(S32X_SDR_DO),
	.port1_q(S32X_SDR_DI),
	.port1_rd(sdr_rd),
	.port1_we(sdr_we),
	.port1_busy(S32X_SDR_WAIT)
);

spram #(16,8) vdp_fb0_l
(
	.clock(clk_sys),
	.address(S32X_FB0_A),
	.data(S32X_FB0_DO[7:0]),
	.wren(S32X_FB0_WE[0]),
	.q(S32X_FB0_DI[7:0])
);

spram #(16,8) vdp_fb0_u
(
	.clock(clk_sys),
	.address(S32X_FB0_A),
	.data(S32X_FB0_DO[15:8]),
	.wren(S32X_FB0_WE[1]),
	.q(S32X_FB0_DI[15:8])
);

spram #(16,8) vdp_fb1_l
(
	.clock(clk_sys),
	.address(S32X_FB1_A),
	.data(S32X_FB1_DO[7:0]),
	.wren(S32X_FB1_WE[0]),
	.q(S32X_FB1_DI[7:0])
);

spram #(16,8) vdp_fb1_u
(
	.clock(clk_sys),
	.address(S32X_FB1_A),
	.data(S32X_FB1_DO[15:8]),
	.wren(S32X_FB1_WE[1]),
	.q(S32X_FB1_DI[15:8])
);

wire [7:0] r, g, b;
always_comb begin
	if ((VDP_MD_EN && !VDP_32X_EN) || !s32x_rom) begin
		r = color_lut[GEN_R];
		g = color_lut[GEN_G];
		b = color_lut[GEN_B];
	end else if (!VDP_MD_EN && VDP_32X_EN) begin
		r = {S32X_R,S32X_R[4:2]};
		g = {S32X_G,S32X_G[4:2]};
		b = {S32X_B,S32X_B[4:2]};
	end else begin
		r = !S32X_YSO_N ? {S32X_R,S32X_R[4:2]} : color_lut[GEN_R];
		g = !S32X_YSO_N ? {S32X_G,S32X_G[4:2]} : color_lut[GEN_G];
		b = !S32X_YSO_N ? {S32X_B,S32X_B[4:2]} : color_lut[GEN_B];
	end

end

/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////

wire downloading = rom_download;
reg  bk_load    = 0;
wire bk_save    = status[1];

reg bk_ena = 0;
reg sav_pending = 0;
always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_change = 0;

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	bk_load <= 0;
	if(img_mounted) begin
		bk_ena <= |img_size;
		bk_load <= |img_size;
	end
end

reg  bk_loading = 0;
reg  bk_state   = 0;

always @(posedge clk_sys) begin
	reg old_load = 0, old_save = 0, old_ack;
	reg [1:0] state;

	old_load   <= bk_load;
	old_save   <= bk_save;
	old_ack    <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if (!bk_state) begin
		tmpram_tx_start <= 0;
		state <= 0;
		sd_lba <= 0;
//		bk_reload <= 0;
		bk_loading <= 0;
		if (bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
//			bk_reload <= bk_load;
			sd_rd <=  bk_load;
			sd_wr <= 0;
		end
	end
	else begin
		if (bk_loading) begin
			case(state)
				0: begin
						sd_rd <= 1;
						state <= 1;
					end
				1: if(old_ack & ~sd_ack) begin
						tmpram_tx_start <= 1;
						state <= 2;
					end
				2: if(tmpram_tx_finish) begin
						tmpram_tx_start <= 0;
						state <= 0;
						sd_lba <= sd_lba + 1'd1;
						if(sd_lba[6:0] == 7'h7F) bk_state <= 0;
					end
			endcase
		end
		else begin
			case(state)
				0: begin
						tmpram_tx_start <= 1;
						state <= 1;
					end
				1: if(tmpram_tx_finish) begin
						tmpram_tx_start <= 0;
						sd_wr <= 1;
						state <= 2;
					end
				2: if(old_ack & ~sd_ack) begin
						state <= 0;
						sd_lba <= sd_lba + 1'd1;
						if(sd_lba[6:0] == 7'h7F) bk_state <= 0;
					end
			endcase
		end
	end
end

wire [15:0] tmpram_dout;
wire [15:0] tmpram_din = {sdr_do[3][7:0],sdr_do[3][15:8]};
wire        tmpram_busy = sdr_busy[3];

dpram_dif #(8,16,9,8) tmpram
(
	.clock(clk_sys),

	.address_a(tmpram_addr),
	.wren_a(~bk_loading & tmpram_busy_d & ~tmpram_busy),
	.data_a(tmpram_din),
	.q_a(tmpram_dout),

	.address_b(sd_buff_addr),
	.wren_b(sd_buff_wr & sd_ack /*& |sd_lba[10:4]*/),
	.data_b(sd_buff_dout),
	.q_b(sd_buff_din)
);

//reg [10:0] tmpram_lba;
reg  [8:1] tmpram_addr;
reg tmpram_tx_start;
reg tmpram_tx_finish;
reg tmpram_req;
reg tmpram_busy_d;
always @(posedge clk_sys) begin
	reg state;

//	tmpram_lba <= sd_lba[10:0] - 11'h10;
	
	tmpram_busy_d <= tmpram_busy;
	if (~tmpram_busy_d & tmpram_busy) tmpram_req <= 0;

	if (~tmpram_tx_start) {tmpram_addr, state, tmpram_tx_finish} <= '0;
	else if(~tmpram_tx_finish) begin
		if(!state) begin
			tmpram_req <= 1;
			state <= 1;
		end
		else if(tmpram_busy_d & ~tmpram_busy) begin
			state <= 0;
			if(~&tmpram_addr) tmpram_addr <= tmpram_addr + 1'd1;
			else tmpram_tx_finish <= 1;
		end
	end
end

///////////////////////////// VIDEO /////////////////////////////////////

wire hblank = s32x_rom ? S32X_HBLANK : gen_hblank;

mist_video #(.SD_HCNT_WIDTH(11), .COLOR_DEPTH(8), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video
(
	.clk_sys(clk_sys),
	.scanlines(scanlines),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync),
	.rotate(2'b00),
	.blend(1'b0),
	.ce_divider(resolution[0] ? 4'd7 : 4'd9),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(hblank),
	.VBlank(vblank),
	.R(r),
	.G(g),
	.B(b),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B)
);

////////////////////////////  HDMI  ///////////////////////////////////

`ifdef USE_HDMI
i2c_master #(53_690_000) i2c_master (
	.CLK         (clk_sys),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.SD_HCNT_WIDTH(11), .COLOR_DEPTH(8), .USE_BLANKS(1'b1), .OUT_COLOR_DEPTH(8), .BIG_OSD(BIG_OSD), .VIDEO_CLEANER(1'b1)) hdmi_video
(
	.clk_sys(clk_sys),
	.scanlines(scanlines),
	.scandoubler_disable(1'b0),
	.ypbpr(1'b0),
	.no_csync(1'b1),
	.rotate(2'b00),
	.blend(1'b0),
	.ce_divider(resolution[0] ? 4'd7 : 4'd9),
	.SPI_DI(SPI_DI),
	.SPI_SCK(SPI_SCK),
	.SPI_SS3(SPI_SS3),
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(hblank),
	.VBlank(vblank),
	.R(r),
	.G(g),
	.B(b),
	.VGA_HS(HDMI_HS),
	.VGA_VS(HDMI_VS),
	.VGA_R(HDMI_R),
	.VGA_G(HDMI_G),
	.VGA_B(HDMI_B),
	.VGA_DE(HDMI_DE)
);

assign HDMI_PCLK = clk_sys;
`endif

//////////////////   AUDIO   //////////////////

hybrid_pwm_sd_2ndorder dac
(
	.clk(clk_sys),
	.reset_n(1'b1),
	.d_l({~laudio[15], laudio[14:0]}),
	.q_l(AUDIO_L),
	.d_r({~raudio[15], raudio[14:0]}),
	.q_r(AUDIO_R)
);

`ifdef I2S_AUDIO
i2s i2s
(
	.reset(1'b0),
	.clk(clk_sys),
	.clk_rate(32'd53_690_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({laudio}),
	.right_chan({raudio})
);
`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_sys),
	.rst_i(1'b0),
	.clk_rate_i(32'd53_690_000),
	.spdif_o(SPDIF),
	.sample_i({raudio, laudio})
);
`endif

////////////////////////////  INPUT  ///////////////////////////////////

wire m_up1, m_down1, m_left1, m_right1;
wire m_up2, m_down2, m_left2, m_right2;
wire m_up3, m_down3, m_left3, m_right3;
wire m_up4, m_down4, m_left4, m_right4;
wire [11:0] m_fire1, m_fire2, m_fire3, m_fire4;
wire m_tilt, m_coin1, m_coin2, m_coin3, m_coin4, m_one_player, m_two_players, m_three_players, m_four_players;

arcade_inputs #(.START1(7)) inputs (
	.clk         ( clk_sys     ),
	.key_strobe  ( key_strobe  ),
	.key_pressed ( key_pressed ),
	.key_code    ( key_code    ),
	.joystick_0  ( joy_0       ),
	.joystick_1  ( joy_1       ),
	.joystick_2  ( joy_2       ),
	.joystick_3  ( joy_3       ),
	.rotate      ( 2'b00       ),
	.orientation ( 2'b00       ),
	.joyswap     ( joyswap     ),
	.oneplayer   ( 1'b0        ),
	.controls    ( {m_tilt, m_coin4, m_coin3, m_coin2, m_coin1, m_four_players, m_three_players, m_two_players, m_one_player} ),
	.player1     ( {m_fire1, m_up1, m_down1, m_left1, m_right1} ),
	.player2     ( {m_fire2, m_up2, m_down2, m_left2, m_right2} ),
	.player3     ( {m_fire3, m_up3, m_down3, m_left3, m_right3} ),
	.player4     ( {m_fire4, m_up4, m_down4, m_left4, m_right4} )
);

endmodule
