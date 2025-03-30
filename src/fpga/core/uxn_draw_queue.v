module uxn_draw_queue
(
	input [23:0] data,
	input we,
	input [7:0] main_ram_read_value,
	input [23:0] queue_ram_read_value,
	input clk,

	output reg [15:0] main_ram_addr,
	output reg queue_ram_write_enable,
	output reg [11:0] queue_ram_wr_addr,
	output reg [23:0] queue_ram_write_value,
	output reg [11:0] queue_ram_rd_addr,

	output reg vram_write_enable, 
	output reg vram_write_layer,
	output reg [16:0] vram_write_addr,
	output reg [1:0] vram_write_value,

	output reg is_queue_empty
);

	reg [7:0] queue_draw_phase = 0;
	reg [3:0] inner_draw_phase = 0;

	reg [15:0] sprite_row;
	reg [2:0] queue_fetch_phase = 0;
	reg [3:0] color = 0;
	reg layer = 0;
	reg [1:0] draw_mode = 0; // 0 = pixel, 1 = fill, 2 = sprite 1bpp, 3 = sprite 2bpp
	reg is_valid = 0;
	reg [15:0] x0 = 0;
	reg [15:0] x1 = 0;
	reg [15:0] y1 = 0;
	reg [15:0] x = 0;
	reg [15:0] y = 0;
	reg [11:0] rd_ptr = 0;
	reg [11:0] wr_ptr = 0;
	reg [15:0] sprite_addr = 0;
	reg [15:0] blending0_1 = 16'b0111101100000000;
	reg [15:0] blending0_0 = 16'b0111000011010000;
	reg [15:0] blending1_1 = 16'b1100110011001100;
	reg [15:0] blending1_0 = 16'b1010101010101010;
	reg [15:0] blending2_1 = 16'b0110011001100110;
	reg [15:0] blending2_0 = 16'b1101110111011101;
	reg [15:0] blending3_1 = 16'b1011101110111011;
	reg [15:0] blending3_0 = 16'b0110011001100110;
	reg [23:0] queue_item_data_0 = 0;
	reg [23:0] queue_item_data_1 = 0;
	reg has_qd0 = 0;
	reg [15:0] opaque_bits = 16'b0111101111011110;
	reg opaque = 0;
	reg fx = 0;
	reg fy = 0;

	always @ (posedge clk)
	begin
		is_queue_empty <= (wr_ptr < rd_ptr + 1);
	end

	always @ (posedge clk)
	begin
		queue_ram_write_enable <= 1;
		case (we)
		0: begin
			queue_ram_wr_addr <= wr_ptr + 2;
			queue_ram_write_value <= 0;
		end
		1: begin
			queue_ram_wr_addr <= wr_ptr;
			queue_ram_write_value <= data;
			wr_ptr <= wr_ptr + 1;
		end
		endcase
	end

	always @ (posedge clk)
	begin
		case (is_valid)
		0: begin
			queue_fetch_phase <= queue_fetch_phase + 1;
			vram_write_enable <= 0;
			vram_write_value <= 0;
			vram_write_addr <= 0;
			vram_write_layer <= 0;
			main_ram_addr <= 0;
			queue_draw_phase <= 0;
			inner_draw_phase <= 0;
			case (queue_fetch_phase)
			0: begin
				queue_ram_rd_addr <= rd_ptr;
			end
			1: begin
				queue_ram_rd_addr <= rd_ptr + 1;
			end
			2: begin
				queue_item_data_0 <= queue_ram_read_value;
			end
			3: begin
				has_qd0 <= queue_item_data_0 != 24'd0;
				queue_item_data_1 <= queue_ram_read_value;
				draw_mode <= {~queue_item_data_0[20] & queue_item_data_0[19], queue_item_data_0[20] | queue_item_data_0[18]};
				layer <= queue_item_data_0[23];
				x <= queue_item_data_0[20] & queue_item_data_0[18] ? 0 : {7'd0, queue_item_data_0[17:9]};
				y <= queue_item_data_0[20] & queue_item_data_0[19] ? 0 : {7'd0, queue_item_data_0[8:0]};
			end
			4: begin
				queue_fetch_phase <= 0;
				case (draw_mode)
				0, 1: begin // single pixel or fill
					x0 <= x;
					x1 <= queue_item_data_0[20] & queue_item_data_0[18] ? {7'd0, queue_item_data_0[17:9]} : 16'd319;
					y1 <= queue_item_data_0[20] & queue_item_data_0[19] ? {7'd0, queue_item_data_0[8:0]} : 16'd287;
					color <= {2'd0, queue_item_data_0[22:21]};
					rd_ptr <= rd_ptr + {11'd0, has_qd0};
					is_valid <= has_qd0;
				end
				2, 3: begin // sprite 1 bpp or 2 bpp
					sprite_addr <= queue_item_data_1[15:0];
					color <= {queue_item_data_1[17:16], queue_item_data_0[22:21]};
					x <= queue_item_data_1[18] ? x : x + 7;
					x0 <= queue_item_data_1[18] ? x : x + 7;
					y <= queue_item_data_1[19] ? y + 7 : y;
					fx <= queue_item_data_1[18];
					fy <= queue_item_data_1[19];
					opaque <= opaque_bits[{queue_item_data_1[17:16], queue_item_data_0[22:21]}];
					rd_ptr <= rd_ptr + {10'd0, has_qd0, 1'b0};
					is_valid <= has_qd0;
				end
				endcase
			end
			endcase
		end
		1: begin
			queue_fetch_phase <= 0;
			queue_draw_phase <= queue_draw_phase + 1;
			inner_draw_phase <= inner_draw_phase + 1;
			case (draw_mode)
			0: begin // single pixel
				vram_write_enable <= 1;
				vram_write_addr <= y*320+x;
				vram_write_layer <= layer;
				vram_write_value <= color[1:0];
				main_ram_addr <= 0;
				is_valid <= 0;
			end
			1: begin // fill
				vram_write_enable <= 1;
				vram_write_addr <= y*320+x;
				vram_write_layer <= layer;
				vram_write_value <= color[1:0];
				main_ram_addr <= 0;
				x <= x == x1 ? x0 : x + 1;
				y <= x == x1 ? y + 1 : y;
				is_valid <= (x != x1 ? 1 : 0) | (y != y1 ? 1 : 0);
			end
			2: begin // sprite 1bpp 
				case (inner_draw_phase) 
				0: begin
					main_ram_addr <= sprite_addr;
				end
				1: begin
					sprite_addr <= sprite_addr + 1;
				end
				2: begin
					sprite_row <= {8'd0, main_ram_read_value};
				end
				11: begin
					x <= x0;
					y <= fy ? (y - 1) : (y + 1);
					vram_write_enable <= 0;
					inner_draw_phase <= 0;
					is_valid <= queue_draw_phase == 8'd95 ? 0 : is_valid;
				end
				default: begin
					sprite_row <= sprite_row >> 1;
					x <= fx ? (x + 1) : (x - 1);
					vram_write_enable <= x < 16'd320 & y < 16'd288 & (opaque | sprite_row[0]);
					vram_write_layer <= layer;
					vram_write_addr <= y*320+x;
					vram_write_value <= sprite_row[0] ? {blending1_1[color], blending1_0[color]} : {blending0_1[color], blending0_0[color]};
				end
				endcase
			end
			3: begin // sprite 2bpp 
				case (inner_draw_phase) 
				0: begin
					main_ram_addr <= sprite_addr;
				end
				1: begin
					main_ram_addr <= sprite_addr + 8;
				end
				2: begin
					sprite_row[7:0] <= main_ram_read_value;
					sprite_addr <= sprite_addr + 1;
				end
				3: begin
					sprite_row[15:8] <= main_ram_read_value;
				end
				12: begin
					x <= x0;
					y <= fy ? (y - 1) : (y + 1);
					vram_write_enable <= 0;
					inner_draw_phase <= 0;
					is_valid <= queue_draw_phase == 8'd103 ? 0 : is_valid;
				end
				default: begin
					sprite_row <= sprite_row >> 1;
					x <= fx ? (x + 1) : (x - 1);
					vram_write_enable <= x < 16'd320 & y < 16'd288 & (opaque | sprite_row[0] | sprite_row[8]);
					vram_write_layer <= layer;
					vram_write_addr <= (y * 16'd320) + x;
					vram_write_value <= sprite_row[8] ? (sprite_row[0] ? {blending3_1[color], blending3_0[color]} : {blending2_1[color], blending2_0[color]}) : (sprite_row[0] ? {blending1_1[color], blending1_0[color]} : {blending0_1[color], blending0_0[color]});
				end
				endcase
			end
			endcase
		end
		endcase
	end
endmodule
/*
vccftlxx xxxxxxxy yyyyyyyy
0000yxcc aaaaaaaa aaaaaaaa
*/
