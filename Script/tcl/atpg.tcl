##############################################
#                   ATPG                     #
##############################################

read_netlist /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v

read_netlist ./Netlist/s15850_dft.v

run_build_model s15850

run_drc ../Test_s15850/Netlist/s15850_dft.spf

set_atpg -coverage 100
set_faults -model transition
set_faults -report collapsed
set_faults -fault_coverage
set_faults -summary verbose

set_delay -launch any

set_atpg -capture 4

add_faults -all

run_atpg -auto_compression

report_summaries
report_summaries > ../Test_s15850/Netlist/s15850_ATPG_report.rpt

write_faults ../Test_s15850/Netlist/s15850.fault -all -replace

write_patterns ../Test_s15850/Netlist/s15850.stil -format STIL -replace

exit