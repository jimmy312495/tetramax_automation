import os
from config_parser import Config, parse_config

class BaseFaultSimScriptGenerator:
    def __init__(self, config: Config):
        self.config = config
        self.config.summary_file = self.config.summary_file.replace('_report', '_FS_report')
    
    def read_netlist_model(self, file):
        file.write("""##############################################
#                 FaultSim                   #
##############################################\n\n""")

        # Read library
        file.write(f"read_netlist {self.config.tech_library}\n")

        # Set up design
        file.write(f"\nread_netlist {self.config.netlist_file}\n\n")

        # Specify top module
        file.write(f"run_build_model {self.config.top_module}\n\n")
        
    def add_clock_constraints(self, file):
        file.write("add_clocks 0 CK\n")
        file.write("add_pi_constraint 0 test_se\n\n")

    def run_drc(self, file):
        file.write(f"run_drc {self.config.spf_file}\n\n")

    def set_pattern(self, file):
        # Set external pattern
        file.write(f"set_patterns -external {self.config.patterns_file}\n")
        self.set_pattern_option(file)
    
    def set_pattern_option(self, file):
        # inheritance
        pass
    
    def read_fault(self, file):
        file.write(f"read_faults {self.config.faults_file}\n") 

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
        file.write("exit")

    def add_fault(self, file):
        # Add fault list to ATPG
        file.write("add_faults -all\n\n")
        
    def set_atpg_option(self, file):
        # inheritance
        pass

    def run_simulation(self, file):
        file.write("set_simulation -measure pat\n")
        file.write("run_simulation -sequential\n\n")
        
    def run_fault_sim(self, file):
        file.write("run_fault_sim")
        if self.config.simulation_sequential:
            file.write(" -sequential")
        if self.config.simulation_sequential_nodrop:
            file.write(" -sequential_nodrop")
        file.write("\n\n")

    def generate_tcl(self, output_file):
        with open(output_file, "w") as file:
            self.read_netlist_model(file)
            self.add_clock_constraints(file)
            self.run_drc(file)
            self.set_fault(file)
            self.read_fault(file)
            self.set_pattern(file)
            self.set_delay_option(file)
            self.set_atpg_option(file)
            self.add_fault(file)
            self.run_simulation(file)
            self.run_fault_sim(file)
            self.write_output(file)

class StuckFaultSimScriptGenerator(BaseFaultSimScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        
    def set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model Stuck\n")
        
class TransitionFaultSimScriptGenerator(BaseFaultSimScriptGenerator):
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

class IDDQFaultSimScriptGenerator(BaseFaultSimScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        if config.capture_cycle == None:
            self.config.capture_cycle = 4
        assert(self.config.capture_cycle >= 2 and self.config.capture_cycle <= 10)
        
    def set_fault_option(self, file):
        file.write("set_faults -model IDDQ\n")
    
    def set_delay_option(self, file):
        file.write(f"set_delay -launch {self.config.launch_cycle}\n\n")
    
    def set_atpg_option(self, file):
        file.write(f"set_atpg -patterns {self.config.iddq_max_patterns}\n\n")
  
class BridgingFaultSimScriptGenerator(BaseFaultSimScriptGenerator):
    def __init__(self, config: Config):
        super().__init__(config)
        
    def set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model bridging\n")
    
    def add_fault(self, file):
        # override default
        file.write("add_faults -node_file nodes.txt \n\n")


if __name__ == "__main__":
    config_file = "config.txt"
    config = parse_config(config_file)

    output_file = "faultsim.tcl"
    
    if config.fault_model == "stuck":
        generator = StuckFaultSimScriptGenerator(config)
    elif config.fault_model == "transition":
        generator = TransitionFaultSimScriptGenerator(config)
    elif config.fault_model == "bridging":
        generator = BridgingFaultSimScriptGenerator(config)
    else:
        generator = BaseFaultSimScriptGenerator(config)
        
    generator.generate_tcl(output_file)

    print(f"TCL script generated successfully: {os.path.abspath(output_file)}")