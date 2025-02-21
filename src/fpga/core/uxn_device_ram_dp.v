module uxn_device_ram_dp
(
	input [7:0] data_a,
	input [7:0] addr_a, addr_b,
	input we_a, clk_a, clk_b,
	output reg [7:0] q_a, q_b
);
	// Declare the RAM variable
	reg [7:0] ram[255:0];
	
	// Port A
	always @ (posedge clk_a)
	begin
		case (we_a)
		0: begin
			q_a <= ram[addr_a];
		end
		1: begin
			ram[addr_a] <= data_a;
			q_a <= data_a;
		end
		endcase
	end
	
	// Port B
	always @ (posedge clk_b)
	begin
		q_b <= ram[addr_b];
	end
	
endmodule
