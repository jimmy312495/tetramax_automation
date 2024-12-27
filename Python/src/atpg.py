import os
from config_parser import Config, parse_config

class BaseATPGScriptGenerator:
    def __init__(self, config: Config):
        self.config = config
        self.config.summary_file = self.config.summary_file.replace('_report', '_ATPG_report')
    
    def set(self, file):
        file.write("""##############################################
#                   ATPG                     #
##############################################\n\n""")

        # Read library
        file.write(f"read_netlist {self.config.tech_library}\n")

        # Set up design
        file.write(f"\nread_netlist {self.config.netlist_file}\n\n")

        # Specify top module
        file.write(f"run_build_model {self.config.top_module}\n\n")

        # Run DRC
        file.write(f"run_drc {self.config.spf_file}\n\n")

    def set_atpg(self, file):
        # Set ATPG
        file.write("set_atpg -coverage 100\n")
        
        if self.config.pattern_specification == "partial":
            file.write("set_atpg -fill X\n")
        
        # file.write("set_atpg -decision random\n")
        # self.set_atpg_option(file)
    
    def set_atpg_option(self, file):
        # inheritance
        pass

    def set_fault(self, file):
        # Set fault model
        self.set_fault_option(file)
        
        if self.config.fault_collapsing:
            file.write("set_faults -report collapsed\n") 
        
        file.write("set_faults -fault_coverage\n")
        file.write("set_faults -summary verbose\n\n")
        
    def set_fault_option(self, file):
        # default: Stuck
        file.write("set_faults -model Stuck\n")

    def set_delay_option(self, file):
        pass
        
    def write_output(self, file):
        # Write outputs
        file.write(f"report_summaries\n")
        file.write(f"report_summaries > {self.config.summary_file}\n\n")
        file.write(f"write_faults {self.config.faults_file} -all -replace\n\n")
        file.write(f"write_patterns {self.config.patterns_file} -format STIL -replace\n\n")
        file.write("exit")

    def add_fault(self, file):
        # Add fault list to ATPG
        file.write("add_faults -all\n\n")

    def run_atpg(self, file):
        # Run ATPG
        if self.config.auto_compression:
            file.write(f"run_atpg -auto_compression\n\n") 
        else:
            file.write(f"run_atpg\n\n")

    def generate_tcl(self, output_file):
        with open(output_file, "w") as file:
            self.set(file)
            self.set_atpg(file)
            self.set_fault(file)
            self.set_delay_option(file)
            self.set_atpg_option(file)
            self.add_fault(file)
            self.run_atpg(file)
            self.write_output(file)

class StuckATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        
    def set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model Stuck\n")
    
    def run_atpg(self, file):
        # Run ATPG with n-detect
        if self.config.auto_compression:
            file.write(f"run_atpg -auto_compression -ndetect {self.config.n_detect}\n\n") 
        else:
            file.write(f"run_atpg -ndetect {self.config.n_detect}\n\n")
        
class TransitionATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        if config.capture_cycle == None:
            self.config.capture_cycle = 4
        assert(self.config.capture_cycle >= 2 and self.config.capture_cycle <= 10)
        
    def set_fault_option(self, file):
        file.write("set_faults -model transition\n")
    
    def set_delay_option(self, file):
        file.write(f"set_delay -launch {self.config.launch_cycle}\n\n")
    
    def set_atpg_option(self, file):
        file.write(f"set_atpg -capture {self.config.capture_cycle}\n\n")

class IDDQATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        if config.capture_cycle == None:
            self.config.capture_cycle = 4
        assert(self.config.capture_cycle >= 2 and self.config.capture_cycle <= 10)
        
    def set_fault_option(self, file):
        file.write("set_faults -model iddq\n")
        if self.config.iddq_toggle:
            file.write("set_iddq -toggle\n")
        if self.config.iddq_float is False:
            file.write("set_iddq nofloat\n")
        if self.config.iddq_strong is False:
            file.write("set_iddq nostrong\n")
        file.write(f"set_iddq -interval_size {self.config.iddq_interval_size}\n") 
    
    def set_delay_option(self, file):
        file.write("set_delay -launch system_clock\n\n")
    
    def set_atpg_option(self, file):
        file.write(f"set_atpg -patterns {self.config.iddq_max_patterns}\n\n")

class BridgingATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        # generate node.txt
        os.system(f"python3 gen_bridging_site.py ./Netlist/{self.config.top_module}_dft.v")
        
    def set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model bridging\n")
    
    def add_fault(self, file):
        # override default
        file.write("add_faults -node_file nodes.txt\n\n")
    
    def set_atpg_option(self, file):
        # Set ATPG
        file.write("set_atpg -optimize_bridge_strengths\n")
        file.write("set_atpg -merge high \n")
        
class PathDelayATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        # generate critical paths
        self.writePrimeTimeScript()
        os.system("pt_shell -f pt_path.tcl")
        
    def set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model path_delay\n")
        file.write(f"add_delay_paths {self.config.top_module}_delay.rpt\n\n")
    
    # def set_atpg_option(self, file):
    #     # Set ATPG
    #     file.write("set_atpg -merge high \n")
    
    def writePrimeTimeScript(self):
        with open("pt_path.tcl", "w") as f:
            f.write("remove_design -all\n")
            f.write(f'set search_path ". {self.config.db_library}"\n')
            f.write('set link_path "* typical.db  fast.db  slow.db"\n\n')
            
            f.write(f"read_verilog {self.config.netlist_file}\n")
            f.write(f"link_design {self.config.top_module}\n")
            f.write(f"read_parasitics {self.config.spef_file}\n")
            f.write("set_operating_conditions typical -library typical\n\n")
            
            f.write(f"set CLK_PERIOD {self.config.slack}\n")
            f.write("set CLK CK\n")
            f.write("create_clock -period $CLK_PERIOD [get_ports $CLK]\n")
            f.write("set_clock_transition -rise 0.05 [get_clocks $CLK]\n")
            f.write("set_clock_transition -fall 0.03 [get_clocks $CLK]\n")
            f.write("set_clock_latency -rise 0.01 [get_clocks $CLK]\n")
            f.write("set_clock_latency -fall 0.03 [get_clocks $CLK]\n")
            f.write("set_ideal_network [get_ports CK]\n\n")
            
            f.write("source pt2tmax.tcl\n")
            f.write(f"write_delay_paths -max_paths 200 -nworst 1 -delay_type max ./{self.config.top_module}_delay.rpt\n\n")
            
            f.write("exit")

class HoldTimeATPGScriptGenerator(PathDelayATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
    
    def set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model hold_time\n")
        file.write(f"add_delay_paths {self.config.top_module}_delay.rpt\n\n")

class ExperimentATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
    
    def set_fault_option(self, file):
        file.write(f"set_static {self.config.experiment_static}")
        

if __name__ == "__main__":
    config_file = "../../Python/src/config.txt"
    config = parse_config(config_file)

    output_file = "../../Script/tcl/atpg.tcl"
    
    if config.fault_model == "stuck":
        generator = StuckATPGScriptGenerator(config)
    elif config.fault_model == "transition":
        generator = TransitionATPGScriptGenerator(config)
    elif config.fault_model == "bridging":
        generator = BridgingATPGScriptGenerator(config)
    elif config.fault_model == "iddq":
        generator = IDDQATPGScriptGenerator(config)
    elif config.fault_model == "path_delay":
        generator = PathDelayATPGScriptGenerator(config)
    elif config.fault_model == "hold_time":
        generator = HoldTimeATPGScriptGenerator(config)
    else:
        generator = BaseATPGScriptGenerator(config)
    
    generator.generate_tcl(output_file)

    print(f"TCL script generated successfully: {os.path.abspath(output_file)}")