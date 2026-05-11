# =============================================================================
# create_project.tcl
#
# One-shot Vivado Tcl that creates a project for the original Zybo (rev B,
# xc7z010clg400-1), adds every RTL/sim source under EmbeddedFinal/, builds
# a block design (`scope_bd`) using module references for each entity, wires
# everything per the cross-module audit, stubs the joystick path with
# xlconstant IPs, generates the BD wrapper, and sets it as the top.
#
# Usage from Vivado Tcl Console:
#     cd C:/Users/Parth/royce-embed
#     source ./create_project.tcl
# Then open scope_bd, sanity-check, and Generate Bitstream from Flow Navigator.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. Resolve paths so this works no matter where Vivado is launched from
# -----------------------------------------------------------------------------
set script_path [file normalize [info script]]
set script_dir  [file dirname $script_path]
set src_dir     [file join $script_dir "EmbeddedFinal"]
set constr_dir  [file join $script_dir "constraints"]
set xdc_file    [file join $constr_dir "zybo_scope.xdc"]
set project_dir [file join $script_dir "vivado_project"]

set project_name "ZyboScope"
set part_name    "xc7z010clg400-1"
set bd_name      "scope_bd"

if {![file isdirectory $src_dir]} {
    error "EmbeddedFinal/ not found next to this script at $src_dir"
}
if {![file isfile $xdc_file]} {
    error "Expected constraints file at $xdc_file. Create it before running this script."
}

puts "INFO: Creating $project_name at $project_dir for $part_name"

# -----------------------------------------------------------------------------
# 1. Create the project (force overwrite)
# -----------------------------------------------------------------------------
create_project $project_name $project_dir -part $part_name -force
set_property target_language VHDL [current_project]
set_property default_lib     work [current_project]

# -----------------------------------------------------------------------------
# 2. Add RTL sources
# -----------------------------------------------------------------------------
set rtl_files [list \
    [file join $src_dir "clk_div_vga.vhd"] \
    [file join $src_dir "debouncer.vhd"] \
    [file join $src_dir "Frame_buffers.vhd"] \
    [file join $src_dir "keypad_controller.vhd"] \
    [file join $src_dir "Main_Controller.vhd"] \
    [file join $src_dir "pixel_pusher.vhd"] \
    [file join $src_dir "SPI_Controller.vhd"] \
    [file join $src_dir "vga_ctrl.vhd"] \
]
add_files -norecurse $rtl_files

# Simulation testbench (SPI_test.vhd is intentionally NOT added; it is a
# hand-driven hardware smoke wrapper and not part of the synthesis build)
set sim_file [file join $src_dir "SPI_tb.vhd"]
if {[file isfile $sim_file]} {
    add_files -fileset sim_1 -norecurse $sim_file
}

# Constraints
add_files -fileset constrs_1 -norecurse $xdc_file

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# -----------------------------------------------------------------------------
# 3. Create the block design
# -----------------------------------------------------------------------------
create_bd_design $bd_name
current_bd_design [get_bd_designs $bd_name]

# -----------------------------------------------------------------------------
# 4. Instantiate every RTL entity as a module-reference cell
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
# 5. Joystick stubs (xlconstant IPs)
#    jstk_y = 0x200 (mid-stick) so neither zoom-in nor zoom-out branch triggers
#    jstk_tick = 0 so the UI process never processes a stale joystick value
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
# 6. External BD ports (these become top-level ports on the auto-wrapper)
# -----------------------------------------------------------------------------
# Clock
create_bd_port -dir I -type clk sysclk
set_property CONFIG.FREQ_HZ 125000000 [get_bd_ports sysclk]

# Reset (raw button, debounced internally by debouncer_reset)
create_bd_port -dir I rst_btn

# VGA outputs (RGB565 + sync)
create_bd_port -dir O -from 4 -to 0 vga_r
create_bd_port -dir O -from 5 -to 0 vga_g
create_bd_port -dir O -from 4 -to 0 vga_b
create_bd_port -dir O vga_hs
create_bd_port -dir O vga_vs

# Pmod JC: Pmod AD1 (chip_sel=JC1, D0=JC2, D1=JC3, sclk=JC4)
create_bd_port -dir O jc_cs
create_bd_port -dir O jc_sclk
create_bd_port -dir I jc_d0
create_bd_port -dir I jc_d1

# Pmod JE: 4x4 keypad
create_bd_port -dir O -from 3 -to 0 je_cols
create_bd_port -dir I -from 3 -to 0 je_rows

# -----------------------------------------------------------------------------
# 7. Wiring
# -----------------------------------------------------------------------------
# --- Clock fan-out: sysclk -> every cell's `clk` -------------------------------
connect_bd_net [get_bd_ports sysclk] [get_bd_pins clk_div_vga_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins vga_ctrl_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins frame_buffer_ch1/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins frame_buffer_ch2/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins spi_controller_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins main_controller_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins keypad_controller_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins pixel_pusher_i/clk]
connect_bd_net [get_bd_ports sysclk] [get_bd_pins debouncer_reset/clk]

# --- Reset path: rst_btn -> debouncer_reset -> {fb_reset, reset} ---------------
connect_bd_net [get_bd_ports rst_btn]                    [get_bd_pins debouncer_reset/btn]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal]  [get_bd_pins main_controller_i/reset]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal]  [get_bd_pins spi_controller_i/reset]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal]  [get_bd_pins frame_buffer_ch1/fb_reset]
connect_bd_net [get_bd_pins  debouncer_reset/db_signal]  [get_bd_pins frame_buffer_ch2/fb_reset]

# --- 25 MHz pixel-enable pulse fan-out -----------------------------------------
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins vga_ctrl_i/en]
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins pixel_pusher_i/en]
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins frame_buffer_ch1/pix_tick]
connect_bd_net [get_bd_pins clk_div_vga_i/div_vga] [get_bd_pins frame_buffer_ch2/pix_tick]

# --- vga_ctrl -> pixel_pusher + main_controller.vsync + VGA sync pins ---------
connect_bd_net [get_bd_pins vga_ctrl_i/hcount] [get_bd_pins pixel_pusher_i/hcount]
connect_bd_net [get_bd_pins vga_ctrl_i/vcount] [get_bd_pins pixel_pusher_i/vcount]
connect_bd_net [get_bd_pins vga_ctrl_i/vid]    [get_bd_pins pixel_pusher_i/vid]
connect_bd_net [get_bd_pins vga_ctrl_i/vs]     [get_bd_pins pixel_pusher_i/vs]
connect_bd_net [get_bd_pins vga_ctrl_i/vs]     [get_bd_pins main_controller_i/vsync]
connect_bd_net [get_bd_pins vga_ctrl_i/hs]     [get_bd_ports vga_hs]
connect_bd_net [get_bd_pins vga_ctrl_i/vs]     [get_bd_ports vga_vs]

# --- pixel_pusher -> VGA colour pins ------------------------------------------
connect_bd_net [get_bd_pins pixel_pusher_i/R] [get_bd_ports vga_r]
connect_bd_net [get_bd_pins pixel_pusher_i/G] [get_bd_ports vga_g]
connect_bd_net [get_bd_pins pixel_pusher_i/B] [get_bd_ports vga_b]

# --- Frame buffers <-> Main_Controller (write side) ---------------------------
connect_bd_net [get_bd_pins main_controller_i/fb_addr_1]     [get_bd_pins frame_buffer_ch1/addr_1]
connect_bd_net [get_bd_pins main_controller_i/fb_wr_en_1]    [get_bd_pins frame_buffer_ch1/wr_en1]
connect_bd_net [get_bd_pins main_controller_i/fb_data_out_1] [get_bd_pins frame_buffer_ch1/din1]

connect_bd_net [get_bd_pins main_controller_i/fb_addr_2]     [get_bd_pins frame_buffer_ch2/addr_1]
connect_bd_net [get_bd_pins main_controller_i/fb_wr_en_2]    [get_bd_pins frame_buffer_ch2/wr_en1]
connect_bd_net [get_bd_pins main_controller_i/fb_data_out_2] [get_bd_pins frame_buffer_ch2/din1]

# --- Frame buffers <-> pixel_pusher (read side) -------------------------------
connect_bd_net [get_bd_pins pixel_pusher_i/read_addr] [get_bd_pins frame_buffer_ch1/addr_2]
connect_bd_net [get_bd_pins pixel_pusher_i/read_addr] [get_bd_pins frame_buffer_ch2/addr_2]
connect_bd_net [get_bd_pins frame_buffer_ch1/dout2]   [get_bd_pins pixel_pusher_i/bram_data_1]
connect_bd_net [get_bd_pins frame_buffer_ch2/dout2]   [get_bd_pins pixel_pusher_i/bram_data_2]

# (frame_buffer_ch{1,2}/dout1 are intentionally left OPEN. They are the
#  system-side readback that nothing in this design consumes.)

# --- SPI_Controller <-> Main_Controller ---------------------------------------
connect_bd_net [get_bd_pins spi_controller_i/data_ready]  [get_bd_pins main_controller_i/SPI_data_acq]
connect_bd_net [get_bd_pins spi_controller_i/next_sample] [get_bd_pins main_controller_i/next_sample]
connect_bd_net [get_bd_pins spi_controller_i/data_out_1]  [get_bd_pins main_controller_i/SPI_data_in_1]
connect_bd_net [get_bd_pins spi_controller_i/data_out_2]  [get_bd_pins main_controller_i/SPI_data_in_2]
connect_bd_net [get_bd_pins main_controller_i/SPI_read_en] [get_bd_pins spi_controller_i/read_en]

# --- SPI_Controller -> Pmod JC pins -------------------------------------------
connect_bd_net [get_bd_pins spi_controller_i/sclk]     [get_bd_ports jc_sclk]
connect_bd_net [get_bd_pins spi_controller_i/chip_sel] [get_bd_ports jc_cs]
connect_bd_net [get_bd_ports jc_d0] [get_bd_pins spi_controller_i/data_in_1]
connect_bd_net [get_bd_ports jc_d1] [get_bd_pins spi_controller_i/data_in_2]

# --- Keypad -> Pmod JE pins + pixel_pusher ------------------------------------
connect_bd_net [get_bd_pins keypad_controller_i/cols] [get_bd_ports je_cols]
connect_bd_net [get_bd_ports je_rows] [get_bd_pins keypad_controller_i/rows]
connect_bd_net [get_bd_pins keypad_controller_i/key_valid] [get_bd_pins pixel_pusher_i/key_valid]
connect_bd_net [get_bd_pins keypad_controller_i/key_data]  [get_bd_pins pixel_pusher_i/key_data]

# --- Joystick stubs -> pixel_pusher -------------------------------------------
connect_bd_net [get_bd_pins jstk_y_const/dout]    [get_bd_pins pixel_pusher_i/jstk_y]
connect_bd_net [get_bd_pins jstk_tick_const/dout] [get_bd_pins pixel_pusher_i/jstk_tick]

# (main_controller_i/pixel_read_en is intentionally left OPEN; it is a 1-cycle
#  "frame ready" status pulse with no functional consumer. Wire it to a debug
#  LED later if you want a visible heartbeat.)

# -----------------------------------------------------------------------------
# 8. Validate, save, generate wrapper, set top
# -----------------------------------------------------------------------------
regenerate_bd_layout
validate_bd_design
save_bd_design

set bd_file [get_files ${bd_name}.bd]
make_wrapper -files $bd_file -top

set wrapper_glob [file join $project_dir "${project_name}.gen" "sources_1" "bd" $bd_name "hdl" "${bd_name}_wrapper.vhd"]
set wrapper_files [glob -nocomplain $wrapper_glob]
if {[llength $wrapper_files] == 0} {
    # Older Vivado layouts put it under .srcs instead of .gen
    set wrapper_glob [file join $project_dir "${project_name}.srcs" "sources_1" "bd" $bd_name "hdl" "${bd_name}_wrapper.vhd"]
    set wrapper_files [glob -nocomplain $wrapper_glob]
}
if {[llength $wrapper_files] == 0} {
    error "Could not locate generated wrapper file at $wrapper_glob"
}
add_files -norecurse $wrapper_files
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "============================================================"
puts "INFO: Project setup complete."
puts "      BD       : $bd_name"
puts "      Top      : ${bd_name}_wrapper"
puts "      Part     : $part_name"
puts "      Project  : $project_dir"
puts "Open the block design, sanity-check, then Generate Bitstream"
puts "from the Flow Navigator."
puts "============================================================"
