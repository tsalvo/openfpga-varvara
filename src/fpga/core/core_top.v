//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3 = 8'hzz;
assign cart_tran_bank3_dir = 1'b0;
assign cart_tran_bank2 = 8'hzz;
assign cart_tran_bank2_dir = 1'b0;
assign cart_tran_bank1 = 8'hzz;
assign cart_tran_bank1_dir = 1'b0;
assign cart_tran_bank0 = 4'hf;
assign cart_tran_bank0_dir = 1'b1;
assign cart_tran_pin30 = 1'b0;      // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31 = 1'bz;      // input
assign cart_tran_pin31_dir = 1'b0;  // input

// link port is unused, set to input only to be safe
// each bit may be bidirectional in some applications
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

assign dram_a = 'h0;
assign dram_ba = 'h0;
assign dram_dq = {16{1'bZ}};
assign dram_dqm = 'h0;
assign dram_clk = 'h0;
assign dram_cke = 'h0;
assign dram_ras_n = 'h1;
assign dram_cas_n = 'h1;
assign dram_we_n = 'h1;

assign sram_a = 'h0;
assign sram_dq = {16{1'bZ}};
assign sram_oe_n  = 1;
assign sram_we_n  = 1;
assign sram_ub_n  = 1;
assign sram_lb_n  = 1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;


// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'h10xxxxxx: begin
        // example
        // bridge_rd_data <= example_device_data;
        bridge_rd_data <= 0;
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked_s; 
    wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;
    
    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;
    
    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

    reg             target_dataslot_read;       
    reg             target_dataslot_write;
    reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped
    
    wire            target_dataslot_ack;        
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;
    
    wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands
    
// bridge data slot access
// synchronous to clk_74a

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

core_bridge_cmd icb (

    .clk                ( clk_74a ),
    .reset_n            ( reset_n ),

    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_rd              ( bridge_rd ),
    .bridge_rd_data         ( cmd_bridge_rd_data ),
    .bridge_wr              ( bridge_wr ),
    .bridge_wr_data         ( bridge_wr_data ),
    
    .status_boot_done       ( status_boot_done ),
    .status_setup_done      ( status_setup_done ),
    .status_running         ( status_running ),

    .dataslot_requestread       ( dataslot_requestread ),
    .dataslot_requestread_id    ( dataslot_requestread_id ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok ),

    .dataslot_requestwrite      ( dataslot_requestwrite ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
    .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

    .dataslot_update            ( dataslot_update ),
    .dataslot_update_id         ( dataslot_update_id ),
    .dataslot_update_size       ( dataslot_update_size ),
    
    .dataslot_allcomplete   ( dataslot_allcomplete ),

    .rtc_epoch_seconds      ( rtc_epoch_seconds ),
    .rtc_date_bcd           ( rtc_date_bcd ),
    .rtc_time_bcd           ( rtc_time_bcd ),
    .rtc_valid              ( rtc_valid ),
    
    .savestate_supported    ( savestate_supported ),
    .savestate_addr         ( savestate_addr ),
    .savestate_size         ( savestate_size ),
    .savestate_maxloadsize  ( savestate_maxloadsize ),

    .savestate_start        ( savestate_start ),
    .savestate_start_ack    ( savestate_start_ack ),
    .savestate_start_busy   ( savestate_start_busy ),
    .savestate_start_ok     ( savestate_start_ok ),
    .savestate_start_err    ( savestate_start_err ),

    .savestate_load         ( savestate_load ),
    .savestate_load_ack     ( savestate_load_ack ),
    .savestate_load_busy    ( savestate_load_busy ),
    .savestate_load_ok      ( savestate_load_ok ),
    .savestate_load_err     ( savestate_load_err ),

    .osnotify_inmenu        ( osnotify_inmenu ),
    
    .target_dataslot_read       ( target_dataslot_read ),
    .target_dataslot_write      ( target_dataslot_write ),
    .target_dataslot_getfile    ( target_dataslot_getfile ),
    .target_dataslot_openfile   ( target_dataslot_openfile ),
    
    .target_dataslot_ack        ( target_dataslot_ack ),
    .target_dataslot_done       ( target_dataslot_done ),
    .target_dataslot_err        ( target_dataslot_err ),

    .target_dataslot_id         ( target_dataslot_id ),
    .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
    .target_dataslot_length     ( target_dataslot_length ),

    .target_buffer_param_struct ( target_buffer_param_struct ),
    .target_buffer_resp_struct  ( target_buffer_resp_struct ),
    
    .datatable_addr         ( datatable_addr ),
    .datatable_wren         ( datatable_wren ),
    .datatable_data         ( datatable_data ),
    .datatable_q            ( datatable_q )

);

////////////////////////////////////////////////////////////////////////////////////////
//
// video generation
// ~12,384,000 hz pixel clock
//
// we want our video mode of 320x288 @ 60hz, this results in 206400 clocks per frame
// we need to add hblank and vblank times to this, so there will be a nondisplay area. 
// it can be thought of as a border around the visible area.

assign video_rgb_clock = clk_core_pixel;
assign video_rgb_clock_90 = clk_core_pixel_90deg;
assign video_rgb = vidout_rgb;
assign video_de = vidout_de;
assign video_skip = vidout_skip;
assign video_vs = vidout_vs;
assign video_hs = vidout_hs;

    localparam  VID_V_BPORCH = 'd10;
    localparam  VID_V_ACTIVE = 'd288;
    localparam  VID_V_TOTAL = 'd600;
    localparam  VID_H_BPORCH = 'd10;
    localparam  VID_H_ACTIVE = 'd320;
    localparam  VID_H_TOTAL = 'd344;

    reg [9:0]   x_count;
    reg [9:0]   y_count;
    
    wire [9:0]  visible_x = x_count - VID_H_BPORCH;
    wire [9:0]  visible_y = y_count - VID_V_BPORCH;
    
    reg [7:0]  pxl_device_ram_read_addr;
    reg [16:0] vram_read_addr;
    
    reg has_set_palette = 0;
    reg [11:0] color_0 = 0;
    reg [11:0] color_1 = 0;
    reg [11:0] color_2 = 0;
    reg [11:0] color_3 = 0;

    reg [23:0]  vidout_rgb;
    reg         vidout_de, vidout_de_1;
    reg         vidout_skip;
    reg         vidout_vs;
    reg         vidout_hs, vidout_hs_1;

always @(posedge clk_core_pixel or negedge reset_n) begin

    if(~reset_n) begin
    
        x_count <= 0;
        y_count <= 0;
        
    end else begin
        vidout_de <= 0;
        vidout_skip <= 0;
        vidout_vs <= 0;
        vidout_hs <= 0;
        
        vidout_hs_1 <= vidout_hs;
        vidout_de_1 <= vidout_de;
        // x and y counters
        x_count <= x_count + 1'b1;
        if(x_count == VID_H_TOTAL-1) begin
            x_count <= 0;
            
            y_count <= y_count + 1'b1;
            if(y_count == VID_V_TOTAL-1) begin
                y_count <= 0;
            end
        end
        
        if (y_count == 0) begin // generate vsync and read palette colors on line 0
         case (x_count)
         0: begin
            // generate sync 
            // sync signal in back porch
            // new frame
            vidout_vs <= 1;
            vram_read_addr <= 0;
            pxl_device_ram_read_addr <= 8'h08; // Red (hi byte)
         end
         1: begin
            pxl_device_ram_read_addr <= 8'h09; // Red (lo byte)
         end
         2: begin
            color_0[11:8] <= pxl_device_ram_read_value[7:4];
            color_1[11:8] <= pxl_device_ram_read_value[3:0];
            pxl_device_ram_read_addr <= 8'h0A; // Green (hi byte)
         end
         3: begin
            color_2[11:8] <= pxl_device_ram_read_value[7:4];
            color_3[11:8] <= pxl_device_ram_read_value[3:0];
            pxl_device_ram_read_addr <= 8'h0B; // Green (lo byte)
         end
         4: begin
            color_0[7:4] <= pxl_device_ram_read_value[7:4];
            color_1[7:4] <= pxl_device_ram_read_value[3:0];
            pxl_device_ram_read_addr <= 8'h0C; // Blue (hi byte)
            has_set_palette <= color_0 == 12'h000 ? has_set_palette : 1;
         end
         5: begin
            color_2[7:4] <= pxl_device_ram_read_value[7:4];
            color_3[7:4] <= pxl_device_ram_read_value[3:0];
            pxl_device_ram_read_addr <= 8'h0D; // Blue (lo byte)
            has_set_palette <= color_1 == 12'h000 ? has_set_palette : 1;
         end
         6: begin
            color_0[3:0] <= pxl_device_ram_read_value[7:4];
            color_1[3:0] <= pxl_device_ram_read_value[3:0];
            pxl_device_ram_read_addr <= 8'h00;
            has_set_palette <= color_2 == 12'h000 ? has_set_palette : 1;
         end
         7: begin
            color_2[3:0] <= pxl_device_ram_read_value[7:4];
            color_3[3:0] <= pxl_device_ram_read_value[3:0];
            has_set_palette <= color_3 == 12'h000 ? has_set_palette : 1;
         end
         endcase
        end
        
        // we want HS to occur a bit after VS, not on the same cycle
        if(x_count == 3) begin
            // sync signal in back porch
            // new line
            vidout_hs <= 1;
        end

        // inactive screen areas are black
        vidout_rgb <= 24'h0;
        // generate active video
        if(y_count >= VID_V_BPORCH && y_count < VID_V_ACTIVE+VID_V_BPORCH) begin

            // read from VRAM a little ahead of where we draw
            if(x_count >= (VID_H_BPORCH - 1) && x_count < (VID_H_ACTIVE + VID_H_BPORCH - 1)) begin
               vram_read_addr <= vram_read_addr + 1;
            end
            
            if(x_count >= VID_H_BPORCH && x_count < VID_H_ACTIVE+VID_H_BPORCH) begin
                // data enable. this is the active region of the line
                vidout_de <= 1;
                
                case(uxn_vram_read_value)
                2'd0: begin
                    vidout_rgb <= has_set_palette ? {color_0[11:8], 4'h0, color_0[7:4], 4'h0, color_0[3:0], 4'h0} : 24'hF0F0F0;
                end
                2'd1: begin
                    vidout_rgb <= has_set_palette ? {color_1[11:8], 4'h0, color_1[7:4], 4'h0, color_1[3:0], 4'h0} : 24'h000000;
                end
                2'd2: begin
                    vidout_rgb <= has_set_palette ? {color_2[11:8], 4'h0, color_2[7:4], 4'h0, color_2[3:0], 4'h0} : 24'h70D0B0;
                end
                2'd3: begin
                    vidout_rgb <= has_set_palette ? {color_3[11:8], 4'h0, color_3[7:4], 4'h0, color_3[3:0], 4'h0} : 24'hF06020;
                end
                endcase
            end
        end 
    end
end

///////////////////////////////////////////////////////////////////////////////
// VRAM Controller
// 
// TODO: use auto-sync counting instead of hard-coded values
localparam  VRAM_COPY_CYCLE_BEGIN = 24'd2053491;
localparam  VRAM_COPY_CYCLE_END = 24'd2145655;

reg vram_last_cycle_count_latch = 0;
reg vram_cycle_count_latch = 0;
reg inner_cycle_count_latch = 0;
reg vram_last_vsync = 0;
reg did_copy_buffer;
reg [23:0] vram_cycle = 0;
reg [23:0] vram_copy_cycle_start = 0;
reg [23:0] vram_copy_cycle_end = 0;
reg [16:0] layer_vram_read_addr;
reg [16:0] vram_write_addr;
reg vram_write_enable = 0;
reg [1:0] vram_write_value;
always @ (posedge clk_core_vram)
begin
   vram_cycle <= vidout_vs_vram_s ? 0 : vram_cycle + 1;
   vram_last_vsync <= vidout_vs_vram_s;
   inner_cycle_count_latch <= inner_cycle_count_latch ? 1 : ~vram_last_vsync & vidout_vs_vram_s;
   vram_cycle_count_latch <= vram_cycle_count_latch ? 1 : inner_cycle_count_latch & ~vram_last_vsync & vidout_vs_vram_s;
   
   case (vram_cycle_count_latch)
   0: begin
      vram_write_enable <= 0;
      vram_write_value <= 0;
      layer_vram_read_addr <= 0;
      vram_write_addr <= 0;
   end
   1: begin
      case (vram_cycle) 
      VRAM_COPY_CYCLE_BEGIN: begin
         vram_write_enable <= ~is_drawing_busy_s;
         did_copy_buffer <= ~is_drawing_busy_s;
         vram_write_value <= 0;
         layer_vram_read_addr <= 17'd0;
         vram_write_addr <= 17'd131070;
      end
      VRAM_COPY_CYCLE_END: begin
         vram_write_enable <= 0;
         vram_write_value <= 0;
         layer_vram_read_addr <= 0;
         vram_write_addr <= 0;
      end
      default: begin
         case (vram_write_enable)
         0: begin
            vram_write_value <= 0;
            layer_vram_read_addr <= 0;
            vram_write_addr <= 0;
         end
         1: begin
            layer_vram_read_addr <= layer_vram_read_addr + 1;
            vram_write_addr <= vram_write_addr + 1;
            vram_write_value <= uxn_vram_fg_read_value == 0 ? uxn_vram_bg_read_value : uxn_vram_fg_read_value;
         end
         endcase
      end
      endcase
   end
   endcase   
end


//
// audio i2s silence generator
// see other examples for actual audio generation
//

assign audio_mclk = audgen_mclk;
assign audio_dac = audgen_dac;
assign audio_lrck = audgen_lrck;

// generate MCLK = 12.288mhz with fractional accumulator
    reg         [21:0]  audgen_accum;
    reg                 audgen_mclk;
    parameter   [20:0]  CYCLE_48KHZ = 21'd122880 * 2;
always @(posedge clk_74a) begin
    audgen_accum <= audgen_accum + CYCLE_48KHZ;
    if(audgen_accum >= 21'd742500) begin
        audgen_mclk <= ~audgen_mclk;
        audgen_accum <= audgen_accum - 21'd742500 + CYCLE_48KHZ;
    end
    
    if (bridge_wr) begin
       casex (bridge_addr)
         32'h10000200: begin
           is_mouse_toggle_enabled <= bridge_wr_data[0];
         end
       endcase
     end
end

// generate SCLK = 3.072mhz by dividing MCLK by 4
    reg [1:0]   aud_mclk_divider;
    wire        audgen_sclk = aud_mclk_divider[1] /* synthesis keep*/;
    reg         audgen_lrck_1;
always @(posedge audgen_mclk) begin
    aud_mclk_divider <= aud_mclk_divider + 1'b1;
end

// shift out audio data as I2S 
// 32 total bits per channel, but only 16 active bits at the start and then 16 dummy bits
//
    reg     [4:0]   audgen_lrck_cnt;    
    reg             audgen_lrck;
    reg             audgen_dac;
always @(negedge audgen_sclk) begin
    audgen_dac <= 1'b0;
    // 48khz * 64
    audgen_lrck_cnt <= audgen_lrck_cnt + 1'b1;
    if(audgen_lrck_cnt == 31) begin
        // switch channels
        audgen_lrck <= ~audgen_lrck;
        
    end 
end

///////////////////////////////////////////////

wire        ioctl_wr;
wire [15:0] ioctl_addr;
wire  [7:0] ioctl_dout;

data_loader #(
    .WRITE_MEM_CLOCK_DELAY(4)
) rom_loader (
    .clk_74a(clk_74a),
    .clk_memory(clk_core_uxn),

    .bridge_wr(bridge_wr),
    .bridge_endian_little(bridge_endian_little),
    .bridge_addr(bridge_addr),
    .bridge_wr_data(bridge_wr_data),

    .write_en(ioctl_wr),
    .write_addr(ioctl_addr),
    .write_data(ioctl_dout)
);

///////////////////////////////////////////////
    wire    clk_core_pixel;
    wire    clk_core_pixel_90deg;
    wire    clk_core_uxn;
    wire    clk_core_vram;
    
    wire    pll_core_locked;
    wire    pll_core_locked_s;
synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

mf_pllbase mp1 (
    .refclk         ( clk_74a ),
    .rst            ( 0 ),
    
    .outclk_0       ( clk_core_pixel ),
    .outclk_1       ( clk_core_pixel_90deg ),
    .outclk_2       ( clk_core_uxn ),
    .outclk_3       ( clk_core_vram ),
    
    
    .locked         ( pll_core_locked )
);

////////////////////////////////////////////////////////////////////////////////////////
// VSYNC
wire is_drawing_busy_s;
synch_2 #(
    .WIDTH(1)
) drawing_busy (
    is_screen_vector_running | ~is_draw_queue_ready,
    is_drawing_busy_s,
    clk_core_vram
);

wire did_copy_buffer_s;
synch_2 #(
    .WIDTH(1)
) dcb_s (
    did_copy_buffer,
    did_copy_buffer_s,
    clk_core_uxn
);

wire vidout_vs_s;
synch_2 #(
    .WIDTH(1)
) vsync_s (
    vidout_vs,
    vidout_vs_s,
    clk_core_uxn
);

wire vidout_vs_vram_s;
synch_2 #(
    .WIDTH(2)
) vsync_vram_s (
    vidout_vs,
    vidout_vs_vram_s,
    clk_core_vram
);

////////////////////////////////////////////////////////////////////////////////////////
// Real Time Clock
wire rtc_valid_s;
wire [31:0] rtc_date_bcd_s;
wire [31:0] rtc_time_bcd_s;

synch_3 #(
    .WIDTH(65)
) rtc_bcd_s (
    {rtc_valid, rtc_date_bcd, rtc_time_bcd}, // rtc_time_bcd rtc_date_bcd
    {rtc_valid_s, rtc_date_bcd_s, rtc_time_bcd_s},
    clk_core_uxn
);

////////////////////////////////////////////////////////////////////////////////////////
// Settings
reg is_mouse_toggle_enabled = 0;

// Synced settings
wire is_mouse_toggle_enabled_s;

synch_3 #(
    .WIDTH(1)
) internal_s (
    is_mouse_toggle_enabled,
    is_mouse_toggle_enabled_s,
    clk_core_uxn
);

////////////////////////////////////////////////////////////////////////////////////////
// Controls
wire [31:0] cont1_key_s;

synch_3 #(
    .WIDTH(32)
) cont1_s (
    cont1_key,
    cont1_key_s,
    clk_core_uxn
);


wire [1:0]  uxn_vram_bg_read_value;
wire [1:0]  uxn_vram_fg_read_value;
wire [1:0]  uxn_vram_read_value;
wire [7:0]  uxn_main_ram_read_value_a;
wire [7:0]  uxn_main_ram_read_value_b;
wire [7:0]  uxn_stack_ram_read_value_a;
wire [7:0]  uxn_stack_ram_read_value_b;
wire [7:0]  uxn_device_ram_read_value;
wire [7:0]  pxl_device_ram_read_value;

wire        layer_vram_write_en;
wire        layer_vram_write_layer;
wire [16:0] layer_vram_write_addr;
wire [1:0]  layer_vram_write_value;
wire        main_ram_write_en_a;
wire [15:0] main_ram_addr_a;
wire [15:0] main_ram_addr_b;
wire [7:0]  main_ram_write_value_a;
wire        stack_ram_write_en_a;
wire        stack_ram_write_en_b;
wire [8:0]  stack_ram_addr_a;
wire [8:0]  stack_ram_addr_b;
wire [7:0]  stack_ram_write_value_a;
wire [7:0]  stack_ram_write_value_b;
wire        device_ram_write_en;
wire [7:0]  device_ram_addr;
wire [7:0]  device_ram_write_value;
wire        queue_write_enable;
wire [23:0] queue_write_value;
wire        is_screen_vector_running;
wire        is_draw_queue_ready;

wire        queue_ram_write_enable;
wire [11:0] queue_ram_wr_addr;
wire [23:0] queue_ram_write_value;
wire [11:0] queue_ram_rd_addr;

wire [23:0] uxn_queue_bg_ram_read_value;
wire [23:0] uxn_queue_fg_ram_read_value;

uxn_cpu uxn_cpu (
    // input
    .cpu_clock(clk_core_uxn),
    .vsync(vidout_vs_s),
    .rtc_valid(rtc_valid_s),
    .rtc_date_bcd(rtc_date_bcd_s[31:0]),
    .rtc_time_bcd(rtc_time_bcd_s[31:0]),
    .mouse_enable(is_mouse_toggle_enabled_s),
    .controller0({cont1_key_s[3:0], cont1_key_s[15:14], cont1_key_s[5:4]}),
    .main_ram_read_value(uxn_main_ram_read_value_a),
    .stack_ram_read_value_a(uxn_stack_ram_read_value_a),
    .stack_ram_read_value_b(uxn_stack_ram_read_value_b),
    .device_ram_read_value(uxn_device_ram_read_value),
    .boot_read_address(ioctl_addr),
    .boot_read_value(ioctl_dout),
    .boot_valid_byte(ioctl_wr),
    .is_draw_queue_ready(is_draw_queue_ready),
    .did_copy_buffer(did_copy_buffer_s),

    // output
    .main_ram_write_enable(main_ram_write_en_a),
    .main_ram_addr(main_ram_addr_a),
    .main_ram_write_value(main_ram_write_value_a),
    .stack_ram_write_enable_a(stack_ram_write_en_a),
    .stack_ram_write_enable_b(stack_ram_write_en_b),
    .stack_ram_addr_a(stack_ram_addr_a),
    .stack_ram_addr_b(stack_ram_addr_b),
    .stack_ram_write_value_a(stack_ram_write_value_a),
    .stack_ram_write_value_b(stack_ram_write_value_b),
    .device_ram_write_enable(device_ram_write_en),
    .device_ram_addr(device_ram_addr),
    .device_ram_write_value(device_ram_write_value),
    .queue_write_enable(queue_write_enable),
    .queue_write_value(queue_write_value),
    .is_screen_vector_running(is_screen_vector_running)
);

uxn_draw_queue uxn_draw_queue (
   // input
   .data(queue_write_value),
   .we(queue_write_enable),
   .main_ram_read_value(uxn_main_ram_read_value_b),
   .queue_ram_read_value(uxn_queue_bg_ram_read_value),
   .clk(clk_core_uxn),
   
   // output
   .main_ram_addr(main_ram_addr_b),
   .queue_ram_write_enable(queue_ram_write_enable),
   .queue_ram_wr_addr(queue_ram_wr_addr),
   .queue_ram_write_value(queue_ram_write_value),
   .queue_ram_rd_addr(queue_ram_rd_addr),
   .vram_write_enable(layer_vram_write_en),
   .vram_write_layer(layer_vram_write_layer),
   .vram_write_addr(layer_vram_write_addr),
   .vram_write_value(layer_vram_write_value),
   .is_queue_empty(is_draw_queue_ready)
);

uxn_queue_ram_dp uxn_queue_ram (
   // input
   .data(queue_ram_write_value),
   .wr_addr(queue_ram_wr_addr),
   .we(queue_ram_write_enable),
   .rd_addr(queue_ram_rd_addr),
   .clk(clk_core_uxn),
   
   // output
   .q(uxn_queue_bg_ram_read_value)
);

uxn_vram uxn_vram_bg (
    // input
   .write_value(layer_vram_write_value),
   .read_addr(layer_vram_read_addr),
   .write_addr(layer_vram_write_addr),
   .write_enable(layer_vram_write_en & ~layer_vram_write_layer),
   .read_clock(clk_core_vram),
   .write_clock(clk_core_uxn),
   
   // output
   .read_value(uxn_vram_bg_read_value)
);

uxn_vram uxn_vram_fg (
    // input
   .write_value(layer_vram_write_value),
   .read_addr(layer_vram_read_addr),
   .write_addr(layer_vram_write_addr),
   .write_enable(layer_vram_write_en & layer_vram_write_layer),
   .read_clock(clk_core_vram),
   .write_clock(clk_core_uxn),
   
   // output
   .read_value(uxn_vram_fg_read_value)
);

uxn_vram uxn_vram (
    // input
   .write_value(vram_write_value),
   .read_addr(vram_read_addr),
   .write_addr(vram_write_addr),
   .write_enable(vram_write_enable),
   .read_clock(clk_core_pixel),
   .write_clock(clk_core_vram),
   
   // output
   .read_value(uxn_vram_read_value)
);

uxn_main_ram_dp uxn_main_ram (
    // input
    .data_a(main_ram_write_value_a),
    .addr_a(main_ram_addr_a),
    .addr_b(main_ram_addr_b),
    .we_a(main_ram_write_en_a),
    .clk(clk_core_uxn),
    
    // output
    .q_a(uxn_main_ram_read_value_a),
    .q_b(uxn_main_ram_read_value_b)
);

uxn_stack_ram_dp uxn_stack_ram_dp (
   // input
   .data_a(stack_ram_write_value_a),
   .data_b(stack_ram_write_value_b),
   .addr_a(stack_ram_addr_a),
   .addr_b(stack_ram_addr_b),
   .we_a(stack_ram_write_en_a),
   .we_b(stack_ram_write_en_b),
   .clk(clk_core_uxn),
   
   // output
   .q_a(uxn_stack_ram_read_value_a),
   .q_b(uxn_stack_ram_read_value_b)
);

uxn_device_ram_dp uxn_device_ram (
    // input
   .data_a(device_ram_write_value),
   .addr_a(device_ram_addr),
   .addr_b(pxl_device_ram_read_addr),
   .we_a(device_ram_write_en),
   .clk_a(clk_core_uxn),
   .clk_b(clk_core_pixel),
   
   // output
   .q_a(uxn_device_ram_read_value),
   .q_b(pxl_device_ram_read_value)
);
    
endmodule
