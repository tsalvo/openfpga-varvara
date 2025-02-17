module uxn_queue_ram_dp
(
	input [23:0] data,
	input [11:0] wr_addr, rd_addr,
	input we, clk,
	output reg [23:0] q
);
	// Declare the RAM variable
	reg [23:0] ram[4095:0];
	
	// Port A (writing)
	always @ (posedge clk)
	begin
		if (we) 
		begin
			ram[wr_addr] <= data;
		end
	end
	
	// Port B (reading)
	always @ (posedge clk)
	begin
		q <= ram[rd_addr];
	end
	
endmodule
