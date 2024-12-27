sh mkdir -p rpt

set company {NTUGIEE}
set designer {Testing123}
set search_path      ". /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/db $search_path"
set target_library   "slow.db                 \
    fast.db                 \
    typical.db              \
"
set link_library     "* $target_library"

set my_toplevel s15850
read_verilog ../Test_s15850/Netlist/s15850_syn.v
current_design $my_toplevel
link
source ../Test_s15850/Netlist/s15850_syn.sdc

set test_default_scan_style multiplexed_flip_flop
set test_default_delay 0
set test_default_bidir_delay 0
set test_default_strobe 40
set test_default_period 100

create_test_protocol -infer_asynch -infer_clock
dft_drc

set_scan_configuration -chain_count 8
set_dft_configuration -fix_clock enable
set_dft_configuration -fix_reset enable
set_dft_configuration -fix_set enable

preview_dft
insert_dft

dft_drc

check_design

set filename [format "%s%s"  $my_toplevel "_dft.v"]
write -f verilog -hier -output [format "%s%s"  "./Netlist/" $filename]

set filename [format "%s%s"  $my_toplevel "_dft.spf"]
write_test_protocol -output [format "%s%s"  "./Netlist/" $filename]

set filename [format "%s%s"  $my_toplevel "_dft.ddc"]
write -f ddc -hier -output [format "%s%s"  "./Netlist/" $filename]

set filename [format "%s%s"  $my_toplevel "_dft.sdf"]
write_sdf -version 2.1 [format "%s%s"  "./Netlist/" $filename]

set filename [format "%s%s"  $my_toplevel "_dft.spef"]
write_parasitics -output [format "%s%s"  "./Netlist/" $filename]

set filename [format "%s%s"  $my_toplevel "_dft.scan_path"]
redirect [format "%s%s"  "./rpt/" $filename] { report_constraint -all_violators -verbose }

set filename [format "%s%s"  $my_toplevel "_dft.cell"]
redirect [format "%s%s"  "./rpt/" $filename] { report_constraint -all_violators -verbose }

redirect [format "%s%s"  "./rpt/" violation.rpt] { report_constraint -all_violators -verbose }
redirect [format "%s%s"  [format "%s%s"  "./rpt/" $my_toplevel] ".area"] { report_area }
redirect [format "%s%s"  "./rpt/" timing.rpt] { report_timing }
redirect [format "%s%s"  "./rpt/" cell.rpt] { report_cell }
redirect [format "%s%s"  "./rpt/" power.rpt] { report_power }
exit
