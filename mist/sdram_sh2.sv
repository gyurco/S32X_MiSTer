//
// sdram.v
//
// sdram controller implementation for the MiST board
// https://github.com/mist-devel/mist-board
// 
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019-2022 Gyorgy Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sdram_sh2 (

	// interface to the MT48LC16M16 chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // two byte masks
	output reg        SDRAM_DQMH, // two byte masks
	output reg [1:0]  SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output            SDRAM_nWE,  // write enable
	output            SDRAM_nRAS, // row address select
	output            SDRAM_nCAS, // columns address select

	// cpu/chipset interface
	input             init_n,     // init signal after FPGA config to initialize RAM
	input             clk,        // sdram clock
	input             rst,

	// 1st bank
	input             port1_rfrsh,
	input             port1_rd,
	input       [1:0] port1_we,
	input      [24:1] port1_a,
	input      [15:0] port1_d,
	output     [15:0] port1_q,
	output     reg    port1_busy
);

localparam RASCAS_DELAY   = 3'd3;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b011; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

localparam STATE_RAS0      = 4'd0;   // first state in cycle
localparam STATE_CAS0      = 4'd3;
localparam STATE_READ0     = 4'd8;   // STATE_CAS0 + CAS_LATENCY + 2'd2;
localparam STATE_READ1     = 4'd9;
localparam STATE_READ2     = 4'd10;
localparam STATE_READ3     = 4'd11;
localparam STATE_READ4     = 4'd12;
localparam STATE_READ5     = 4'd13;
localparam STATE_READ6     = 4'd14;
localparam STATE_READ7     = 4'd15;
localparam STATE_LAST      = 4'd15;

reg [3:0] t;

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
	if(!init_n) begin
		reset <= 5'h1f;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 5'd1;
		init <= !(reset == 0);
	end
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0]  sd_cmd;   // current command sent to sd ram
// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];


reg         refresh;
reg  [15:0] data_latch[8];
reg   [2:0] burst_cnt;
reg   [2:0] read_cnt;
reg   [1:0] we_latch;
reg         oe_latch;
reg         port1_rfrshD;
reg         port1_rdD;
reg   [1:0] port1_weD;
reg         port1_rd_req;
reg         port1_rfrsh_req;
reg   [1:0] port1_we_req;
reg  [15:0] we_buf;
reg  [24:1] ad_buf;
reg  [15:0] sd_din;
reg   [7:0] rfrsh_cnt;

assign port1_q = data_latch[burst_cnt];

always @(posedge clk) begin

	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	SDRAM_BA <= 2'b00;
	sd_din <= SDRAM_DQ;
	sd_cmd <= CMD_NOP;  // default: idle
	t <= t + 1'd1;
	if (t == STATE_LAST) t <= STATE_RAS0;

	if(init) begin
		burst_cnt <= 0;
		read_cnt <= 0;
		oe_latch <= 0;
		we_latch <= 0;
		refresh <= 0;
		port1_busy <= 0;
		port1_rd_req <= 0;
		port1_we_req <= 0;
		port1_rfrsh_req <= 0;
		// initialization takes place at the end of the reset phase
		if(t == STATE_RAS0) begin

			if(reset == 15) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			if(reset == 10 || reset == 8) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			if(reset == 2) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		// RAS phase
		// bank 0,1
		if (rst) burst_cnt <= 0;
		port1_rdD <= port1_rd;
		port1_weD <= port1_we;
		port1_rfrshD <= port1_rfrsh;
		if (~port1_rfrshD && port1_rfrsh) begin
			port1_rfrsh_req <= 1;
			ad_buf <= {rfrsh_cnt, 9'd0};
			rfrsh_cnt <= rfrsh_cnt + 1'd1;
		end
		if (burst_cnt == 0 && ~port1_rdD && port1_rd) begin
			port1_rd_req <= 1;
			ad_buf <= port1_a;
		end
		if (~|port1_weD & |port1_we) begin
			port1_we_req <= port1_we;
			ad_buf <= port1_a;
			we_buf <= port1_d;
		end
		if (burst_cnt != 0 && ~port1_rdD && port1_rd) begin
			burst_cnt <= burst_cnt - 1'd1;
		end
		if(t == STATE_RAS0) begin
			oe_latch <= 0;
			we_latch <= 0;
			refresh <= 0;
			if (burst_cnt == 0 && (port1_rfrsh_req | port1_rd_req | |port1_we_req)) begin
				port1_rd_req <= 0;
				port1_we_req <= 0;
				port1_rfrsh_req <= 0;
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= ad_buf[22:10];
				if (port1_rd) begin
					burst_cnt <= 7;
					read_cnt <= 7;
					oe_latch <= 1;
					port1_busy <= 1;
				end
				if (|port1_we_req) we_latch <= port1_we_req;
				if (port1_rfrsh_req) refresh <= 1;
			end else
				t <= t;
		end

		// CAS phase
		if(t == STATE_CAS0 && (|we_latch || oe_latch)) begin
			sd_cmd <= |we_latch?CMD_WRITE:CMD_READ;
			if (|we_latch) begin
				{ SDRAM_DQMH, SDRAM_DQML } <= ~we_latch;
				SDRAM_DQ <= we_buf;
			end
			SDRAM_A <= { 4'b0010, ad_buf[9:1] };  // auto precharge
		end

		if(t == STATE_CAS0 && refresh)
			sd_cmd <= CMD_PRECHARGE;

		if(t == 7) begin
			if (we_latch | refresh)	t <= STATE_RAS0;
			port1_busy <= 0;
		end

		// Data returned
		if(t > STATE_CAS0 && t <= STATE_READ5 && oe_latch) begin
			{ SDRAM_DQMH, SDRAM_DQML } <= 0;
		end
		if(t >= STATE_READ0 && t <= STATE_READ7 && oe_latch) begin
			data_latch[read_cnt] <= sd_din;
			read_cnt <= read_cnt - 1'd1;
		end
	end
end

endmodule
