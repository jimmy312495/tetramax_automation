import os
from atpg_parser import ATPGConfig, parse_config


class DFTScriptGenerator:
    def __init__(self, config: ATPGConfig):
        self.config = config
        
    def mkdir(self, file):
        file.write("sh mkdir -p rpt\n\n")
    
    def set_libraries(self, file):
        file.write("set company {NTUGIEE}\n")
        file.write("set designer {Testing123}\n")
        file.write("set search_path      \". /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/SynopsysDC/db $search_path\"\n")
        file.write("set target_library   \"slow.db                 \\\n")
        file.write("    fast.db                 \\\n")
        file.write("    typical.db              \\\n")
        file.write("\"\n")
        file.write("set link_library     \"* $target_library\"\n\n")
        
    def set_top_level_module(self, file):
        file.write(f"set my_toplevel {self.config.top_module}\n")
        file.write(f"read_verilog {self.config.synthesized_files}\n")
        file.write("current_design $my_toplevel\n")
        file.write("link\n")
        file.write(f"source {self.config.synthesized_files.replace('.v', '.sdc')}\n\n")

    def set_test_defaults(self, file):
        file.write(f"set test_default_scan_style {self.config.scan_style}\n")
        file.write("set test_default_delay 0\n")
        file.write("set test_default_bidir_delay 0\n")
        file.write("set test_default_strobe 40\n")
        file.write("set test_default_period 100\n\n")

    def create_test_protocol(self, file):
        file.write("create_test_protocol -infer_asynch -infer_clock\n")
        file.write("dft_drc\n\n")

    def configure_scan_chain(self, file):
        file.write(f"set_scan_configuration -chain_count {self.config.num_scan_chain}\n")
        file.write("set_dft_configuration -fix_clock enable\n")
        file.write("set_dft_configuration -fix_reset enable\n")
        file.write("set_dft_configuration -fix_set enable\n\n")

    def insert_dft(self, file):
        file.write("preview_dft\n")
        file.write("insert_dft\n\n")
        file.write("dft_drc\n\n")
        file.write("check_design\n\n")

    def write_output_files(self, file):
        # Verilog
        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.v\"]\n")
        file.write("write -f verilog -hier -output [format \"%s%s\"  \"./Netlist/\" $filename]\n\n")

        # SPF
        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.spf\"]\n")
        file.write("write_test_protocol -output [format \"%s%s\"  \"./Netlist/\" $filename]\n\n")

        # DDC
        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.ddc\"]\n")
        file.write("write -f ddc -hier -output [format \"%s%s\"  \"./Netlist/\" $filename]\n\n")

        # SDF
        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.sdf\"]\n")
        file.write("write_sdf -version 2.1 [format \"%s%s\"  \"./Netlist/\" $filename]\n\n")

        # SPEF
        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.spef\"]\n")
        file.write("write_parasitics -output [format \"%s%s\"  \"./Netlist/\" $filename]\n\n")

    def write_reports(self, file):
        # Scan path and cell reports
        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.scan_path\"]\n")
        file.write("redirect [format \"%s%s\"  \"./rpt/\" $filename] { report_constraint -all_violators -verbose }\n\n")

        file.write("set filename [format \"%s%s\"  $my_toplevel \"_dft.cell\"]\n")
        file.write("redirect [format \"%s%s\"  \"./rpt/\" $filename] { report_constraint -all_violators -verbose }\n\n")

        # Various analysis reports
        file.write("redirect [format \"%s%s\"  \"./rpt/\" violation.rpt] { report_constraint -all_violators -verbose }\n")
        file.write("redirect [format \"%s%s\"  [format \"%s%s\"  \"./rpt/\" $my_toplevel] \".area\"] { report_area }\n")
        file.write("redirect [format \"%s%s\"  \"./rpt/\" timing.rpt] { report_timing }\n")
        file.write("redirect [format \"%s%s\"  \"./rpt/\" cell.rpt] { report_cell }\n")
        file.write("redirect [format \"%s%s\"  \"./rpt/\" power.rpt] { report_power }\n")
        file.write("exit\n")

    def generate_tcl(self, output_file: str):
        with open(output_file, 'w') as file:
            self.mkdir(file)
            self.set_libraries(file)
            self.set_top_level_module(file)
            self.set_test_defaults(file)
            self.create_test_protocol(file)
            self.configure_scan_chain(file)
            self.insert_dft(file)
            self.write_output_files(file)
            self.write_reports(file)

if __name__ == "__main__":
    config_file = "define.txt"
    config = parse_config(config_file)

    output_file = "dft_dc.tcl"

    generator = DFTScriptGenerator(config)
        
    generator.generate_tcl(output_file)

    print(f"TCL script generated successfully: {os.path.abspath(output_file)}")
