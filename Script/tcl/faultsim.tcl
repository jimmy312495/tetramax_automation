##############################################
#                 FaultSim                   #
##############################################

read_netlist /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v

read_netlist ./Netlist/s15850_dft.v

run_build_model s15850

add_clocks 0 CK
add_pi_constraint 0 test_se

run_drc ../Test_s15850/Netlist/s15850_dft.spf

set_faults -model transition
set_faults -report collapsed
set_faults -fault_coverage
set_faults -summary verbose

read_faults ../Test_s15850/Netlist/s15850.fault
set_patterns -external ../Test_s15850/Netlist/s15850.stil
set_delay -launch any

set_atpg -capture 4

add_faults -all

set_simulation -measure pat
run_simulation -sequential

run_fault_sim -sequential

report_summaries
report_summaries > ../Test_s15850/Netlist/s15850_FS_report.rpt

write_faults ../Test_s15850/Netlist/s15850.fault -all -replace

exit