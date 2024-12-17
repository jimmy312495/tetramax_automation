import os
from atpg_parser import ATPGConfig, parse_config

class BaseATPGScriptGenerator:
    def __init__(self, config: ATPGConfig):
        self.config = config
    
    def write_set(self, file):
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

    def write_set_atpg(self, file):
        # Set ATPG
        file.write("set_atpg -coverage 100\n")
        
        if self.config.pattern_specification == "partial":
            file.write("set_atpg -fill X\n")
        
        file.write("set_atpg -decision random\n")
        self.write_set_atpg_option(file)
    
    def write_set_atpg_option(self, file):
        # inheritance
        pass

    def write_set_fault(self, file):
        # Set fault model
        self.write_set_fault_option(file)
        
        if self.config.fault_collapsing:
            file.write("set_faults -report collapsed\n") 
        
        file.write("set_faults -fault_coverage\n")
        file.write("set_faults -summary verbose\n\n")
        
    def write_set_fault_option(self, file):
        # default: Stuck
        file.write("set_faults -model Stuck\n")

    def write_set_delay_option(self, file):
        pass
        
    def write_output(self, file):
        # Write outputs
        file.write(f"report_summaries > {self.config.summary_file}\n\n")
        file.write(f"write_faults {self.config.faults_file} -all -replace\n\n")
        file.write(f"write_patterns {self.config.patterns_file} -format STIL -replace\n\n")
        file.write("exit")

    def write_add_fault(self, file):
        # Add fault list to ATPG
        file.write("add_faults -all\n\n")

    def write_run_atpg(self, file):
        # Run ATPG
        if self.config.auto_compression:
            file.write("run_atpg -auto_compression\n\n") 
        else:
            file.write("run_atpg\n\n")

    def generate_tcl(self, output_file):
        with open(output_file, "w") as file:
            self.write_set(file)
            self.write_set_atpg(file)
            self.write_set_fault(file)
            self.write_set_delay_option(file)
            self.write_add_fault(file)
            self.write_run_atpg(file)
            self.write_output(file)

class StuckATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: ATPGConfig):
        super().__init__(config)
        
    def write_set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model Stuck\n")
        
class TransitionATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: ATPGConfig):
        super().__init__(config)
        if config.capture_cycle == None:
            self.config.capture_cycle = 4
        assert(self.config.capture_cycle >= 2 and self.config.capture_cycle <= 10)
        
    def write_set_fault_option(self, file):
        file.write("set_faults -model transition\n")
    
    def write_set_delay_option(self, file):
        file.write("set_delay -launch system_clock\n\n")
    
    def write_set_atpg_option(self, file):
        file.write(f"set_atpg -capture {self.config.capture_cycle}\n\n")
        
class BridgingATPGScriptGenerator(BaseATPGScriptGenerator):
    def __init__(self, config: ATPGConfig):
        super().__init__(config)
        
    def write_set_fault_option(self, file):
        # Set fault model
        file.write("set_faults -model transition\n")
    
    def write_add_fault(self, file):
        # override default
        file.write("add_faults -node_file nodes.txt \n\n")
    
    def write_set_atpg_option(self, file):
        # Set ATPG
        file.write("set_atpg -merge high \n")


if __name__ == "__main__":
    config_file = "define.txt"
    config = parse_config(config_file)

    output_file = "atpg.tcl"
    
    if config.fault_model == "stuck":
        generator = StuckATPGScriptGenerator(config)
    elif config.fault_model == "transition":
        generator = TransitionATPGScriptGenerator(config)
    elif config.fault_model == "bridging":
        generator = BridgingATPGScriptGenerator(config)
    else:
        generator = BaseATPGScriptGenerator(config)
        
    generator.generate_tcl(output_file)

    print(f"TCL script generated successfully: {os.path.abspath(output_file)}")