// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module SH_regram (
	input	  clock,
	input	[31:0]  data,
	input	[3:0]  rdaddress,
	input	[3:0]  wraddress,
	input	  wren,
	output reg [31:0]  q
);

	reg [31:0] regs[16];
	always @(posedge clock)
		if (wren) regs[wraddress] <= data;

	always @(negedge clock)
		q <= regs[rdaddress];

endmodule

module CACHE_RAM (
	input	[7:0]  data,
	input	[9:0]  rdaddress,
	input	  rdclock,
	input	[9:0]  wraddress,
	input	  wrclock,
	input	  wren,
	output reg [7:0]  q
);

	reg [7:0] mem[1024];

	always @(posedge wrclock)
		if (wren) mem[wraddress] <= data;

	always @(posedge rdclock)
		q <= mem[rdaddress];

endmodule


module CACHE_TAG (
	input	[19:0]  data,
	input	[5:0]  rdaddress,
	input	  clock,
	input	[5:0]  wraddress,
	input	  wren,
	output reg [19:0]  q
);

	reg [19:0] mem[64];

	always @(posedge clock)
		if (wren) mem[wraddress] <= data;

	always @(negedge clock)
		q <= mem[rdaddress];

endmodule

module CACHE_LRU (
	input	[5:0]  data,
	input	[5:0]  rdaddress,
	input	  clock,
	input	[5:0]  wraddress,
	input	  wren,
	output reg [5:0]  q
);

	reg [5:0] mem[64];

	always @(posedge clock)
		if (wren) mem[wraddress] <= data;

	always @(posedge clock)
		q <= mem[rdaddress];

endmodule
