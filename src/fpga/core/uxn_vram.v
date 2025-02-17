module uxn_vram
(
	input [1:0] write_value,
	input [16:0] read_addr, write_addr, // 2^17 = 131072
	input write_enable, read_clock, write_clock,
	output reg [1:0] read_value
);
	// Declare the RAM variable
	reg [1:0] ram[131071:0];
	
	always @ (posedge write_clock)
	begin
		// Write
		if (write_enable)
			ram[write_addr] <= write_value;
	end
	
	always @ (posedge read_clock)
	begin
		// Read 
		read_value <= ram[read_addr];
	end
endmodule
