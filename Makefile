###############################################################
# File       [ Makefile ]                                     #
# Author     [ Testing123 ]                                   #
# Date       [ 2024/12/13 created ]                           #
###############################################################

# Makefile for running TCL files using tmax

# Add more TCL files to this variable in the future
# To run new files:
# 1. Add them to the TCL_FILES list above.
# 2. Re-execute `make run`.

# Define the default TCL files to run (excluding dft_dc.tcl which runs separately)
DFT_TCL := dft_dc.tcl
ATPG_TCL := atpg.tcl
FAULT_SIM_TCL := faultsim.tcl

# Command for executing TCL files
TMAX := tmax -shell -tcl
DCSHELL := dc_shell -f

# Default target: run dft_dc.tcl first, then other TCL files
.PHONY: all clean gentcl scinsert atpg faultsim
all: gentcl scinsert atpg faultsim

# Add error checking for critical commands
gentcl: dft.py atpg.py faultsim.py
	@echo "Generating tcl files..."
	@python3 dft.py || (echo "Error generating dft.tcl"; exit 1)
	@python3 atpg.py || (echo "Error generating atpg.tcl"; exit 1)
	@python3 faultsim.py || (echo "Error generating faultsim.tcl"; exit 1)

# Rule to execute dft_dc.tcl with dc_shell
scinsert: $(DFT_TCL)
	@echo "Scan Insertion: Running dft_dc.tcl with dc_shell..."
	@$(DCSHELL) $<
# Rule to execute atpg.tcl with tmax
atpg: $(ATPG_TCL)
	@echo "ATPG: Running atpg.tcl with tmax..."
	@$(TMAX) $<

# Rule to execute faultsim.tcl with tmax 
faultsim: $(FAULT_SIM_TCL)
	@echo "Fault Simulation: Running faultsim.tcl with tmax..."
	@$(TMAX) $<

# Clean up generated files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	@rm -f *.run *.tcl