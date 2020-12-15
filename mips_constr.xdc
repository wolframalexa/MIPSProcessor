set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN Y9 [get_ports clk]
create_clock -period 10 [get_ports clk]

set_property PACKAGE_PIN M15 [get_ports reset]
set_property PACKAGE_PIN U14 [get_ports memwrite]

set_property IOSTANDARD LVCMOS18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports memwrite]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]
