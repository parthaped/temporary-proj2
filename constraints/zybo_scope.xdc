# =============================================================================
# zybo_scope.xdc - Pin and timing constraints for the ZyboScope project.
# Target board: Digilent Zybo (rev B, original; NOT Zybo Z7).
# FPGA:         xc7z010clg400-1
#
# Pin values are pulled from the Digilent Zybo (rev B) Master XDC. Spot-check
# the Pmod-position comments on the right side of each line against your
# board schematic before flashing.
# =============================================================================

# -----------------------------------------------------------------------------
# 125 MHz system clock from Ethernet PHY (you confirmed L16)
# -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports sysclk]
create_clock -name sysclk -period 8.000 [get_ports sysclk]

# -----------------------------------------------------------------------------
# Reset button (BTN0)
# -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports rst_btn]

# -----------------------------------------------------------------------------
# VGA connector (RGB565 + HS/VS)
# -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN M19 IOSTANDARD LVCMOS33 } [get_ports {vga_r[0]}]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports {vga_r[1]}]
set_property -dict { PACKAGE_PIN J20 IOSTANDARD LVCMOS33 } [get_ports {vga_r[2]}]
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS33 } [get_ports {vga_r[3]}]
set_property -dict { PACKAGE_PIN F19 IOSTANDARD LVCMOS33 } [get_ports {vga_r[4]}]

set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 } [get_ports {vga_g[0]}]
set_property -dict { PACKAGE_PIN N20 IOSTANDARD LVCMOS33 } [get_ports {vga_g[1]}]
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports {vga_g[2]}]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS33 } [get_ports {vga_g[3]}]
set_property -dict { PACKAGE_PIN H20 IOSTANDARD LVCMOS33 } [get_ports {vga_g[4]}]
set_property -dict { PACKAGE_PIN F20 IOSTANDARD LVCMOS33 } [get_ports {vga_g[5]}]

set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports {vga_b[0]}]
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports {vga_b[1]}]
set_property -dict { PACKAGE_PIN K19 IOSTANDARD LVCMOS33 } [get_ports {vga_b[2]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {vga_b[3]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports {vga_b[4]}]

set_property -dict { PACKAGE_PIN P19 IOSTANDARD LVCMOS33 } [get_ports vga_hs]
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports vga_vs]

# -----------------------------------------------------------------------------
# Pmod JC = Pmod AD1
#   chip_sel = JC1, D0 (ch1) = JC2, D1 (ch2) = JC3, sclk = JC4
# -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports jc_cs]   ;# JC1
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports jc_d0]   ;# JC2
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports jc_d1]   ;# JC3
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports jc_sclk] ;# JC4

# -----------------------------------------------------------------------------
# Pmod JE = 4x4 matrix keypad
#   cols on JE1..JE4 (driven low one at a time)
#   rows on JE7..JE10 (sampled; PULLUP so they idle high)
# -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports {je_cols[0]}] ;# JE1
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports {je_cols[1]}] ;# JE2
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {je_cols[2]}] ;# JE3
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {je_cols[3]}] ;# JE4

set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {je_rows[0]}] ;# JE7
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {je_rows[1]}] ;# JE8
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {je_rows[2]}] ;# JE9
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports {je_rows[3]}] ;# JE10

# -----------------------------------------------------------------------------
# Pmod JB (joystick) - intentionally not constrained. The jstk_y / jstk_tick
# BD ports are stubbed with xlconstant cells until a real PmodJSTK2 controller
# is added. When you wire one in, add JB pin assignments here.
# -----------------------------------------------------------------------------
