import configparser
from typing import Optional

# [ DEFAULT ] 
# top_module = s1423
# netlist_file = ./Netlist/s1423_dft.v
# tech_library =  /home/raid7_2/course/cvsd/CBDK_IC_Contest_v2.5/Verilog/tsmc13_neg.v
# synthesized_files = ../Test_s1423/Netlist/s1423_syn.v
# spf_file = ../Test_s1423/Netlist/s1423.spf
# faults_file = ../Test_s1423/Netlist/s1423.fault
# summary_file = ../Test_s1423/Netlist/s1423_ATPG_report.rpt
# patterns_file = ../Test_s1423/Netlist/s1423.stil

# [SCAN_CHAIN_INSERT]
# # supported scan chain type: <multiplexed_flip_flop | clocked_scan | lssd | aux_clock_lssd | combinational | or none>
# scan_style = multiplexed_flip_flop
# num_scan_chain = 8

# # detect scan chain fault
# [ SCAN_CHAIN_FAULT ]
# scan_fault_detect = false

# # supoorted fault types: stuck, transition, iddq, iddq_bridging, path_delay, hold_time, bridging, dynamic_bridging, dual_transition_bridging
# [ FAULT_TYPES ]
# fault_model = transition

# [ PATTERN_OPTIONS ]
# pattern_specification = full
# fault_collapsing = true

# [ TRANSITION_FAULT_OPTIONS ]
# launch_cycle = any
# capture_cycle = 2
# MUXClock_mode = false

# [ ATPG_GENERAL_OPTIONS ]
# auto_compression = true
# # optional: remove p% faults
# remove_fault = 50

# [SIMULATION_OPTION]
# simulation_sequential = true
# simulation_sequential_nodrop = false

class Config:
    def __init__(self, 
                 top_module: str,
                 netlist_file: str,
                 tech_library: str, 
                 synthesized_files: str, 
                 spf_file: str, 
                 faults_file: str, 
                 summary_file: str, 
                 patterns_file: str,
                 scan_style: str,
                 num_scan_chain: int,
                 scan_fault_detect: bool, 
                 fault_model: str, 
                 pattern_specification: str, 
                 fault_collapsing: bool,  # Changed from Optional[bool]
                 launch_cycle: Optional[str],
                 capture_cycle: Optional[int],
                 MUXClock_mode: bool,     # Changed from Optional[int]
                 auto_compression: bool,   # Changed from Optional[int]
                 remove_fault: Optional[int],
                 simulation_sequential: bool,
                 simulation_sequential_nodrop: bool):
        self.top_module = top_module
        self.netlist_file = netlist_file
        self.tech_library = tech_library
        self.synthesized_files = synthesized_files
        self.spf_file = spf_file
        self.faults_file = faults_file
        self.summary_file = summary_file
        self.patterns_file = patterns_file
        self.scan_style = scan_style
        self.num_scan_chain = num_scan_chain
        self.scan_fault_detect = scan_fault_detect
        self.fault_model = fault_model
        self.pattern_specification = pattern_specification
        self.fault_collapsing = fault_collapsing
        self.launch_cycle = launch_cycle
        self.capture_cycle = capture_cycle
        self.MUXClock_mode = MUXClock_mode
        self.auto_compression = auto_compression
        self.remove_fault = remove_fault
        self.simulation_sequential = simulation_sequential
        self.simulation_sequential_nodrop = simulation_sequential_nodrop

    def __repr__(self):
        return (f"ATPGConfig(top_module={self.top_module}, netlist_file={self.netlist_file}, tech_library={self.tech_library}, "
                f"synthesized_files={self.synthesized_files}, spf_file={self.spf_file}, "
                f"faults_file={self.faults_file}, summary_file={self.summary_file}, "
                f"patterns_file={self.patterns_file}, scan_style={self.scan_style}, "
                f"num_scan_chain={self.num_scan_chain}, scan_fault_detect={self.scan_fault_detect}, "
                f"fault_model={self.fault_model}, pattern_specification={self.pattern_specification}, "
                f"launch_cycle={self.launch_cycle}, capture_cycle={self.capture_cycle}, "
                f"MUXClock_mode={self.MUXClock_mode}, fault_collapsing={self.fault_collapsing}, "
                f"auto_compression={self.auto_compression}, remove_fault={self.remove_fault}, "
                f"simulation_sequential={self.simulation_sequential}, simulation_sequential_nodrop={self.simulation_sequential_nodrop})")

def parse_config(file_path: str) -> Config:
    config = configparser.ConfigParser()
    config.read(file_path)

    def parse_bool(value: Optional[str]) -> bool:
        return value.lower() == 'true' if value else False

    def parse_optional_int(value: Optional[str]) -> Optional[int]:
        return int(value) if value and value.isdigit() else None

    # Get all required sections
    default_section = config["DEFAULT"]
    scan_chain_section = config["SCAN_CHAIN_INSERT"]
    scan_fault_section = config["SCAN_CHAIN_FAULT"]
    fault_types_section = config["FAULT_TYPES"]
    pattern_section = config["PATTERN_OPTIONS"]
    transition_section = config["TRANSITION_FAULT_OPTIONS"]
    general_section = config["ATPG_GENERAL_OPTIONS"]
    simulation_section = config["SIMULATION_OPTION"]

    return Config(
        # DEFAULT section
        top_module=default_section.get("top_module", ""),
        netlist_file=default_section.get("netlist_file", ""),
        tech_library=default_section.get("tech_library", ""),
        synthesized_files=default_section.get("synthesized_files", ""),
        spf_file=default_section.get("spf_file", ""),
        faults_file=default_section.get("faults_file", ""),
        summary_file=default_section.get("summary_file", ""),
        patterns_file=default_section.get("patterns_file", ""),
        
        # SCAN_CHAIN_INSERT section
        scan_style=scan_chain_section.get("scan_style", "multiplexed_flip_flop"),
        num_scan_chain=int(scan_chain_section.get("num_scan_chain", "8")),
        
        # SCAN_CHAIN_FAULT section
        scan_fault_detect=parse_bool(scan_fault_section.get("scan_fault_detect")),
        
        # FAULT_TYPES section
        fault_model=fault_types_section.get("fault_model", ""),
        
        # PATTERN_OPTIONS section
        pattern_specification=pattern_section.get("pattern_specification", ""),
        fault_collapsing=parse_bool(pattern_section.get("fault_collapsing")),
        
        # TRANSITION_FAULT_OPTIONS section
        launch_cycle=transition_section.get("launch_cycle", "any"),
        capture_cycle=parse_optional_int(transition_section.get("capture_cycle", "4")),
        MUXClock_mode=parse_bool(transition_section.get("MUXClock_mode")),
        
        # ATPG_GENERAL_OPTIONS section
        auto_compression=parse_bool(general_section.get("auto_compression")),
        remove_fault=parse_optional_int(general_section.get("remove_fault")),

        # SIMULATION_OPTION section
        simulation_sequential=parse_bool(simulation_section.get("simulation_sequential")),
        simulation_sequential_nodrop=parse_bool(simulation_section.get("simulation_sequential_nodrop"))
    )

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Parse ATPG configuration from TXT file.")
    parser.add_argument("file_path", type=str, help="Path to the configuration file.")
    args = parser.parse_args()

    config = parse_config(args.file_path)
    print(config)