# Access environmental variables
set channel_count $env(CHANNEL_COUNT)
set window_length $env(WINDOW_LENGTH)
set data_width $env(DATA_WIDTH)
set q_scale $env(Q_SCALE)

# Save the current working directory
set current_dir [pwd]


# Create project
file mkdir ./hw/vivado_project
create_project vivado_project ./hw/vivado_project -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

# Import design files
import_files -norecurse -fileset sources_1 ./hw/src/sv/design/

# Import simulation files
import_files -norecurse -fileset sim_1 ./hw/src/sv/testbench/

# Set top file
set_property top axis_l_sorter [get_filesets sources_1]

# Import constrains
import_files -norecurse -fileset constrs_1 ./hw/src/xdc/

# Generate IPs
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name bram_filter
set width [expr {2*$data_width}]
set depth $channel_count
set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A $width \
    CONFIG.Read_Width_A $width \
    CONFIG.Write_Width_B $width \
    CONFIG.Read_Width_B $width \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Use_REGCEB_Pin {true}] [get_ips bram_filter]
generate_target all [get_ips bram_filter]
create_ip_run [get_ips bram_filter]
launch_run bram_filter_synth_1
wait_on_run bram_filter_synth_1

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name bram_median
set width [expr {int((ceil(log($window_length - 1)/log(2)) + $data_width - 1) * ($window_length - 1))}]
set depth $channel_count
set coe_file_path [format "%s/python_outputs/detector.coe" $current_dir]
set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A $width \
    CONFIG.Read_Width_A $width \
    CONFIG.Write_Width_B $width \
    CONFIG.Read_Width_B $width \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Load_Init_File {true} \
    CONFIG.Use_REGCEB_Pin {true} \
    CONFIG.Coe_File $coe_file_path] [get_ips bram_median]
generate_target all [get_ips bram_median]
create_ip_run [get_ips bram_median]
launch_run bram_median_synth_1
wait_on_run bram_median_synth_1

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name bram_cluster
set width [expr {22}]
set depth [expr {2*$channel_count}]
set_property -dict [list \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A $width \
    CONFIG.Read_Width_A $width \
    CONFIG.Write_Width_B $width \
    CONFIG.Read_Width_B $width \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Register_PortB_Output_of_Memory_Primitives	false] [get_ips bram_cluster]
generate_target all [get_ips bram_cluster]
create_ip_run [get_ips bram_cluster]
launch_run bram_cluster_synth_1
wait_on_run bram_cluster_synth_1

create_ip -name div_gen -vendor xilinx.com -library ip -version 5.1 -module_name loc_divider
set_property -dict [list \
  CONFIG.algorithm_type {High_Radix} \
  CONFIG.dividend_and_quotient_width {29} \
  CONFIG.divisor_width {18} \
  CONFIG.fractional_width {0} \
  CONFIG.latency {25} \
  CONFIG.remainder_type {Fractional} \
] [get_ips loc_divider]
generate_target all [get_ips loc_divider]
create_ip_run [get_ips loc_divider]
launch_run loc_divider_synth_1
wait_on_run loc_divider_synth_1

# Update compile order
update_compile_order -fileset [current_fileset]

# Set the top module
set_property top tb_top [get_filesets sim_1]

# Update compile order
update_compile_order -fileset [current_fileset]
