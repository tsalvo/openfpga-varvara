/* Registers
[ Z ][ Y ][ X ][ L ][ N ][ T ] <
[ . ][ . ][ . ][   H2   ][ . ] <
[   L2   ][   N2   ][   T2   ] <
*/

module uxn_cpu
(
	input cpu_clock,
	input vsync,
	input mouse_enable,
	input rtc_valid,
	input [31:0] rtc_date_bcd,
	input [31:0] rtc_time_bcd,
	input [7:0]  controller0, // u d l r s s a b
	input [7:0]  main_ram_read_value,
	input [7:0]  stack_ram_read_value_a,
	input [7:0]  stack_ram_read_value_b,
	input [7:0]  device_ram_read_value,
	input [15:0] boot_read_address,
	input [7:0]  boot_read_value,
	input        boot_valid_byte,
	input        is_draw_queue_ready,
	input        did_copy_buffer,
	
	output reg main_ram_write_enable,
	output reg [15:0] main_ram_addr,
	output reg [7:0] main_ram_write_value,
	
	output reg stack_ram_write_enable_a,
	output reg [8:0] stack_ram_addr_a,
	output reg [7:0] stack_ram_write_value_a,
	output reg stack_ram_write_enable_b,
	output reg [8:0] stack_ram_addr_b,
	output reg [7:0] stack_ram_write_value_b,
	
	output reg device_ram_write_enable,
	output reg [7:0] device_ram_addr,
	output reg [7:0] device_ram_write_value,
	
	output reg queue_write_enable, 
	output reg [23:0] queue_write_value,
	
	output reg is_screen_vector_running
);
	reg [15:0] pc = 16'h0100;
	reg [7:0] phase = 0;
	reg [7:0] opc_phase = 0;
	reg [7:0] deo_phase = 0;
	reg [2:0] inner_sprite_phase = 0;
	reg is_booted = 0;
	reg boot_timeout = 0;
	reg boot_ram_full = 0;
	reg is_ins_done = 0;
	reg is_wait = 0;
	reg ins_7 = 0;
	reg stack_index = 0;
	reg [23:0] boot_phase = 0;
	reg [7:0] opc = 0;
	reg [7:0] sp0 = 0;
	reg [7:0] sp1 = 0;
	reg [7:0] t8 = 0;
	reg [7:0] n8 = 0;
	reg [7:0] l8 = 0;
	reg [7:0] x8 = 0;
	reg [7:0] y8 = 0;
	reg [7:0] z8 = 0;
	reg [7:0] sp_offset_a = 0;
	reg [7:0] sp_offset_b = 0;
	reg is_stack_index_flipped = 0;
	
	reg [7:0] last_controller0 = 0;
	reg [15:0] x = 0;
	reg [15:0] y = 0;
	reg [8:0] mouse_x = 0;
	reg [8:0] mouse_y = 0;
	reg [15:0] spr_x = 0;
	reg [15:0] spr_y = 0;
	reg [8:0] pxl_x = 0;
	reg [8:0] pxl_y = 0;
	reg [15:0] screen_ram_addr = 0;
	reg [1:0] px_color = 0;
	reg [3:0] spr_color = 0;
	reg [3:0] screen_auto_length = 0;
	reg is_last_blit = 0;
	reg is_vsync = 0;
	reg [1:0] vsync_phase = 0;
	reg [1:0] controller_phase = 0;
	reg spr_mode = 0;
	reg px_mode = 0;
	reg px_flip_x = 0;
	reg px_flip_y = 0;
	reg spr_flip_x = 0;
	reg spr_flip_y = 0;
	reg is_x_in_bounds = 0;
	reg is_y_in_bounds = 0;
	reg spr_layer = 0;
	reg px_layer = 0;
	reg is_auto_addr = 0;
	reg is_auto_x = 0;
	reg is_auto_y = 0;
	reg is_auto_px_x = 0;
	reg is_auto_px_y = 0;
	reg is_dei_done = 0;
	reg is_deo_done = 0;
	reg is_second_deo = 0;
	reg is_second_dei = 0;
	reg pending_controller = 0;
	reg is_mouse = 0;
	reg is_draw_queue_ready_reg = 0;
	reg did_copy_buffer_reg = 0;
	
	reg last_vsync = 0;
	reg [31:0] rtc_date_bcd_r = 0;
	reg [31:0] rtc_time_bcd_r = 0; 
	reg [15:0] year = 0; 
	reg [7:0] month = 0;
	reg [7:0] day_of_month = 0;
	reg [7:0] day_of_week = 0;
	reg [7:0] ticks = 0;
	reg [7:0] seconds = 0;
	reg [7:0] minutes = 0;
	reg [7:0] hours = 0;
	reg has_read_rtc = 0;
	reg has_set_time = 0;
	reg [3:0] set_clock_phase = 0;

	always @ (posedge cpu_clock)
	begin
		last_vsync <= vsync;
		case (has_read_rtc)
		0: begin
			// get initial date and time from device RTC
			set_clock_phase <= 0;
			case (rtc_valid)
			0: begin end
			1: begin
				rtc_date_bcd_r <= rtc_date_bcd;
				rtc_time_bcd_r <= rtc_time_bcd;
				has_read_rtc <= 1;
			end
			endcase
		end
		1: begin
			case (has_set_time)
			0: begin
				set_clock_phase <= set_clock_phase + 1;
				case (set_clock_phase)
				0: begin
					ticks <= 8'h0A * {4'h0, rtc_date_bcd_r[23:20]} + {4'h0, rtc_date_bcd_r[19:16]}; // use ticks as temp variable
				end
				1: begin
					// TODO: we're not reading the upper two digits of the year. fix by 2100
					year <= 16'd2000 + {8'h00, ticks};
					ticks <= 0;
				end
				2: begin
					month <= 8'h0A * {4'h0, rtc_date_bcd_r[15:12]} + {4'h0, rtc_date_bcd_r[11:8]} - 8'h01;
				end
				3: begin
					day_of_month <= 8'h0A * {4'h0, rtc_date_bcd_r[7:4]} + {4'h0, rtc_date_bcd_r[3:0]};
				end
				4: begin
					day_of_week <= 8'h0A * {4'h0, rtc_time_bcd_r[31:28]} + {4'h0, rtc_time_bcd_r[27:24]};
				end
				5: begin
					hours <= 8'h0A * {4'h0, rtc_time_bcd_r[23:20]} + {4'h0, rtc_time_bcd_r[19:16]};
				end
				6: begin
					minutes <= 8'h0A * {4'h0, rtc_time_bcd_r[15:12]} + {4'h0, rtc_time_bcd_r[11:8]};
				end
				7: begin
					seconds <= 8'h0A * {4'h0, rtc_time_bcd_r[7:4]} + {4'h0, rtc_time_bcd_r[3:0]};
					has_set_time <= 1;
				end
				endcase
			end
			1: begin
				case (vsync & ~last_vsync)
				0: begin end
				1: begin
					// TODO: day of week and day of month
					ticks <= ticks == 59 ? 0 : ticks + 1;
					seconds <= ticks == 59 ? (seconds == 59 ? 0 : seconds + 1) : seconds;
					minutes <= seconds == 59 && ticks == 59 ? (minutes == 59 ? 0 : minutes + 1) : minutes;
					hours <= minutes == 59 && seconds == 59 && ticks == 59 ? (hours == 23 ? 0 : hours + 1) : hours;
				end
				endcase
			end
			endcase
		end
		endcase
	end
	
	always @ (posedge cpu_clock)
	begin
		case (is_booted)
		1: begin
			is_vsync <= vsync | is_vsync;
			is_mouse <= mouse_enable;
			pending_controller <= last_controller0 != controller0 ? 1 : pending_controller;
			is_draw_queue_ready_reg <= is_draw_queue_ready;
			did_copy_buffer_reg <= did_copy_buffer;
			case (is_wait) 
			1: begin
				phase <= 0;
				device_ram_write_enable <= 0;
				main_ram_addr <= pc;
				main_ram_write_enable <= 0;
				main_ram_write_value <= 0;
				
				stack_ram_write_enable_a <= 0;
				stack_ram_addr_a <= 0;
				stack_ram_write_value_a <= 0;
				stack_ram_write_enable_b <= 0;
				stack_ram_addr_b <= 0;
				stack_ram_write_value_b <= 0;
				
				queue_write_enable <= 0;
				queue_write_value <= 0;
				
				device_ram_write_enable <= 0;
				device_ram_addr <= 0;
				device_ram_write_value <= 0;
				
				is_ins_done <= 0;
				is_second_deo <= 0;
				is_second_dei <= 0;
				deo_phase <= 0;
				is_deo_done <= 0;
				is_dei_done <= 0;
				sp_offset_a <= 0;
				sp_offset_b <= 0;
				is_stack_index_flipped <= 0;
				t8 <= 0;
				n8 <= 0;
				l8 <= 0;
				x8 <= 0;
				y8 <= 0;
				z8 <= 0;
				case (is_vsync)
				1: begin
					vsync_phase <= vsync_phase + 1;
					case (vsync_phase)
					0: begin
						mouse_x <= (is_mouse & last_controller0[6]) ? mouse_x - 2 : (is_mouse & last_controller0[7] ? mouse_x + 2 : mouse_x);
						device_ram_addr <= 8'h20; // screen vector (hi)
					end
					1: begin
						mouse_y <= (is_mouse & last_controller0[4]) ? mouse_y - 2 : (is_mouse & last_controller0[5] ? mouse_y + 2 : mouse_y);
						device_ram_addr <= 8'h21; // screen vector (lo)
					end
					2: begin
						n8 <= device_ram_read_value;
						is_screen_vector_running <= device_ram_read_value == 0 ? 0 : is_draw_queue_ready_reg & did_copy_buffer_reg;
					end
					3: begin
						pc <= is_screen_vector_running ? {n8, device_ram_read_value} : pc;
						is_wait <= is_screen_vector_running ? 0 : is_wait;
						pending_controller <= is_mouse ? last_controller0[7:4] != 4'h0 : pending_controller;
						is_vsync <= 0;
					end
					endcase
				end
				0: begin
					case (pending_controller)
					0: begin end
					1: begin
						controller_phase <= controller_phase + 1;
						case (controller_phase)
						0: begin
							device_ram_addr <= is_mouse ? 8'h90 : 8'h80; // controller or mouse vector (hi)
						end
						1: begin
							device_ram_addr <= is_mouse ? 8'h91 : 8'h81; // controller or mouse vector (lo)
						end
						2: begin
							n8 <= device_ram_read_value;
						end
						3: begin
							pending_controller <= 0;
							last_controller0 <= controller0;
							pc <= n8 == 0 ? pc : {n8, device_ram_read_value};
							is_wait <= n8 == 0 ? is_wait : 0;
						end
						endcase
					end
					endcase
				end
				endcase
			end
			0: begin
				phase <= is_ins_done ? 0 : pc[15:8] == 0 ? 0 : (phase + 1);
				opc_phase <= opc_phase + 1;
				vsync_phase <= 0;
				controller_phase <= 0;
				main_ram_write_enable <= 0;
				main_ram_write_value <= 0;
				queue_write_enable <= 0;
				queue_write_value <= 0;
				device_ram_addr <= 0;
				device_ram_write_enable <= 0;
				device_ram_write_value <= 0;
				stack_ram_write_enable_a <= 0;
				stack_ram_write_enable_b <= 0;
				main_ram_addr <= pc;
				
				case (phase)
				0: begin
					is_ins_done <= 0;
					is_second_deo <= 0;
					is_second_dei <= 0;
					deo_phase <= 0;
					is_deo_done <= 0;
					is_dei_done <= 0;
					sp_offset_a <= 0;
					sp_offset_b <= 0;
					is_stack_index_flipped <= 0;
					t8 <= 0;
					n8 <= 0;
					l8 <= 0;
					x8 <= 0;
					y8 <= 0;
					z8 <= 0;
				end
				1: begin
					pc <= pc + 1;
				end
				2: begin
					opc <= main_ram_read_value & (main_ram_read_value[4:0] == 0 ? 8'hFF : 8'h3F);
					ins_7 <= main_ram_read_value[7];
					stack_index <= main_ram_read_value[6];
					opc_phase <= 0;
				end
				default: begin
					
					case (opc)
					8'h00: /* BRK   */ begin
						is_screen_vector_running <= 0;
						is_ins_done <= 1; 
						is_wait <= 1;
					end
					8'h01: /* INC   */ begin // t=T; SET(1, 0) T = t + 1;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 1 : 0, 0);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); 
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= t8 + 1;
						end
						endcase
					end
					8'h02: /* POP   */ begin // SET(1,-1)
						case (opc_phase)
						0: begin
							shift(ins_7 ? 0 : 1, ~ins_7);
							is_ins_done <= 1;
						end
						endcase
					end
					8'h03: /* NIP   */ begin // t=T; SET(2,-1) T = t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
							is_ins_done <= 1;
						end
						2: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= stack_ram_read_value_b;
						end
						endcase
					end
					8'h04: /* SWP   */ begin // t=T;n=N; SET(2, 0) T = n; N = t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 2 : 0, 0);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(t8, n8);
						end
						endcase
					end
					8'h05: /* ROT   */ begin // t=T;n=N;l=L;    SET(3, 0) T = l; N = t; L = n;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get L2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 3 : 0, 0); 
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							set_sp_offset(3); 
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8;
							is_ins_done <= 1;
						end
						4: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(t8, l8);
						end
						endcase
					end
					8'h06: /* DUP   */ begin // t=T; SET(1, 1) T = t; N = t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 2 : 1, 0);
							is_ins_done <= 1;
						end
						2: begin 
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(stack_ram_read_value_b, stack_ram_read_value_b);
						end
						endcase
					end
					8'h07: /* OVR   */ begin // t=T;n=N; SET(2, 1) T = n; N = t; L = n;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 3 : 1, 0);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin
							set_sp_offset(3); // set L
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8;
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(t8, n8);
						end
						endcase
					end
					8'h08: /* EQU   */ begin // t=T;n=N; SET(2,-1) T = n == t; 
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 == t8 ? 1 : 0;
						end
						endcase
					end
					8'h09: /* NEQ   */ begin //  t=T;n=N;  SET(2,-1) T = n != t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 == t8 ? 0 : 1;
						end
						endcase
					end
					8'h0A: /* GTH   */ begin // t=T;n=N; SET(2,-1) T = n > t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 > t8 ? 1 : 0;
						end
						endcase
					end
					8'h0B: /* LTH   */ begin // t=T;n=N; SET(2,-1) T = n < t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 < t8 ? 1 : 0;
						end
						endcase
					end
					8'h0C: /* JMP   */ begin // t=T; SET(1,-1) pc += (Sint8)t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 0 : 1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							pc <= (t8[7] ? (pc - 16'h0080 + {9'd0, t8[6:0]}) : (pc + {8'h00, t8}));
						end
						endcase
					end
					8'h0D: /* JCN   */ begin // t=T;n=N; SET(2,-2) if(n) pc += (Sint8)t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							pc <= n8 == 0 ? pc : (t8[7] ? pc - 16'h0080 + {9'd0, t8[6:0]} : pc + {8'h00, t8});
						end
						endcase
					end
					8'h0E: /* JSR   */ begin // t=T; SET(1,-1) FLIP SHIFT(2) T2_(pc) pc += (Sint8)t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							flip_shift(2);
						end
						3: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(pc[15:8], pc[7:0]);
							is_ins_done <= 1;
						end
						4: begin
							stack_ram_write_enable_a <= 0; 
							stack_ram_write_enable_b <= 0; 
							pc <= (t8[7] ? pc - 16'h0080 + {9'd0, t8[6:0]} : pc + {8'h00, t8});
						end
						endcase
					end
					8'h0F: /* STH   */ begin // t=T; SET(1,-1) FLIP SHIFT(1) T = t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							flip_shift(1);
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1);	// set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= t8;
						end
						endcase
					end
					8'h10: /* LDZ   */ begin //  t=T; SET(1, 0) T = ram[t]; 
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 1 : 0, 0);
						end
						2: begin 
							main_ram_addr <= {8'h00, stack_ram_read_value_b}; // peek RAM at address equal to T
						end
						3: begin
							is_ins_done <= 1;
						end
						4: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= main_ram_read_value;
						end
						endcase
					end
					8'h11: /* STZ   */ begin // t=T;n=N; SET(2,-2) ram[t] = n;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin 
							main_ram_write_enable <= 1; 
							main_ram_addr <= {8'h00, t8};
							main_ram_write_value <= n8;
						end
						endcase
					end
					8'h12: /* LDR   */ begin // t=T; SET(1, 0) T = ram[pc + (Sint8)t];
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 1 : 0, 0);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin
							main_ram_addr <= t8[7] ? pc - 16'h0080 + {9'd0, t8[6:0]} : pc + {8'h00, t8}; // peek RAM at address equal to  PC + T
						end
						4: begin
							is_ins_done <= 1;
						end
						5: begin 
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= main_ram_read_value;
						end
						endcase
					end
					8'h13: /* STR   */ begin // t=T;n=N; SET(2,-2) ram[pc + (Sint8)t] = n;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin 
							main_ram_write_enable <= 1; 
							main_ram_addr <= t8[7] ? pc - 16'h0080 + {9'd0, t8[6:0]} : pc + {8'h00, t8};
							main_ram_write_value <= n8;
						end
						endcase
					end
					8'h14: /* LDA   */ begin // t=T2;           SET(2,-1) T = ram[t];
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(1, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin 
							main_ram_addr <= {n8, t8};
						end
						4: begin
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offset(1);
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= main_ram_read_value;
						end
						endcase
					end
					8'h15: /* STA   */ begin // t=T2;n=L; SET(3,-3) ram[t] = n;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 0 : 3, ~ins_7);
							is_ins_done <= 1;
						end
						3: begin 
							main_ram_write_enable <= 1;
							main_ram_addr <= {n8, t8};
							main_ram_write_value <= stack_ram_read_value_b;
						end
						endcase
					end
					8'h16: /* DEI   */ begin // t=T; SET(1, 0) T = DEI(t);
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 1 : 0, 0);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						default: begin
							device_in(t8, opc_phase - 3);
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= is_dei_done; 
							stack_ram_write_value_a <= z8;
							is_ins_done <= is_dei_done;
						end
						endcase
					end
					8'h17: /* DEO   */ begin // t=T;n=N; SET(2,-2) DEO(t, n)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						default: begin
							device_out(t8, n8, opc_phase - 3);
							is_ins_done <= is_deo_done;
						end
						endcase
					end
					8'h18: /* ADD   */ begin //  t=T;n=N; SET(2,-1) T = n + t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 + t8;
						end
						endcase
					end
					8'h19: /* SUB   */ begin //  t=T;n=N; SET(2,-1) T = n - t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 - t8;
						end
						endcase
					end
					8'h1A: /* MUL   */ begin //  t=T;n=N; SET(2,-1) T = n * t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= n8 * t8;
						end
						endcase
					end
					8'h1B: /* DIV   */ begin //  t=T;n=N; SET(2,-1) T = t ? n / t : 0;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= t8 == 0 ? 0 : n8 / t8;
						end
						endcase
					end
					8'h1C: /* AND   */ begin //  t=T;n=N; SET(2,-1) T = n & t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
							is_ins_done <= 1;
						end
						2: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= stack_ram_read_value_a & stack_ram_read_value_b;
						end
						endcase
					end
					8'h1D: /* ORA   */ begin //  t=T;n=N; SET(2,-1) T = n | t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
							is_ins_done <= 1;
						end
						2: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= stack_ram_read_value_a | stack_ram_read_value_b;
						end
						endcase
					end
					8'h1E: /* EOR   */ begin //  t=T;n=N; SET(2,-1) T = n ^ t;
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
							is_ins_done <= 1;
						end
						2: begin
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= stack_ram_read_value_a ^ stack_ram_read_value_b;
						end
						endcase
					end
					8'h1F: /* SFT   */ begin // t=T;n=N; SET(2,-1) T = n >> (t & 0xf) << (t >> 4)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(1, ~ins_7);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin
							l8 <= (n8 >> (t8 & 8'h0F)) << (t8 >> 4);
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= l8;
						end
						endcase
					end
					8'h20: /* JCI   */ begin // t=T; SHIFT(-1) if(!t) { pc += 2; break; } else { rr = ram + pc; pc += PEEK2(rr) + 2; }
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
							main_ram_addr <= pc; // peek RAM at PC
						end
						1: begin
							shift(1, 1);
							main_ram_addr <= pc + 1; // peek RAM at PC + 1
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							l8 <= main_ram_read_value;
						end
						3: begin
							x8 <= main_ram_read_value;
							is_ins_done <= 1; 
						end
						4: begin 
							pc <= (t8 == 0 ? (pc + 2) : (pc + {l8, x8} + 2));
						end
						endcase
					end
					8'h21: /* INC2  */ begin //  t=T2; SET(2, 0) T2_(t + 1)
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 2 : 0, 0); 
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(t8 == 8'hFF ? n8 + 1 : n8, t8 + 1);
						end
						endcase
					end
					8'h22: /* POP2  */ begin // SET(2,-2)
						case (opc_phase)
						0: begin
							shift(ins_7 ? 0 : 2, ~ins_7);
							is_ins_done <= 1;
						end
						endcase
					end
					8'h23: /* NIP2  */ begin // t=T2; SET(4,-2) T2_(t)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(2, ~ins_7);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(n8, t8);
						end
						endcase
					end
					8'h24: /* SWP2  */ begin // t=T2;n=N2; SET(4, 0) T2_(n) N2_(t)
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 4 : 0, 0);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							set_sp_offsets_ab(4, 3); // set N2
							stack_write_ab(n8, t8);
							is_ins_done <= 1;
						end
						4: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8, l8);
						end
						endcase
					end
					8'h25: /* ROT2  */ begin // t=T2;n=N2;l=L2; SET(6, 0) T2_(l) N2_(t) L2_(n)
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							set_sp_offsets_ab(6, 5); // get L2
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							shift(ins_7 ? 6 : 0, 0);
						end
						4: begin
							z8 <= stack_ram_read_value_a;
							y8 <= stack_ram_read_value_b;
							set_sp_offsets_ab(4, 3); // set N2
							stack_write_ab(n8, t8);
						end
						5: begin
							set_sp_offsets_ab(6, 5); // set L2
							stack_write_ab(x8, l8);
							is_ins_done <= 1;
						end
						6: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
						end
						endcase
					end
					8'h26: /* DUP2  */ begin // t=T2;  SET(2, 2) T2_(t) N2_(t) break;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 4 : 2, 0);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin	
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(n8, t8);
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offsets_ab(4, 3); // set N2
							stack_write_ab(n8, t8);
						end
						endcase
					end
					8'h27: /* OVR2  */ begin // t=T2;n=N2; SET(4, 2) T2_(n) N2_(t) L2_(n) break;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 6 : 2, 0);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							set_sp_offsets_ab(4, 3); // set N2
							stack_write_ab(n8, t8);
						end
						4: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8, l8);
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offsets_ab(6, 5); // set L2
							stack_write_ab(x8, l8);
						end
						endcase
					end
					8'h28: /* EQU2  */ begin 	//  t=T2;n=N2; SET(4,-3) T = n == t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 1 : 3, ~ins_7);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offset(1);
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= ({x8, l8} == {n8, t8}) ? 1 : 0;
						end
						endcase
					end
					8'h29: /* NEQ2  */ begin 	//  t=T2;n=N2; SET(4,-3) T = n == t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 1 : 3, ~ins_7);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offset(1);
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= ({x8, l8} == {n8, t8}) ? 0 : 1;
						end
						endcase
					end
					8'h2A: /* GTH2  */ begin // t=T2;n=N2;      SET(4,-3) T = n > t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 1 : 3, ~ins_7);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offset(1);
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= ({x8, l8} > {n8, t8}) ? 1 : 0;
						end
						endcase
					end
					8'h2B: /* LTH2  */ begin // t=T2;n=N2;      SET(4,-3) T = n < t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 1 : 3, ~ins_7);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin 
							set_sp_offset(1);
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= ({x8, l8} < {n8, t8}) ? 1 : 0;
						end
						endcase
					end
					8'h2C: /* JMP2  */ begin // t=T2; SET(2,-2) pc = t
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						3: begin 
							pc <= {n8, t8};
						end
						endcase
					end
					8'h2D: /* JCN2  */ begin // t=T2;n=L; SET(3,-3) if(n) pc = t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 0 : 3, ~ins_7);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin 
							pc <= l8 == 0 ? pc : {n8, t8};
						end
						endcase
					end
					8'h2E: /* JSR2  */ begin // t=T2; SET(2,-2) FLIP SHIFT(2) T2_(pc) pc = t;
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							flip_shift(2);
							is_ins_done <= 1;
						end
						3: begin 
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(pc[15:8], pc[7:0]);
							pc <= {n8, t8};
						end
						endcase
					end
					8'h2F: /* STH2  */ begin // t=T2; SET(2,-2) FLIP SHIFT(2) T2_(t)
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 0 : 2, ~ins_7);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							flip_shift(2);
							is_ins_done <= 1;
						end
						3: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(n8, t8);
						end
						endcase
					end
					8'h30: /* LDZ2  */ begin //  t=T; SET(1, 1) rr = ram + t; T2_(PEEK2(rr))
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 2 : 1, 0);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin
							main_ram_addr <= {8'h00, t8};
						end
						4: begin 
							main_ram_addr <= {8'h00, t8 + 8'h01};
						end
						5: begin 
							x8 <= main_ram_read_value;
							is_ins_done <= 1;
						end
						6: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8, main_ram_read_value);
						end
						endcase
					end
					8'h31: /* STZ2  */ begin // t=T;n=H2; SET(3,-3) rr = ram + t; POKE2(rr, n)
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 0 : 3, ~ins_7);
						end
						3: begin 
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							main_ram_write_enable <= 1; 
							main_ram_addr <= {8'h00, t8 + 8'h01};
							main_ram_write_value <= n8;
							is_ins_done <= 1;
						end
						4: begin
							main_ram_write_enable <= 1; 
							main_ram_addr <= {8'h00, t8};
							main_ram_write_value <= l8;
						end
						endcase
					end
					8'h32: /* LDR2  */ begin // t=T; SET(1, 1) rr = ram + pc + (Sint8)t; T2_(PEEK2(rr))
						case (opc_phase)
						0: begin 
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin 
							shift(ins_7 ? 2 : 1, 0);
						end
						2: begin 
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin
							main_ram_addr <= t8[7] ? pc - 16'h0080 + {9'd0, t8[6:0]} : pc + {8'h00, t8}; // peek RAM (byte 1 of 2) at address equal to PC + T 
						end
						4: begin 
							main_ram_addr <= main_ram_addr + 1;
						end
						5: begin 
							x8 <= main_ram_read_value;
							is_ins_done <= 1;
						end
						6: begin 
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8, main_ram_read_value);
						end
						endcase
					end
					8'h33: /* STR2  */ begin // t=T;n=H2; SET(3,-3) rr = ram + pc + (Sint8)t; POKE2(rr, n)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 0 : 3, ~ins_7);
						end
						3: begin
							main_ram_write_enable <= 1; 
							main_ram_addr <= t8[7] ? pc - 16'h0080 + {9'd0, t8[6:0]} : pc + {8'h00, t8};
							main_ram_write_value <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin
							main_ram_write_enable <= 1; 
							main_ram_addr <= main_ram_addr + 1;
							main_ram_write_value <= n8;
						end
						endcase
					end
					8'h34: /* LDA2  */ begin  // t=T2;           SET(2, 0) rr = ram + t; T2_(PEEK2(rr))
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 2 : 0, 0);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						3: begin
							main_ram_addr <= {n8, t8}; // peek RAM at T2
						end
						4: begin 
							main_ram_addr <= main_ram_addr + 1; // peek RAM at T2 + 1
						end
						5: begin 
							n8 <= main_ram_read_value;
							is_ins_done <= 1;
						end
						6: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(n8, main_ram_read_value);
						end
						endcase
					end
					8'h35: /* STA2  */ begin // t=T2;n=N2; SET(4,-4) rr = ram + t; POKE2(rr, n)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 0 : 4, ~ins_7);
						end
						3: begin
							l8 <= stack_ram_read_value_b;
							main_ram_write_enable <= 1;
							main_ram_addr <= {n8, t8};
							main_ram_write_value <= stack_ram_read_value_a; // set high byte of n16 to ram address t16
							is_ins_done <= 1; 
						end
						4: begin
							main_ram_write_enable <= 1;
							main_ram_addr <= main_ram_addr + 1;
							main_ram_write_value <= l8; // set low byte of n16 to ram address t16 
						end
						endcase
					end
					8'h36: /* DEI2  */ begin  // t=T; SET(1, 1) T = DEI(t + 1); N = DEI(t);
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							shift(ins_7 ? 2 : 1, 0);
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
						end
						default: begin
							device_in(is_second_dei ? t8 : t8 + 1, deo_phase);
							deo_phase <= is_dei_done & ~is_second_dei ? 0 : deo_phase + 1;
							stack_ram_write_enable_a <= is_dei_done; 
							set_sp_offset(is_second_dei ? 2 : 1); // set T
							stack_ram_write_value_a <= z8;
							is_ins_done <= deo_phase == 0 ? 0 : is_dei_done & is_second_dei;
							is_second_dei <= is_second_dei | is_dei_done;
						end
						endcase
					end
					8'h37: /* DEO2  */ begin // t=T;n=N;l=L; SET(3,-3) DEO(t, l) DEO((t + 1), n)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 0 : 3, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
						end
						default: begin
							device_out(is_second_deo ? t8 + 1 : t8, is_second_deo ? n8 : l8, deo_phase);
							deo_phase <= is_deo_done & ~is_second_deo ? 0 : deo_phase + 1;
							is_ins_done <= deo_phase == 0 ? 0 : is_deo_done & is_second_deo;
							is_second_deo <= is_second_deo | is_deo_done;
						end
						endcase
					end
					8'h38: /* ADD2  */ begin //  t=T2;n=N2; SET(4,-2) T2_(n + t) 
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
						end
						4: begin
							{z8, y8} <= {x8, l8} + {n8, t8};
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
						end
						endcase
					end
					8'h39: /* SUB2  */ begin //  t=T2;n=N2; SET(4,-2) T2_(n - t) 
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
						end
						4: begin
							{z8, y8} <= {x8, l8} - {n8, t8};
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
						end
						endcase
					end
					8'h3A: /* MUL2  */ begin // t=T2;n=N2; SET(4,-2) T2_(n * t)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
						end
						4: begin
							{z8, y8} <= {x8, l8} * {n8, t8};
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
						end
						endcase
					end
					8'h3B: /* DIV2  */ begin // t=T2;n=N2; SET(4,-2) T2_(t ? n / t : 0)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
						end
						4: begin
							{z8, y8} <= {n8, t8} == 0 ? 0 : {x8, l8} / {n8, t8};
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
						end
						endcase
					end
					8'h3C: /* AND2  */ begin //  t=T2;n=N2; SET(4,-2) T2_(n & t)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8 & n8, l8 & t8);
						end
						endcase
					end
					8'h3D: /* ORA2  */ begin //  t=T2;n=N2; SET(4,-2) T2_(n | t)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8 | n8, l8 | t8);
						end
						endcase
					end
					8'h3E: /* EOR2  */ begin //  t=T2;n=N2; SET(4,-2) T2_(n ^ t)
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(2, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
							is_ins_done <= 1;
						end
						4: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(x8 ^ n8, l8 ^ t8);
						end
						endcase
					end
					8'h3F: /* SFT2  */ begin // t=T;n=H2; SET(3,-1) T2_(n >> (t & 0xf) << (t >> 4))
						case (opc_phase)
						0: begin
							set_sp_offsets_ab(2, 1); // get T2
						end
						1: begin
							set_sp_offsets_ab(4, 3); // get N2
						end
						2: begin
							n8 <= stack_ram_read_value_a;
							t8 <= stack_ram_read_value_b;
							shift(ins_7 ? 2 : 1, ~ins_7);
						end
						3: begin
							x8 <= stack_ram_read_value_a;
							l8 <= stack_ram_read_value_b;
						end
						4: begin 
							{z8, y8} <= ({l8, n8} >> (t8 & 8'h0F)) << (t8 >> 4);
							is_ins_done <= 1;
						end
						5: begin
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
						end
						endcase
					end
					8'h40: /* JMI   */ begin // rr = ram + pc; pc += PEEK2(rr) + 2;
						case (opc_phase)
						0: begin 
							main_ram_addr <= pc; // peek RAM at PC
						end
						1: begin 
							main_ram_addr <= main_ram_addr + 1; // peek RAM at PC + 1
						end
						2: begin 
							n8 <= main_ram_read_value;
						end
						3: begin
							t8 <= main_ram_read_value;
							is_ins_done <= 1; 
						end
						4: begin
							pc <= pc + {n8, t8} + 2;
						end
						endcase
					end
					8'h60: /* JSI   */ begin // SHIFT( 2) T2_(pc + 2); rr = ram + pc; pc += PEEK2(rr) + 2;
						case (opc_phase)
						0: begin 
							{z8, y8} <= pc + 2;
							shift(2, 0);
							main_ram_addr <= pc; // peek RAM at PC
						end
						1: begin 
							set_sp_offsets_ab(2, 1); // set T2
							stack_write_ab(z8, y8);
							main_ram_addr <= main_ram_addr + 1; // peek RAM at PC + 1
						end
						2: begin 
							n8 <= main_ram_read_value;
							stack_ram_write_enable_a <= 0;
							stack_ram_write_enable_b <= 0; 
						end
						3: begin 
							t8 <= main_ram_read_value;
							is_ins_done <= 1; 
						end
						4: begin
							pc <= {z8, y8} + {n8, t8};
						end
						endcase
					end
					8'h80, 8'hC0: /* LIT, LITr */ begin  // SHIFT( 1) T = ram[pc++];
						case (opc_phase)
						0: begin 
							main_ram_addr <= pc;
						end
						1: begin
							shift(1, 0);
							is_ins_done <= 1; 
						end
						2: begin 
							set_sp_offset(1); // set T
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= main_ram_read_value;
							pc <= pc + 1;
						end
						endcase
					end
					8'hA0, 8'hE0: /* LIT2, LIT2r  */ begin // SHIFT( 2) rr = ram + pc; T2_(PEEK2(rr)) pc += 2;	
						case (opc_phase)
						0: begin
							shift(2, 0);
							main_ram_addr <= pc;
						end
						1: begin
							main_ram_addr <= main_ram_addr + 1; 
						end
						2: begin
							set_sp_offset(2); // set T2 (High byte)
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= main_ram_read_value;
							is_ins_done <= 1; 
						end
						3: begin
							set_sp_offset(1); // set T2 (Low byte)
							stack_ram_write_enable_a <= 1; 
							stack_ram_write_value_a <= main_ram_read_value;
							pc <= pc + 2;
						end
						endcase
					end
					default: begin
						is_ins_done <= 1; 
					end
					endcase
				end
				endcase
			end
			endcase
		end
		0: begin // booting
			queue_write_enable <= 0;
			queue_write_value <= 0;
			device_ram_addr <= 0;
		
			is_screen_vector_running <= 0;
			stack_ram_write_enable_a <= 1;
			stack_ram_write_enable_b <= 0;
			stack_ram_addr_a <= boot_phase[8:0];
			stack_ram_addr_b <= 0;
			stack_ram_write_value_a <= 0;
			stack_ram_addr_b <= 0;
			
			device_ram_write_enable <= 1;
			device_ram_addr <= boot_phase[7:0];
			device_ram_write_value <= 0;
			
			main_ram_write_enable <= boot_valid_byte & ~boot_ram_full;
			main_ram_addr <= boot_read_address + 16'h0100;
			main_ram_write_value <= boot_read_value;
			
			boot_timeout <= boot_phase == 24'hFFFFFF;
			boot_ram_full <= boot_ram_full | boot_read_address == 16'hFF00;
			boot_phase <= boot_valid_byte ? 0 : boot_phase + 1;
			is_booted <= has_set_time & (boot_timeout | boot_ram_full);
		end
		endcase
	end
	
	task stack_write_a(input [7:0] a);
		stack_ram_write_enable_a <= 1; 
		stack_ram_write_enable_b <= 0; 
		stack_ram_write_value_a <= a;
	endtask
	
	task stack_write_ab(input [7:0] a, input [7:0] b);
		stack_ram_write_enable_a <= 1; 
		stack_ram_write_enable_b <= 1; 
		stack_ram_write_value_a <= a;
		stack_ram_write_value_b <= b;
	endtask
	
	task update_stack(input [7:0] offset_a, input [7:0] offset_b, input index, input flip, input [7:0]s0, input [7:0]s1);
		stack_ram_addr_a <= {index ^ flip, ((index ^ flip) ? s1 : s0) - offset_a};
		stack_ram_addr_b <= {index ^ flip, ((index ^ flip) ? s1 : s0) - offset_b};
	endtask
	
	task set_sp_offset(input [7:0] offset);
		sp_offset_a <= offset;
		update_stack(offset, sp_offset_b, stack_index, is_stack_index_flipped, sp0, sp1);
	endtask
	
	task set_sp_offsets_ab(input [7:0] offset_a, input [7:0] offset_b);
		sp_offset_a <= offset_a;
		sp_offset_b <= offset_b;
		update_stack(offset_a, offset_b, stack_index, is_stack_index_flipped, sp0, sp1);
	endtask
	
	task flip_shift(input [7:0]amount);
		is_stack_index_flipped <= 1;
		case (stack_index)
		0: begin
			sp1 <= sp1 + amount;
		end
		1: begin
			sp0 <= sp0 + amount;
		end
		endcase
		update_stack(
		sp_offset_a, 
		sp_offset_b, 
		stack_index, 
		1, 
		stack_index ? sp0 + amount : sp0, 
		stack_index ? sp1 : sp1 + amount
		);
	endtask
	
	task shift(input [7:0]amount, input is_negative);
		if (stack_index ^ is_stack_index_flipped) begin
			sp1 <= is_negative ? sp1 - amount : sp1 + amount;
		end else begin
			sp0 <= is_negative ? sp0 - amount : sp0 + amount;
		end
		update_stack(
		sp_offset_a, 
		sp_offset_b, 
		stack_index, 
		is_stack_index_flipped, 
		(stack_index ^ is_stack_index_flipped) ? sp0 : (is_negative ? sp0 - amount : sp0 + amount), 
		(stack_index ^ is_stack_index_flipped) ? (is_negative ? sp1 - amount : sp1 + amount) : sp1);
	endtask
	
	task system_dei(input [7:0] addr, input [7:0] d_phase);
		case (addr[3:0])
		4: begin
			z8 <= sp0;
			is_dei_done <= 1;
		end
		5: begin
			z8 <= sp1;
			is_dei_done <= 1;
		end
		default: begin
			generic_dei(addr, d_phase);
		end
		endcase
	endtask
	
	task datetime_dei(input [3:0] addr);
		case (addr)
		0: begin // year (hi)
			z8 <= year[15:8];
			is_dei_done <= 1;
		end
		1: begin //year (lo)
			z8 <= year[7:0];
			is_dei_done <= 1;
		end
		2: begin // month, 0 - 11
			z8 <= month;
			is_dei_done <= 1;
		end
		3: begin // day of month, 1 - 31
			z8 <= day_of_month;
			is_dei_done <= 1;
		end
		4: begin // hour, 0 - 23
			z8 <= hours;
			is_dei_done <= 1;
		end
		5: begin // minute, 0 - 59
			z8 <= minutes;
			is_dei_done <= 1;
		end
		6: begin // second, 0 - 59
			z8 <= seconds;
			is_dei_done <= 1;
		end
		7: begin // day of week, 0 - 6, beginning Sunday
			z8 <= day_of_week;
			is_dei_done <= 1;
		end
		default: begin
			z8 <= 0;
			is_dei_done <= 1;
		end
		endcase
	endtask
	
	task controller_dei(input [7:0] addr, input [7:0] d_phase);
		case (addr[3:0])
		2: begin
			z8 <= last_controller0;
			is_dei_done <= 1;
		end
		default: begin
			generic_dei(addr, d_phase);
		end
		endcase
	endtask
	
	task mouse_dei(input [7:0] addr, input [7:0] d_phase);
		case (addr[3:0])
		2: begin
			z8 <= {7'd0, mouse_x[8]}; 	// mouse x (hi)
			is_dei_done <= 1;
		end
		3: begin
			z8 <= mouse_x[7:0]; 		// mouse x (lo)
			is_dei_done <= 1;
		end
		4: begin
			z8 <= {7'd0, mouse_y[8]}; 	// mouse y (hi)
			is_dei_done <= 1;
		end
		5: begin
			z8 <= mouse_y[7:0]; 		// mouse y (lo)
			is_dei_done <= 1;
		end
		6: begin
			z8 <= {6'd0, last_controller0[1:0]}; // mouse button state
			is_dei_done <= 1;
		end
		default: begin
			generic_dei(addr, d_phase);
		end
		endcase
	endtask
	
	task screen_dei(input [7:0] addr, input [7:0] d_phase);
		case (addr[3:0])
		2: begin
			z8 <= 8'h01; // screen width (hi)
			is_dei_done <= 1;
		end
		3: begin
			z8 <= 8'h40; // screen width (lo)
			is_dei_done <= 1;
		end
		4: begin 
			z8 <= 8'h01; // screen height (hi)
			is_dei_done <= 1;
		end
		5: begin 
			z8 <= 8'h20; // screen height (lo)
			is_dei_done <= 1;
		end
		default: begin
			generic_dei(addr, d_phase);
		end
		endcase
	endtask
	
	task generic_dei(input [7:0] addr, input [7:0] d_phase);
		case (d_phase)
		0, 1: begin
			device_ram_write_enable <= 0;
			device_ram_addr <= addr;
			is_dei_done <= 0;
		end
		2: begin
			z8 <= device_ram_read_value;
			is_dei_done <= 1;
		end
		endcase
	endtask
	
	task device_in(input [7:0] addr, input [7:0] d_phase);
		case (addr[7:4])
		4'h0: begin
			system_dei(addr, d_phase);
		end
		4'h2: begin // screen
			screen_dei(addr, d_phase);
		end
		4'h8: begin // controller
			controller_dei(addr, d_phase);
		end
		4'h9: begin // mouse
			mouse_dei(addr, d_phase);
		end
		4'hC: begin // datetime
			datetime_dei(addr[3:0]);
		end
		default: begin
			generic_dei(addr, d_phase);
		end
		endcase
	endtask
	
	task device_out(input [7:0] addr, input [7:0] value, input [7:0] d_phase);
		case (d_phase)
		0: begin
			queue_write_enable <= 0;
			device_ram_write_enable <= 1;
			device_ram_addr <= addr;
			device_ram_write_value <= value;
			is_deo_done <= 0;
		end
		default: begin
			case (addr[7:4])
			4'h2: begin // screen
				screen_deo(addr[3:0], value, d_phase - 1);
			end
			default: begin
				queue_write_enable <= 0;
				device_ram_write_enable <= 0;
				is_deo_done <= 1;
			end
			endcase
		end
		endcase
	endtask
	
	task screen_deo(input [3:0] port, input [7:0] value, input [7:0] screen_phase);
		case (port)
		4'hE: begin // pixel port
			pixel_deo(value, screen_phase);
		end
		4'hF: begin
			sprite_deo(value, screen_phase);
		end
		default: begin
			queue_write_enable <= 0;
			device_ram_write_enable <= 0;
			is_deo_done <= 1;
		end
		endcase
	endtask
	
	task sprite_deo(input [7:0] value, input [7:0] screen_phase);
		spr_mode <= value[7];
		spr_layer <= value[6];
		spr_flip_y <= value[5];
		spr_flip_x <= value[4];
		spr_color <= value[3:0];
		case (screen_phase)
		0: begin 
			screen_auto_length <= 0;
			is_auto_x <= 0;
			is_auto_y <= 0;
			is_last_blit <= 0;
			spr_x <= 0;
			spr_y <= 0;
			is_auto_addr <= 0;
			device_ram_addr <= 0;
			queue_write_enable <= 0;
			device_ram_write_enable <= 0;
			device_ram_addr <= 8'h28; // x (hi)
		end
		1: begin
			device_ram_write_enable <= 0;
			device_ram_addr <= 8'h29; // x (lo)
		end
		2: begin
			x[15:8] <= device_ram_read_value;
			device_ram_write_enable <= 0;
			device_ram_addr <= 8'h2A; // y (hi)
		end
		3: begin
			x[7:0] <= device_ram_read_value;
			device_ram_write_enable <= 0;
			device_ram_addr <= 8'h2B; // y (lo)
		end
		4: begin
			y[15:8] <= device_ram_read_value;
			device_ram_addr <= 8'h2C; // ram_addr (hi)
		end
		5: begin
			is_x_in_bounds <= spr_flip_x ? x < 16'd327 : x < 16'd320;
			y[7:0] <= device_ram_read_value;
			device_ram_addr <= 8'h2D; // ram_addr (lo)
		end
		6: begin
			is_y_in_bounds <= spr_flip_y ? y < 16'd295 : y < 16'd288;
			screen_ram_addr[15:8] <= device_ram_read_value;
			device_ram_addr <= 8'h26; // auto
		end
		7: begin
			spr_x <= x;
			spr_y <= y;
			screen_ram_addr[7:0] <= device_ram_read_value;
		end
		8: begin
			screen_auto_length <= device_ram_read_value[7:4]; // rML
			is_auto_addr <= device_ram_read_value[2]; // rMA
			is_auto_y <= device_ram_read_value[1]; // rMY
			is_auto_x <= device_ram_read_value[0]; // rMX 
			is_last_blit <= 0;
			inner_sprite_phase <= 3'd0;
		end
		default: begin
			inner_sprite_phase <= inner_sprite_phase + 1;
			case (inner_sprite_phase)
			0: begin
				device_ram_write_enable <= 0;
				queue_write_enable <= 0;
				is_last_blit <= screen_auto_length == 0 ? 1 : 0;
			end
			1: begin
				// vccftlxx xxxxxxxy yyyyyyyy
				screen_auto_length <= screen_auto_length - 1;
				queue_write_enable <= is_x_in_bounds & is_y_in_bounds;
				queue_write_value <= {spr_layer, spr_color[1:0], 1'b0, 1'b1, spr_mode, spr_x[8:0], spr_y[8:0]};
				x <= (is_auto_x & is_last_blit) ? (spr_flip_x ? x - 8 : x + 8) : x;
			end
			2: begin
				y <= (is_auto_y & is_last_blit) ? (spr_flip_y ? y - 8 : y + 8) : y;
				// yxllllcc aaaaaaaa aaaaaaaa
				queue_write_enable <= is_x_in_bounds & is_y_in_bounds;
				queue_write_value <= {4'd0, spr_flip_y, spr_flip_x, spr_color[3:2], screen_ram_addr};
				device_ram_write_enable <= 1;
				device_ram_addr <= 8'h28; // x (hi)
				device_ram_write_value <= x[15:8];
			end
			3: begin
				screen_ram_addr <= is_auto_addr ? (spr_mode ? screen_ram_addr + 16 : screen_ram_addr + 8) : screen_ram_addr;
				queue_write_enable <= 0;
				device_ram_write_enable <= 1;
				device_ram_addr <= 8'h29; // x (lo)
				device_ram_write_value <= x[7:0];
			end
			4: begin
				spr_x <= is_auto_y ? (spr_flip_x ? spr_x - 8 : spr_x + 8) : spr_x;
				device_ram_write_enable <= 1;
				device_ram_addr <= 8'h2A; // y (hi)
				device_ram_write_value <= y[15:8];
			end
			5: begin
				spr_y <= is_auto_x ? (spr_flip_y ? spr_y - 8 : spr_y + 8) : spr_y;
				device_ram_write_enable <= 1;
				device_ram_addr <= 8'h2B; // y (lo)
				device_ram_write_value <= y[7:0];
			end
			6: begin
				is_x_in_bounds <= spr_flip_x ? spr_x < 16'd327 : spr_x < 16'd320;
				device_ram_write_enable <= 1;
				device_ram_addr <= 8'h2C; // ram_addr (hi)
				device_ram_write_value <= screen_ram_addr[15:8];
				is_deo_done <= is_last_blit;
			end
			7: begin
				is_y_in_bounds <= spr_flip_y ? spr_y < 16'd295 : spr_y < 16'd288;
				device_ram_write_enable <= 1;
				device_ram_addr <= 8'h2D; // ram_addr (lo)
				device_ram_write_value <= screen_ram_addr[7:0];
			end
			endcase
		end
		endcase
	endtask
	
	task pixel_deo(input [7:0] value, input [7:0] screen_phase);
		px_mode <= value[7];
		px_layer <= value[6];
		px_flip_y <= value[5];
		px_flip_x <= value[4];
		px_color <= value[1:0];
		case (screen_phase)
		0: begin 
			is_auto_px_x <= 0;
			is_auto_px_y <= 0;
			pxl_x <= 0;
			pxl_y <= 0;
			queue_write_enable <= 0;
			device_ram_write_enable <= 0;
			device_ram_addr <= 8'h28; // x (hi)
		end
		1: begin
			device_ram_addr <= 8'h29; // x (lo)
		end
		2: begin
			pxl_x[8] <= device_ram_read_value[0];
			device_ram_addr <= 8'h2A; // y (hi)
		end
		3: begin
			pxl_x[7:0] <= device_ram_read_value;
			device_ram_addr <= 8'h2B; // y (lo)
		end
		4: begin
			pxl_y[8] <= device_ram_read_value[0];
			is_x_in_bounds <= (px_mode & px_flip_x) | pxl_x < 9'd320;
			device_ram_addr <= 8'h26; // auto
		end
		5: begin
			pxl_y[7:0] <= device_ram_read_value;
		end
		6: begin
			is_auto_px_x <= device_ram_read_value[0];
			is_auto_px_y <= device_ram_read_value[1];
			is_y_in_bounds <= (px_mode & px_flip_y) | pxl_y < 9'd288;
		end
		7: begin
			queue_write_enable <= is_x_in_bounds & is_y_in_bounds;
			queue_write_value <= {px_layer, px_color, px_mode, px_mode & px_flip_y, px_mode & px_flip_x, pxl_x, pxl_y};
			device_ram_write_enable <= 1;
			device_ram_write_value <= {7'd0, pxl_x[8]} + (pxl_x[7:0] == 8'hFF ? {7'd0, is_auto_px_x} : 0);
			device_ram_addr <= 8'h28; // x (hi)
		end
		8: begin
			queue_write_enable <= 0;
			device_ram_write_enable <= 1;
			device_ram_addr <= 8'h29; // x (lo)
			device_ram_write_value <= pxl_x[7:0] + {7'd0, is_auto_px_x};
		end
		9: begin
			device_ram_write_enable <= 1;
			device_ram_write_value <= {7'd0, pxl_y[8]} + (pxl_y[7:0] == 8'hFF ? {7'd0, is_auto_px_y} : 0);
			device_ram_addr <= 8'h2A; // y (hi)
			is_deo_done <= 1;
		end
		10: begin
			device_ram_write_enable <= 1;
			device_ram_addr <= 8'h2B; // y (lo)
			device_ram_write_value <= pxl_y[7:0] + {7'd0, is_auto_px_y};
		end
		endcase
	endtask

endmodule
