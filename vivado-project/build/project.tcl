set projDir "./vivado"
set projName "beta"
set topName top
set device xc7a35tftg256-1
if {[file exists "$projDir"]} { file delete -force "$projDir" }
create_project $projName "$projDir" -part $device
set_property design_mode RTL [get_filesets sources_1]
set verilogSources [list "./source/alchitry_top.sv" "./source/reset_conditioner.sv" "./source/alu.sv" "./source/bit_reverse.sv" "./source/pipeline.sv" "./source/button_conditioner.sv" "./source/edge_detector.sv" "./source/regfile_memory.sv" "./source/regfile_unit.sv" "./source/simple_ram.v" "./source/simple_dual_port_ram.v" "./source/control_unit.sv" "./source/beta_cpu.sv" "./source/pc_unit.sv" "./source/counter.sv" "./source/decoder.sv" "./source/add_and_sub.sv" "./source/fa.sv" "./source/rca.sv" "./source/mul.sv" "./source/boolean.sv" "./source/mux2to1.sv" "./source/mux4to1.sv" "./source/compact_shifter.sv" "./source/compare_unit.sv" "./source/popcount.sv" "./source/reduction.v" "./source/game_datapath.sv" "./source/game_regfile.sv" "./source/game_fsm.sv" "./source/box_fsm.sv" "./source/game_control_unit.sv" "./source/tictactoe_ws2812_display.sv" "./source/lucid_globals.sv" ]
import_files -fileset [get_filesets sources_1] -norecurse $verilogSources
set xdcSources [list "./constraint/alchitry.xdc" "./constraint/au_props.xdc" ]
read_xdc $xdcSources
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
update_compile_order -fileset sources_1
launch_runs -runs synth_1 -jobs 6
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1
