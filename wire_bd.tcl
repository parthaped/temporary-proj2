# =============================================================================
# wire_bd.tcl
#
# Run this AFTER you have manually added every VHDL file under EmbeddedFinal/
# and the constraints/zybo_scope.xdc to a Vivado project for the original
# Zybo (rev B, xc7z010clg400-1).
#
# It builds the `scope_bd` block design using IP Integrator:
#   - one module-reference cell per RTL entity
#   - two xlconstant IPs that stub the joystick path
#   - external BD ports for sysclk, reset, VGA, Pmod JC (AD1), Pmod JE (keypad)
#   - every cross-module connect_bd_net from the audit
#   - validate + save the BD
#
# It does NOT create the project, add files, set the part, or generate the
# HDL wrapper. Create the HDL wrapper yourself afterwards:
#   Sources panel -> right-click scope_bd.bd -> Create HDL Wrapper
#
# Usage from the Vivado Tcl Console (project must already be open):
#     source <path>/wire_bd.tcl
# =============================================================================

set bd_name "scope_bd"

# Make sure the sources you added are visible to module-reference lookups.
update_compile_order -fileset sources_1

# -----------------------------------------------------------------------------
# 1. Create the block design (error out if one already exists with this name;
#    Vivado will refuse to silently overwrite it and that's the safer default)
# -----------------------------------------------------------------------------
if {[llength [get_bd_designs -quiet $bd_name]] > 0} {
    error "A block design named '$bd_name' already exists. Close/remove it before sourcing this script."
}
create_bd_design $bd_name
current_bd_design [get_bd_designs $bd_name]

# -----------------------------------------------------------------------------
# 2. Module-reference cells (one per RTL entity)
# -----------------------------------------------------------------------------
create_bd_cell -type module -reference clk_div_vga       clk_div_vga_i
create_bd_cell -type module -reference vga_ctrl          vga_ctrl_i
create_bd_cell -type module -reference Frame_buffers     frame_buffer_ch1
create_bd_cell -type module -reference Frame_buffers     frame_buffer_ch2
create_bd_cell -type module -reference SPI_Controller    spi_controller_i
create_bd_cell -type module -reference Main_Controller   main_controller_i
create_bd_cell -type module -reference keypad_controller keypad_controller_i
create_bd_cell -type module -reference pixel_pusher      pixel_pusher_i
create_bd_cell -type module -reference debouncer         debouncer_reset

# -----------------------------------------------------------------------------
# 3. Joystick stubs (xlconstant IPs)
#    jstk_y     = 0x200 (mid-stick) so neither zoom branch triggers
#    jstk_tick  = 0     so the UI process never sees a tick
# -----------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 jstk_y_const
set_property -dict [list \
    CONFIG.CONST_WIDTH {10} \
    CONFIG.CONST_VAL   {0x200} \
] [get_bd_cells jstk_y_const]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 jstk_tick_const
set_property -dict [list \
    CONFIG.CONST_WIDTH {1} \
    CONFIG.CONST_VAL   {0} \
] [get_bd_cells jstk_tick_const]

# -----------------------------------------------------------------------------
# 4. External BD ports (these become top-level ports on the auto-wrapper)
# -----------------------------------------------------------------------------
create_bd_port -dir I -type clk sysclk
set_property CONFIG.FREQ_HZ 125000000 [get_bd_ports sysclk]

create_bd_port -dir I rst_btn

create_bd_port -dir O -from 4 -to 0 vga_r
create_bd_port -dir O -from 5 -to 0 vga_g
create_bd_port -dir O -from 4 -to 0 vga_b
create_bd_port -dir O vga_hs
create_bd_port -dir O vga_vs

create_bd_port -dir O jc_cs
create_bd_port -dir O jc_sclk
create_bd_port -dir I jc_d0
create_bd_port -dir I jc_d1

create_bd_port -dir O -from 3 -to 0 je_cols
create_bd_port -dir I -from 3 -to 0 je_rows

# -----------------------------------------------------------------------------
# 5. Wiring
# -----------------------------------------------------------------------------
# --- Clock fan-out: sysclk -> every cell's `clk` -----------------------------
connect_bd_net [get_bd_ports sysclk] [get_bd_pins clk_div_vga_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins vga_ctrl_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins frame_buffer_ch1/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins frame_buffer_ch2/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins spi_controller_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins main_controller_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins keypad_controller_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins pixel_pusher_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins debouncer_reset/clk]

# --- Reset: rst_btn -> debouncer -> {reset, fb_reset} on consumers ----------
connect_bd_net [get_bd_ports rst_btn]                   [get_bd_pins debouncer_reset/btn]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal] [get_bd_pins main_controller_i/reset]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal] [get_bd_pins spi_controller_i/reset]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal] [get_bd_pins frame_buffer_ch1/fb_reset]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal] [get_bd_pins frame_buffer_ch2/fb_reset]

# --- 25 MHz pixel-enable pulse fan-out ---------------------------------------
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins vga_ctrl_i/en]
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins pixel_pusher_i/en]
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins frame_buffer_ch1/pix_tick]
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins frame_buffer_ch2/pix_tick]

# --- vga_ctrl -> pixel_pusher + main_controller.vsync + VGA sync pins -------
connect_bd_net [get_bd_pins vga_ctrl_i/hcount] [get_bd_pins pixel_pusher_i/hcount]
connect_bd_net [get_bd_pins vga_ctrl_i/vcount] [get_bd_pins pixel_pusher_i/vcount]
connect_bd_net [get_bd_pins vga_ctrl_i/vid]    [get_bd_pins pixel_pusher_i/vid]
connect_bd_net [get_bd_pins vga_ctrl_i/vs]     [get_bd_pins pixel_pusher_i/vs]
connect_bd_net [get_bd_pins vga_ctrl_i/vs]     [get_bd_pins main_controller_i/vsync]
connect_bd_net [get_bd_pins vga_ctrl_i/hs]     [get_bd_ports vga_hs]
connect_bd_net [get_bd_pins vga_ctrl_i/vs]     [get_bd_ports vga_vs]

# --- pixel_pusher -> VGA colour pins -----------------------------------------
connect_bd_net [get_bd_pins pixel_pusher_i/R] [get_bd_ports vga_r]
connect_bd_net [get_bd_pins pixel_pusher_i/G] [get_bd_ports vga_g]
connect_bd_net [get_bd_pins pixel_pusher_i/B] [get_bd_ports vga_b]

# --- Frame buffers <- Main_Controller (write side) ---------------------------
connect_bd_net [get_bd_pins main_controller_i/fb_addr_1]     [get_bd_pins frame_buffer_ch1/addr_1]
connect_bd_net [get_bd_pins main_controller_i/fb_wr_en_1]    [get_bd_pins frame_buffer_ch1/wr_en1]
connect_bd_net [get_bd_pins main_controller_i/fb_data_out_1] [get_bd_pins frame_buffer_ch1/din1]

connect_bd_net [get_bd_pins main_controller_i/fb_addr_2]     [get_bd_pins frame_buffer_ch2/addr_1]
connect_bd_net [get_bd_pins main_controller_i/fb_wr_en_2]    [get_bd_pins frame_buffer_ch2/wr_en1]
connect_bd_net [get_bd_pins main_controller_i/fb_data_out_2] [get_bd_pins frame_buffer_ch2/din1]

# --- Frame buffers -> pixel_pusher (read side) -------------------------------
connect_bd_net [get_bd_pins pixel_pusher_i/read_addr] [get_bd_pins frame_buffer_ch1/addr_2]
connect_bd_net [get_bd_pins pixel_pusher_i/read_addr] [get_bd_pins frame_buffer_ch2/addr_2]
connect_bd_net [get_bd_pins frame_buffer_ch1/dout2]   [get_bd_pins pixel_pusher_i/bram_data_1]
connect_bd_net [get_bd_pins frame_buffer_ch2/dout2]   [get_bd_pins pixel_pusher_i/bram_data_2]

# frame_buffer_ch{1,2}/dout1 stay OPEN on purpose (system-side readback,
# nothing consumes it; one synth warning each is expected)

# --- SPI_Controller <-> Main_Controller --------------------------------------
connect_bd_net [get_bd_pins spi_controller_i/data_ready]   [get_bd_pins main_controller_i/SPI_data_acq]
connect_bd_net [get_bd_pins spi_controller_i/next_sample]  [get_bd_pins main_controller_i/next_sample]
connect_bd_net [get_bd_pins spi_controller_i/data_out_1]   [get_bd_pins main_controller_i/SPI_data_in_1]
connect_bd_net [get_bd_pins spi_controller_i/data_out_2]   [get_bd_pins main_controller_i/SPI_data_in_2]
connect_bd_net [get_bd_pins main_controller_i/SPI_read_en] [get_bd_pins spi_controller_i/read_en]

# --- SPI_Controller -> Pmod JC pins ------------------------------------------
connect_bd_net [get_bd_pins spi_controller_i/sclk]     [get_bd_ports jc_sclk]
connect_bd_net [get_bd_pins spi_controller_i/chip_sel] [get_bd_ports jc_cs]
connect_bd_net [get_bd_ports jc_d0] [get_bd_pins spi_controller_i/data_in_1]
connect_bd_net [get_bd_ports jc_d1] [get_bd_pins spi_controller_i/data_in_2]

# --- Keypad <-> Pmod JE pins + pixel_pusher ----------------------------------
connect_bd_net [get_bd_pins keypad_controller_i/cols]      [get_bd_ports je_cols]
connect_bd_net [get_bd_ports je_rows]                      [get_bd_pins keypad_controller_i/rows]
connect_bd_net [get_bd_pins keypad_controller_i/key_valid] [get_bd_pins pixel_pusher_i/key_valid]
connect_bd_net [get_bd_pins keypad_controller_i/key_data]  [get_bd_pins pixel_pusher_i/key_data]

# --- Joystick stubs -> pixel_pusher ------------------------------------------
connect_bd_net [get_bd_pins jstk_y_const/dout]    [get_bd_pins pixel_pusher_i/jstk_y]
connect_bd_net [get_bd_pins jstk_tick_const/dout] [get_bd_pins pixel_pusher_i/jstk_tick]

# main_controller_i/pixel_read_en stays OPEN on purpose (1-cycle "frame
# ready" status pulse with no functional consumer; wire to a debug LED later
# if you want a visible heartbeat)

# -----------------------------------------------------------------------------
# 6. Tidy up and save
# -----------------------------------------------------------------------------
regenerate_bd_layout
validate_bd_design
save_bd_design

puts "============================================================"
puts "INFO: scope_bd built and saved."
puts ""
puts "NEXT STEPS (in the Vivado GUI):"
puts "  1. Sources panel -> right-click scope_bd.bd"
puts "     -> Create HDL Wrapper..."
puts "     -> 'Let Vivado manage wrapper and auto-update' -> OK"
puts "  2. Flow Navigator -> Generate Bitstream."
puts "============================================================"
