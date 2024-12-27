##############################################################################
#
#                                tmax2pt.tcl
#                  Copyright (c) 2004-2019 by Synopsys, Inc.
#                            ALL RIGHTS RESERVED
#
#
# This program is proprietary and confidential information of Synopsys, Inc.
# and may be used and disclosed only as authorized in a license agreement
# controlling such use and disclosure.
#
#############################################################################
#
# This Tcl script runs in TetraMAX (R) and creates another Tcl script that
# runs in PrimeTime (R) and configures it to perform timing analysis of a
# design in its atpg/test mode.
#
#############################################################################

# current limitations or unsupported:
# * "Add cell constraints" because cell is not constrained between shifts.
# * "Add slow bidis" is all or nothing: If any are not slow, all are checked.
# * "Set delay -nopo_measures" because it is ignored for transition faults.
# * Sequential capture procedures
# * Delay test with end-of-cycle measure not supported
# * Last-shift cycle different from other shift cycles are not supported.
# * Each clock and port is individually listed, even if there are many
#   with the same waveforms.
# * "set delay -nopi_changes" is pessimistic because the PIs are timed
#   from the beginning of the launch cycle. Removing this pessimism
#   would require a 3rd -wft for the extra unclocked cycle.
# * Constraints in preamble of procedures in the SPF may not be translated
#   properly to set_false_path or set_case_analysis.  This may, for
#   example, time false paths when using end-of-cycle measures.  The user
#   has to specify exceptions manually for this scenario.
# * Internal clocking procedures
# * Loadable nonscan cells where shift simulation is greater than 1
# * DFTMAX Serializer is not supported in shift mode.

echo "Loading tmax2pt.tcl ..."

# the main routine.  use -help option for usage info.
proc write_timing_constraints args {

    set out_file_perm 0644

    set rel_version "P-2019.03"
    set null ""
    set Date ""
    set vc_version "$Date: 2019/01/23 02:04:06 $null"
    append version $rel_version $vc_version

    set pt_script_replace 0
    set debug 0
    set date [date]
    set sta_mode "capture"
    set wft1 "_default_WFT_"
    set wft2 ""
    set number_wft 0
    set ontime_wft2 ""
    set offtime_wft2 ""
    set only_scanouts 0

# list of inter-clock exceptions.  format {type clk1 offstate1 clk2 offstate2}
# type: fp == false_path, mcp == multicycle path, fph == false_path(hold),
#       fp2 == false_path(special two_cycle)
# from clk1 to clk2
    set interclk_excep {}

# whether we are doing a superimposition of 2 clocks per net (launch-
# capture or last_shift).  the "single cycle" notation in the code
# implies the clock waveform only has a single cycle.  the analysis,
# of course, spans multiple cycles.
    set two_cycle 0

# print a header in the output file by default
    set header 1

# default time unit is 1ns
    set timeunit 1

    parse_proc_arguments -args $args results
    set pt_script $results(outfn)
    if {[info exists results(-mode)]} {
	set sta_mode $results(-mode)
    }
    if {[info exists results(-only_constrain_scanouts)]} {
	set only_scanouts 1
    }
    if {[info exists results(-replace)]} {
	set pt_script_replace 1
    }
    if {[info exists results(-unit)]} {
	if { $results(-unit) == "ps" } {
	    set timeunit 1000.0
	}
    }
    if {[info exists results(-wft)]} {
	foreach i $results(-wft) {
	    if { $number_wft == 0 } {
		if {$i == "default" || $i == "launch" || $i == "capture" || $i == "launch_capture"} {
		    set wft1 "_${i}_WFT_"
		} else {
		    set wft1 $i
		}
	    } elseif { $number_wft == 1 } {
		if {$i == "default" || $i == "launch" || $i == "capture" || $i == "launch_capture"} {
		    set wft2 "_${i}_WFT_"
		} else {
		    set wft2 $i
		}
	    } else {
		error "A maximum of 2 wfts can be specified."
	    }
	    incr number_wft
	}
    }
    if {[info exists results(-debug)]} {
	set debug 1
    }
    if {[info exists results(-no_header)]} {
	set header 0
    }

    if {[info exists results(-man)]} {
	echo "
Version: $version
Usage:
write_timing_constraints <output_pt_script_file>
  \[-man\]
  \[-mode shift|capture|last_shift|update\]
  \[-only_constrain_scanouts\]
  \[-replace\]
  \[-wft <wft_name>|default|launch|capture|launch_capture
    \[-wft <wft_name>|default|launch|capture|launch_capture\]\]
  \[-unit ns|ps\]
  \[-debug\]
  \[-no_header\]

  Default mode: $sta_mode
  Default wft_name: $wft1

Options:
 -man
   This help message is displayed.
 -mode <mode_name>
   Specify the mode in which to perform timing analysis.
 -only_constrain_scanouts
   Only set output delay constraints on scanout ports.
   By default, all outputs are constrained. 
   This option is only compatible with -mode shift.
 -replace
   Overwrite output PrimeTime script file if it exists.
 -wft <wft_name>
   Specify the WaveformTable as defined in the STIL protocol file from
   which timing data is gathered.  Well known WFT names can be
   abbreviated as follows if they are defined: default (_default_WFT_),
   launch (_launch_WFT_), capture (_capture_WFT_), launch_capture
   (_launch_capture_WFT_).  This option can be repeated once.
 -unit <unit>
   Specify ps if protocol uses ps. Default is ns.
 -debug
   Write additional debug data into output file. This can be useful
   if you are attempting to modify this script.
 -no_header
   Suppress header information in the output file. This can be useful
   for comparing the results of different versions.

Description:
write_timing_constraint outputs a PrimeTime Tcl script that configures
the design in various ATPG modes for timing analysis.  The output script
can be sourced in a PrimeTime session to analyze test mode timing.  The
constraints will reflect the timing used during ATPG and on the tester.

The mode can be either 'shift', 'capture', 'last_shift' or 'update'.
Shift mode uses the constraints from the load_unload procedure and
configures the design to analyze timing during scan chain shifting.
Capture mode uses constraints from the capture procedures and configures
the design to analyze timing during the capture cycles.
Last_shift mode analyzes the timing of the last shift cycle and the
subsequent capture cycle.  This is normally used for analyzing the
last shift launch transition pattern timing.
Update mode analyzes the timing of the last shift cycle, capture cycle
and first shift cycle to determine the timing of the DFTMAX Ultra
cache registers.

The timing used for the analysis is specified separately from the mode
using the -wft option.  The argument to the -wft option must be a valid
WaveformTable in the STIL Protocol File.  Well known WFT names can be
abbreviated as shown in the usage info above.

The -wft option can be used once or twice.  If two WFTs are specified,
two cycles will be timed.  The first WFT will be used for the first cycle
timing, and the second WFT for the second cycle.  Two cycle analysis
is done by superimposing two cycles, offset by a period, for each clock.

TetraMAX must be started in Tcl mode (tmax -tcl ...) in order to use this
script.  A command like the following will load this procedure.
source \$env(SYNOPSYS)/auxx/syn/tmax/tmax2pt.tcl

Example usage of the -mode and -wft options is below.

To validate shifting:
 -mode shift -wft _slow_WFT_

To validate stuck-at capture cycles:
 -mode capture -wft default

To validate system clock launch capture cycles for transition faults:
 -mode capture -wft launch -wft capture

To validate the timing between shift and capture for transition faults:
 -mode last_shift -wft default -wft _fast_WFT_


Details:
The 'force PI' and 'measure PO' times are relative to virtual clocks
in PrimeTime.  The 'force PI' virtual clock rises at 0, and the
'measure PO' clock falls at the earliest PO measure time.  Input and
output delays are specified relative to these clocks.

For the modes involving two wfts, all the clock ports will have
two superimposed clocks representing the two cycles that need to be
analyzed.

End-of-cycle measures produce cycle times of double the normal cycles
to account for the expansion of vectors into multiple vectors.

The user should carefully review the generated PrimeTime script to ensure
the static timing analysis configuration is as expected.
"
	return
    }

# take default wft
    if {$number_wft == 0} {
        set number_wft 1
    }

# check if all required inputs were supplied
    if {[info exists pt_script]} {
	if {[file exists $pt_script] && !$pt_script_replace} {
	    error "$pt_script exists. Use -replace to overwrite it."
	}
# don't open file for writing until more checks have been completed
    } else {
	error "The output script name needs to be specified."
    }

# for shift or capture modes, use exceptions from first mode/cycle.
# for last_shift, use exceptions from 2nd mode/cycle.

# determine the mode in each cycle.
    if {$sta_mode == "last_shift"} {

	set mode1 "load_unload"
	set mode2 "capture"
	set two_cycle 1

# if last_shift mode, but only one wft is given, assume the same wft for
# both cycles.
	if {$number_wft == 1} {
	    set wft2 $wft1
	}

    } elseif {$sta_mode == "shift"} {
	if {$number_wft != 1} {
	    error "Only one wft can be specified for shift mode."
	}
	redirect -variable serializer_rep { report_serializers -all }
	if {[string length $serializer_rep]} {
	    error "Shift mode is not supported when Serializer is in use; see SolvNet article 035288."
	}

	set mode1 "load_unload"

	set mode2 ""
	set two_cycle 0

    } elseif {$sta_mode == "update"} {
	if {$number_wft != 1} {
	    error "Only one wft can be specified for update mode."
	}
        set sas_cache_regs [get_compressors -sas_cache_reg]
        set spcc_cache_regs [get_compressors -spc_chain_cache_reg]
        if {[sizeof_collection $sas_cache_regs] == 0 && [sizeof_collection $spcc_cache_regs] == 0} {
            error "No cache register cells were found in update mode."
        }

	set mode1 "load_unload"

	set mode2 ""
	set two_cycle 0

    } elseif {$sta_mode == "capture"} {
	set mode1 "capture"

	if {$number_wft == 1} {
	    set mode2 ""
	    set two_cycle 0
	} else {
	    set mode2 "capture"
	    set two_cycle 1
	}

    } else {
	error "invalid mode: $sta_mode"
    }


# go thru all the outputs to get the earliest & latest PO measures
    foreach_in_collection port [add_to_collection [get_cells -type PO] \
    [get_cells -type PIO]] {

	set port_nm [get_attribute $port cell_name]

	set mpo_time1 \
	    [expr [get_attribute [get_timing $port_nm -wft $wft1] measure_time] / $timeunit ]

	if {![info exists min_mpo_time1] || ($mpo_time1 < $min_mpo_time1)} {
	    set min_mpo_time1 $mpo_time1
	}
	if {![info exists max_mpo_time1] || ($mpo_time1 > $max_mpo_time1)} {
	    set max_mpo_time1 $mpo_time1
	}

	if {$two_cycle} {
	    set mpo_time2 \
		[expr [get_attribute [get_timing $port_nm -wft $wft2] measure_time] / $timeunit ]

	    if {![info exists min_mpo_time2] || ($mpo_time2 < $min_mpo_time2)} {
		set min_mpo_time2 $mpo_time2
	    }
	    if {![info exists max_mpo_time2] || ($mpo_time2 > $max_mpo_time2)} {
		set max_mpo_time2 $mpo_time2
	    }
	}

# foreach output port
    }

# if PO measure time is not found, could be a bug.
    if {![info exists min_mpo_time1] || ![info exists max_mpo_time1]} {
      error "Error: did not get PO measure time range."
    }

# go thru the clocks and find earliest/latest edge times and
# clock periods.
    foreach_in_collection clk [get_clocks -all] {


# don't use internal, pll or reference clocks in this analysis
	if {[get_attribute $clk is_internal]} continue
	if {[get_attribute $clk is_pll]} continue
	if {[get_attribute $clk is_reference]} {
	    if {![regexp {shift} [get_attribute $clk usage]]} {
		 continue
	    }
	}

	set clk_nm [get_attribute $clk clock_name]
	set time_obj_wft1 [get_timing $clk_nm -wft $wft1]

# determine period, first time thru for the wfts
	if {![info exists wft1_period]} {
	    set wft1_period [expr [get_attribute $time_obj_wft1 period] / $timeunit ]

	    if {$wft1_period == 0} {
		error "Error: invalid first wft for clk $clk_nm: $wft1"
	    }

	    if {$debug} {
		echo "# clk $clk_nm: period of 1st wft: $wft1_period"
	    }
	}

        if {[string length $wft2]} {
	    set time_obj_wft2 [get_timing $clk_nm -wft $wft2]
	}

# determine period of wft2
	if {![info exists wft2_period]} {
	    if {[string length $wft2]} {
# wft was specified

		set wft2_period [expr [get_attribute $time_obj_wft2 period] / $timeunit ]

		if {$wft2_period == 0} {
		    error "Error: invalid second wft for clk $clk_nm: $wft2"
		}
	    } else {
# wft was not specified
		if {$two_cycle} {
		    set wft2_period $wft1_period
		} else {
		    set wft2_period 0
		}
	    }
	    if {$debug} {
		echo "# clk $clk_nm: period of 2nd wft: $wft2_period"
	    }

	}

	set ontime_wft1 [expr [get_attribute $time_obj_wft1 clkon_time] / $timeunit ]
	set offtime_wft1 [expr [get_attribute $time_obj_wft1 clkoff_time] / $timeunit ]

	if {[string length $wft2]} {
	    set ontime_wft2 [expr [expr [get_attribute $time_obj_wft2 \
		       clkon_time] / $timeunit ] + $wft1_period]
	    set offtime_wft2 [expr [expr [get_attribute $time_obj_wft2 \
			clkoff_time] / $timeunit ] + $wft1_period]
	} elseif {$two_cycle} {
	    set ontime_wft2 $ontime_wft1
	    set offtime_wft2 $offtime_wft1
	}

# find earliest and latest clock edges in both wfts
        if {![info exists min_clk_ontime1] || \
		($ontime_wft1 < $min_clk_ontime1)} {
		set min_clk_ontime1 $ontime_wft1
	}
        if {![info exists max_clk_offtime1] || \
		($offtime_wft1 > $max_clk_offtime1)} {
		set max_clk_offtime1 $offtime_wft1
	}
        if {$two_cycle} {
	    if {![info exists min_clk_ontime2] || \
		    ($ontime_wft2 < $min_clk_ontime2)} {
		set min_clk_ontime2 $ontime_wft2
	    }
	    if {![info exists max_clk_offtime2] || \
		    ($offtime_wft2 > $max_clk_offtime2)} {
		set max_clk_offtime2 $offtime_wft2
	    }
	}

	if {![info exists total_period]} {
# Set artificial window for DFTMAX Ultra update check
	    if {$sta_mode == "update"} {
		set total_period [expr 3 * $wft1_period]
	    } else {
		set total_period [expr $wft1_period + $wft2_period]
	    }
	}

	if {$debug} {
	    echo "# clk $clk_nm: ontime of 1st wft: $ontime_wft1."
            echo "# clk $clk_nm: offtime of 1st wft: $offtime_wft1."
	    if {$two_cycle} {
		echo "# clk $clk_nm: ontime of 2nd wft: $ontime_wft2."
		echo "# clk $clk_nm: offtime of 2nd wft: $offtime_wft2."
	    }
	    echo "# clk $clk_nm: total period: $total_period."
	}

    }

# determine the measure position in the cycle
   if {$max_mpo_time1 > $min_clk_ontime1} {
       if {$min_mpo_time1 > $max_clk_offtime1} {
	   if {$two_cycle} {
	       error "delay test with end of cycle measures are not supported"
	   }
	   set eoc_measure 1

# double the period for end-of-cycle measure
	   if {$sta_mode == "capture"} {
	       set total_period [expr 2 * $total_period]
	   }

       } else {
	   error "all measure times must be either before all clock edges or after all clock edges."
       }
    } else {
        set eoc_measure 0

    }


    set fh [open $pt_script w $out_file_perm]

    if {$header} {
	puts $fh "
# PrimeTime (R) Tcl script created by tmax2pt.tcl
# Creation time: $date
# tmax2pt.tcl version: $version
# arguments: $args
"
    }

    if {$debug} {
	puts $fh "# output PrimeTime script: $pt_script"
	puts $fh "# mode: $sta_mode"
	puts $fh "# wft1: $wft1, wft2: $wft2"
	puts $fh "# minimum measure time for wft1: $min_mpo_time1."
	puts $fh "# maximum measure time for wft1: $max_mpo_time1."
	if {$two_cycle} {
	    puts $fh "# minimum measure time for wft2: $min_mpo_time2."
	    puts $fh "# maximum measure time for wft2: $max_mpo_time2."
	}
	puts $fh "# earliest clk edge time for wft1: $min_clk_ontime1"
	puts $fh "# latest clk edge time for wft1: $max_clk_offtime1"
	if {$two_cycle} {
	    puts $fh "# earliest clk edge time for wft2: $min_clk_ontime2"
	    puts $fh "# latest clk edge time for wft2: $max_clk_offtime2"
	}
    }

# miscellaneous PT settings to initialize analysis.
    puts $fh {
# Note: any existing constraints or exceptions may invalidate those
# here.  Uncomment the following to reset everything except the linked
# design.
# reset_design

set timing_enable_preset_clear_arcs true

    }

# Check whether all bidis are slow
    set all_slow_bidi 1
    foreach_in_collection port [get_cells -type PIO] {
	if {![get_attribute $port is_slow]} {
	    set all_slow_bidi 0
	    break
	}
    }
    if {$all_slow_bidi==0} {
	puts $fh "# add_slow_bidi -all was not used, so enable inout paths:"
	puts $fh "set timing_disable_internal_inout_cell_paths false"
	puts $fh "set timing_disable_internal_inout_net_arcs false"
    }

# if following var is set, we don't need to worry about inter-domain
# clock crossings with delay test patterns.
# "set delay -common_launch_capture" setting either does no clock
# grouping or does it for clock pairs that have no interaction.
     set no_inter_clk_path [expr {\
     [get_attribute [filter_collection [get_settings delay] \
 	command_type==common_launch_capture_clock] value] == "true"}]

    puts $fh ""
    puts $fh "# clocks"
    puts $fh "suppress_message UITE-210"
# get a list of clocks and set up 
    foreach_in_collection clk [get_clocks -all] {



	set clk_nm [get_attribute $clk clock_name]

# internal and pll clocks have no timing so dummy timing must be assigned
	if {[get_attribute $clk is_internal] || [get_attribute $clk is_pll]} {
	    set ontime_wft1 45
	    set offtime_wft1 55
	    set ontime_wft2 [expr $ontime_wft1 + $wft1_period]
	    set offtime_wft2 [expr $offtime_wft1 + $wft1_period]
	} else {
	    set time_obj_wft1 [get_timing $clk_nm -wft $wft1]

            if {[string length $wft2]} {
		set time_obj_wft2 [get_timing $clk_nm -wft $wft2]
	    }

	    set ontime_wft1 [expr [get_attribute $time_obj_wft1 clkon_time] / $timeunit ]
	    set offtime_wft1 [expr [get_attribute $time_obj_wft1 clkoff_time] / $timeunit ]

# invalid pulse-width.  skip this.
            if {$ontime_wft1 == $offtime_wft1} continue

# for end-of-cycle measures in capture cycles, push the clocks one cycle out.
	    if {$eoc_measure && ($sta_mode == "capture")} {
		set ontime_wft1 [expr $ontime_wft1 + $wft1_period]
		set offtime_wft1 [expr $offtime_wft1 + $wft1_period]
	    }

	    if {[string length $wft2]} {
		set ontime_wft2 [expr [expr [get_attribute $time_obj_wft2 \
		       clkon_time] / $timeunit] + $wft1_period]
		set offtime_wft2 [expr [expr [get_attribute $time_obj_wft2 \
			clkoff_time] / $timeunit] + $wft1_period]
# invalid pulse-width.  skip this.
		if {$ontime_wft2 == $offtime_wft2} continue

	    } elseif {$two_cycle} {
		set ontime_wft2 $ontime_wft1
		set offtime_wft2 $offtime_wft1
	    }
# end extra check for internal and pll clock timing assignment
	}


# edge order for create_clock: rise, fall
# rtz clock: edge order for create_clock: on, off
# rto clock: edge order for create_clock: off, on
# if return-to-one (rto) clocks, the rise time comes 2nd, in the next cycle.
	set off_state [get_attribute $clk off_state]
	if {$off_state == "HI"} {
# rto clock
	    set off_state_num 1
	    if {$two_cycle!=1} {
		set new_ontime_wft1 [expr $ontime_wft1 + $wft1_period]
	        set wft1_edges "$offtime_wft1 $new_ontime_wft1"
	    }
# rto 2-cycle has 1 edge for wft1 and 3 for wft2 here
# generated clocks will pick the correct set of edges
	    if {$two_cycle} {
		set wft1_edges "$offtime_wft1"
		set new_offtime_wft1 [expr $ontime_wft1 + $total_period]
		set wft2_edges "$ontime_wft2 $offtime_wft2 $new_offtime_wft1"
		set wft1_mid_edge 4
		set wft2_mid_edge 6
	    }
	} elseif  {$off_state == "LO"} {
# rtz clock
	    set off_state_num 0
	    set wft1_edges "$ontime_wft1 $offtime_wft1"
	    if {$two_cycle} {
		set wft2_edges "$ontime_wft2 $offtime_wft2"
		set wft1_mid_edge 2
		set wft2_mid_edge 4
	    }
	} else {
	    puts $fh "Error: invalid off state for clk $clk_nm"
	    close $fh
	    error "Error: invalid off state for clk $clk_nm"
	}

	if {$debug} {
	    puts $fh "# clk $clk_nm. off state: $off_state."
	}

# create clocks
# nonvirtual clocks that have a create_clock statement
# inhibit generation of exceptions for pll clocks
	if {![get_attribute $clk is_pll]} {
	    set pt_clocks(${clk_nm}_wft1) 1
	}

	if {[get_attribute $clk is_reference]} {
# reference clocks are free running with their own period
	    if {$sta_mode == "update"} {
		set ref_period [expr 3 * [get_attribute $time_obj_wft1 period] / $timeunit ]
		puts $fh "echo \"TMAX2PT WARNING: Free-running clock $clk_nm defined in update mode.\""
		puts $fh "echo \"Timing checks will be valid to and from cache cells, but do not use this script for other checks.\""
	    } else {
		set ref_period [expr [get_attribute $time_obj_wft1 period] / $timeunit ]
	    }
	    puts $fh "create_clock -name ${clk_nm}_wft1 -period \
	    $ref_period -waveform { $wft1_edges } \[get_ports $clk_nm\]"
	} elseif {[get_attribute $clk is_pll]} {
	    if {$sta_mode == "update"} {
		puts $fh "# PLL source [get_attribute $clk pll_pin_name] is not used for update mode checks."
		continue
	    }
	    set pllclkpinnm [get_attribute $clk pll_pin_name]
	    puts $fh "echo \"TMAX2PT WARNING: PLL source $pllclkpinnm timing is defaulted.\""
	    puts $fh "echo \"Adjust this timing to correct values before checking.\""
	    puts $fh "create_clock -name ${clk_nm}_wft1 -period \
	    $wft1_period -waveform { $wft1_edges } \[get_pins $pllclkpinnm\]"
	} elseif {$two_cycle!=1} {
	    if {[get_attribute $clk is_internal]} {
# internal clocks should not be defined for shift mode
		if {$sta_mode == "shift" || $sta_mode == "update"} {
		    puts $fh "# Internal clock [get_attribute $clk clock_name] is not used for shift."
		    continue
		}
# internal clocks must use a cell output, not the TMAX clock name
		foreach_in_collection clkpin [get_attribute [get_instance \
		[get_attribute $clk clock_name] ] pins] {
		    if {[get_attribute $clkpin direction] == "OUT"} {
			set clkpinnm [get_attribute $clkpin pin_pathname]
		    }
		}
		puts $fh "echo \"TMAX2PT WARNING: Internal clock $clkpinnm timing is defaulted.\""
		puts $fh "echo \"Adjust this timing to correct values before checking.\""
		puts $fh "create_clock -name ${clk_nm}_wft1 -period \
		$total_period -waveform { $wft1_edges } $clkpinnm"
	    } else {
# external clocks single-cycle
		if {[get_attribute [get_cells $clk_nm] ${mode1}_constraint] == $off_state_num} {
		    puts $fh "# Clock $clk_nm is constrained off, so no create_clock command is printed for it."
		    continue
		} else {
		    puts $fh "create_clock -name ${clk_nm}_wft1 -period $total_period -waveform { $wft1_edges } \[get_ports $clk_nm\]"
		}
	    }
	} else {
# two-cycle capture
	    if {[get_attribute $clk is_internal]} {
# internal clocks must use a cell output, not the TMAX clock name
		foreach_in_collection clkpin [get_attribute [get_instance \
		[get_attribute $clk clock_name] ] pins] {
		    if {[get_attribute $clkpin direction] == "OUT"} {
			set clkpinnm [get_attribute $clkpin pin_pathname]
		    }
		}
		puts $fh "echo \"TMAX2PT WARNING: Internal clock $clkpinnm timing is defaulted.\""
		puts $fh "echo \"Adjust this timing to correct values before checking.\""

		puts $fh "create_clock -name ${clk_nm}_master -period \
		$total_period -waveform { $wft1_edges $wft2_edges } \
		$clkpinnm"

		puts $fh "create_generated_clock -name ${clk_nm}_wft1 -edges \
		{ 1 $wft1_mid_edge 5 } -source $clkpinnm \
		$clkpinnm -add -master_clock ${clk_nm}_master"

		puts $fh "create_generated_clock -name ${clk_nm}_wft2 -edges \
		{ 3 $wft2_mid_edge 7 } -source $clkpinnm \
		$clkpinnm -add -master_clock ${clk_nm}_master"

	    } else {
# external clocks two-cycle
		set mode1_constr [get_attribute [get_cells $clk_nm] ${mode1}_constraint]
		set mode2_constr [get_attribute [get_cells $clk_nm] ${mode2}_constraint]
		if {$mode1_constr == $mode2_constr && $mode1_constr == $off_state_num} {
		    puts $fh "# Clock $clk_nm is constrained off, so no create_clock command is printed for it."
		    continue
		} else {
		    puts $fh "create_clock -name ${clk_nm}_master -period $total_period -waveform { $wft1_edges $wft2_edges } \[get_ports $clk_nm\]"

		    puts $fh "create_generated_clock -name ${clk_nm}_wft1 -edges { 1 $wft1_mid_edge 5 } -source \[get_ports $clk_nm\] \[get_ports $clk_nm\] -add -master_clock ${clk_nm}_master"

		    puts $fh "create_generated_clock -name ${clk_nm}_wft2 -edges { 3 $wft2_mid_edge 7 } -source \[get_ports $clk_nm\] \[get_ports $clk_nm\] -add -master_clock ${clk_nm}_master"

		}
	    }

	    puts $fh "# These set_clock_latency commands prevent UIT-461 errors."
	    puts $fh "set_clock_latency -source 0.0 \[get_clocks ${clk_nm}_wft1\]"
	    puts $fh "set_clock_latency -source 0.0 \[get_clocks ${clk_nm}_wft2\]"

	    puts $fh "# Allow timing checks only between generated clocks."
	    puts $fh "set_false_path -from \[get_clocks ${clk_nm}_master\]"
	    puts $fh "set_false_path -to \[get_clocks ${clk_nm}_master\]"

	    set pt_clocks(${clk_nm}_wft2) 1
	}


# exceptions during capture, in either last_shift & capture, or system
# clock launch & capture.
	if {$sta_mode != "shift"} {

	    foreach_in_collection other_clk [add_to_collection \
				   [get_attribute $clk ungroupable_clocks] \
				   [get_attribute $clk disturbed_clocks]] {



		set clk_nm2 [get_attribute $other_clk clock_name]

		set oth_time_wft1 [get_timing $clk_nm2 -wft $wft1]

		set off_state2 [get_attribute $other_clk off_state]

		if {![get_attribute $other_clk is_internal]} {
		    set clk2_ontime_wft1 [expr [get_attribute $oth_time_wft1  clkon_time] / $timeunit ]
		    set clk2_offtime_wft1 [expr [get_attribute $oth_time_wft1 clkoff_time] / $timeunit ]
		}


		if {$two_cycle} {
		    if {![get_attribute $other_clk is_internal]} {
			set clk2_ontime_wft2 [expr [expr [get_attribute $oth_time_wft1 \
			    clkon_time] / $timeunit ] + $wft1_period]
			set clk2_offtime_wft2 [expr [expr [get_attribute $oth_time_wft1 \
			     clkoff_time] / $timeunit ] + $wft1_period]
		    }
		}

		if {$debug} {
		    puts $fh "# ungrouped/disturbed clocks: $clk_nm, $clk_nm2."
		}

# do first cycle
		if {$two_cycle} {

# with parallel clocking relationships between clk1 and clk2, we
# time clk1_wft1 -> clk2_wft1, clk1_wft1 -> clk2_wft2 &
# clk1_wft2 -> clk2_wft2.  (clk1_wft2 -> clk2_wft1 exception
# is below.)  however, this section of code is for ungrouped/disturbed
# clock pairs.  we are really only timing paths between wft1 -> wft2
# (ungrouped clocks can be pulsed in adjacent cycles, but not in the same;
# disturbed clocks can be pulsed in the same cycle, but the receiver is
#  masked, so we don't need to time that).  we don't care about paths going
# from clk1_wft1 -> clk2_wft1 and clk1_wft2 -> clk2_wft2 since these clocks
# cannot be pulsed together in the same cycle, or if they are, the capture
# is masked.

		    lappend interclk_excep [list fp ${clk_nm}_wft1 $off_state \
						${clk_nm2}_wft1 $off_state2]
		    lappend interclk_excep [list fp ${clk_nm}_wft2 $off_state \
						${clk_nm2}_wft2 $off_state2]

# false path the capture cycles
		    if {$no_inter_clk_path} {

# no inter-domain paths need to be timed for delay test, which deal
# with adjacent cycles.
			lappend interclk_excep [list fp ${clk_nm}_wft1 $off_state \
						    ${clk_nm2}_wft2 $off_state2]

		    }
		} elseif {$sta_mode == "capture"} {
# single cycle capture

# false path on hold only, between ungroupable or disturbed domains.
		    lappend interclk_excep [list fph ${clk_nm}_wft1 $off_state \
						    ${clk_nm2}_wft1 $off_state2]

# check if there is an early to late relationship, and set mcp for set-up
# internal clocks are always disturbed, so skip them
		    if {![get_attribute $other_clk is_internal]} {
			if { $ontime_wft1 < $clk2_ontime_wft1 || \
			     $offtime_wft1 < $clk2_offtime_wft1} {
			    lappend interclk_excep [list mcp ${clk_nm}_wft1 $off_state \
						    ${clk_nm2}_wft1 $off_state2]
			}
		    }
		}

# foreach other clocks
	    }

# if not shift
	}

# set false paths between same clock; 2 cycle cases will never
# see the same cycle sequentially.
        if {$two_cycle} {
	    lappend interclk_excep [list fp2 ${clk_nm}_wft1 $off_state ${clk_nm}_wft1 $off_state]
	    lappend interclk_excep [list fp2 ${clk_nm}_wft2 $off_state ${clk_nm}_wft2 $off_state]
	}

# foreach clock
    }
    puts $fh "unsuppress_message UITE-210"


    puts $fh {
# Note: uncomment any of the following sections as appropriate.
#
## pre-layout design
#set clock_delay 0
#set_clock_latency $clock_delay [all_clocks]
#
## post-layout design
#set_propagated_clock [all_clocks]
#
#set intra_clock_skew 0
#set inter_clock_skew 0
#set_clock_uncertainty $intra_clock_skew [all_clocks]
#foreach_in_collection from_clock [all_clocks] {
#  foreach_in_collection to_clock [all_clocks] {
#    if {[get_attribute $from_clock full_name] !=
#        [get_attribute $to_clock full_name]} {
#      set_clock_uncertainty $inter_clock_skew -from $from_clock -to $to_clock
#    }
#  }
#}
    }

# output clock domain exceptions, after clock definitions above.
    if {[llength $interclk_excep]} {
        puts $fh ""
        puts $fh "# clock domain exceptions"
    }

    foreach excep $interclk_excep {
        if {[string length excep] == 0} continue

        set excep_type [lindex $excep 0]
        set clk1 [lindex $excep 1]
        set offstate1 [lindex $excep 2]
        set clk2 [lindex $excep 3]
        set offstate2 [lindex $excep 4]

# only print out true clocks here
        if {[llength [array names pt_clocks -exact $clk1]] == 0 ||
	    [llength [array names pt_clocks -exact $clk2]] == 0} {
	    continue
	}

        if {$excep_type == "fph"} {
# false path for hold only, but also multicycle for LE-TE paths
	    puts $fh "set_false_path -hold -from \
                    \[get_clocks $clk1 \] -to \[get_clocks $clk2 \]"
# edge1 is leading edge of clk1
	    if {$offstate1 == "HI"} {
		set edge1 fall
	    } else {
		set edge1 rise
	    }
# edge2 is trailing edge of clk2
	    if {$offstate2 == "HI"} {
		set edge2 rise
	    } else {
		set edge2 fall
	    }
	    puts $fh "set_multicycle_path -setup 2 -${edge1}_from \
                    \[get_clocks $clk1 \] -${edge2}_to \[get_clocks $clk2 \]"
        } elseif {$excep_type == "fp"} {
# false path
	    puts $fh "set_false_path -from \[get_clocks $clk1 \] \
                    -to \[get_clocks $clk2 \]"
        } elseif {$excep_type == "fp2"} {
# false path between same pulse of same clock - setup only (same edges)
# plus TE-LE - only valid paths are holds plus LE-TE
	    if {$offstate1 == "HI"} {
		set edge1 rise
		set edge2 fall
	    } else {
		set edge1 fall
		set edge2 rise
	    }
	    puts $fh "set_false_path -setup -${edge1}_from \
		    \[get_clocks $clk1 \] -${edge1}_to \[get_clocks $clk1 \]"
	    puts $fh "set_false_path -setup -${edge2}_from \
		    \[get_clocks $clk1 \] -${edge2}_to \[get_clocks $clk1 \]"
	    puts $fh "set_false_path -${edge1}_from \
		    \[get_clocks $clk1 \] -${edge2}_to \[get_clocks $clk1 \]"
        } elseif {$excep_type == "mcp"} {
# multicycle path
	    puts $fh "set_multicycle_path -setup 2 -from \
              \[get_clocks $clk1 \] -to \[get_clocks $clk2 \]"
        } else {
	    puts $fh "Error: unrecognized exception type: $excep_type."
	    close $fh
	    error "Error: unrecognized exception type: $excep_type."
        }
    }


    puts $fh ""
    puts $fh "# virtual clocks for PI, PO & PIO events"
    puts $fh "suppress_message UITE-121"

# create virtual clocks for PI and PO.
# use the rising edge of this clock for all references
    puts $fh "create_clock -name forcePI_wft1 -period $total_period \
    -waveform { 0 [expr 1 / $timeunit ] } "

# use the falling edge of this clock for all references.
    set po_meas_wft1 $min_mpo_time1
    puts $fh "create_clock -name measurePO_wft1 -period $total_period \
    -waveform { 0 $po_meas_wft1 } "

    if {$two_cycle} {

       set wft1_period_plus1 [expr $wft1_period + [expr 1 / $timeunit ] ]
# use the rising edge of this clock for all references
	puts $fh "create_clock -name forcePI_wft2 -period $total_period \
        -waveform { $wft1_period $wft1_period_plus1 } "

# use the falling edge of this clock for all references.
	set po_meas_wft2 [expr $wft1_period + $min_mpo_time2]
	puts $fh "create_clock -name measurePO_wft2 -period $total_period \
       -waveform { 0 $po_meas_wft2 } "
    }
    puts $fh "unsuppress_message UITE-121"


# if scan-in ports are constrained during load_unload, ignore it.  keep
# a list of scan-in ports.
    if { [get_compressors -load_data_ports] == "" } {
	if {$debug} {
	    puts $fh "# Getting scan-in ports from get_scan_chains."
	}
	foreach_in_collection chn [get_scan_chains -all] {
	    set scan_in_pins([get_attribute $chn input_pin]) 1
	}
    } else {
	if {$debug} {
	    puts $fh "# Getting scan-in ports from get_compressors."
	}
	foreach_in_collection ldp [get_compressors -load_data_ports] {
	    set scan_in_pins([get_attribute $ldp port_name]) 1
	}
	foreach_in_collection lmp [get_compressors -load_mode_ports] {
	    set scan_in_pins([get_attribute $lmp port_name]) 1
	}
    }

    puts $fh ""
    puts $fh "# PI & PIO settings"

# get nonclock port timing from appropriate wft and apply.
    foreach_in_collection port [add_to_collection [get_cells -type PI] \
				    [get_cells -type PIO]] {

	set port_nm [get_attribute $port cell_name]

# skip reference clocks entirely because they have false ATPG constraints
	if {[get_attribute $port is_clock]} {
	    if {[get_attribute [get_clocks $port_nm] is_reference]} {
		continue
	    }
	}

# false_paths and set_case_analysis for this port
	set mode1_constr [get_attribute $port ${mode1}_constraint]

# only generate constraints for non-scan-in ports.
        if {[llength [array names scan_in_pins -exact $port_nm]] == 0} {

	    if {$two_cycle} {

# set_case_analysis if two_cycle and the constraints are same in both
# modes.
		set mode2_constr [get_attribute $port ${mode2}_constraint]

		if {$debug} {
		    puts $fh \
			"# port: $port_nm: 2nd mode constraint: $mode2_constr."
		}

# apply false_path in 2nd cycle if 2nd cycle's constraint is X/Z
		if {$mode2_constr == "X" || $mode2_constr == "Z"} {
# X constraint
		    if {$mode1_constr == $mode2_constr} {
# 2-cycle capture, or last_shift with X/Z constraint in both cycles.  apply
# false_path in both cycles.

			puts $fh "set_false_path -from \[get_ports $port_nm\]"
# Skip input delay time for false-path inputs
			continue
		    } else {
# if constraints are different, must be last_shift.
# since different across cycles, false_path only in 2nd cycle (capture).

			puts $fh "set_false_path \
                        -rise_from \[get_clocks forcePI_wft2\] \
                        -through \[get_ports $port_nm\]"
		    }

		} else {
# 2-cycles, and constraints are not X/Z

		    if {[string length $mode1_constr] && \
			    $mode1_constr == $mode2_constr} {

			puts $fh "set_case_analysis $mode1_constr \
                        \[get_ports $port_nm\]"
# Skip input delay time for case-analysis inputs
			continue
		    }
		}
	    } elseif {$sta_mode == "update"} {
# Update mode is a special case because scan enable is defined as a clock
		set mode1_constr [get_attribute $port load_unload_constraint]
		set mode2_constr [get_attribute $port capture_constraint]
		if {$mode1_constr == "X" || $mode1_constr == "Z"} {
		    if {$mode1_constr == $mode2_constr} {
			puts $fh "set_false_path -from \[get_ports $port_nm\]"
# Skip input delay time for false-path inputs
			continue
		    }
		} elseif {[string length $mode1_constr]} {
		    if {$mode1_constr == $mode2_constr} {
			puts $fh "set_case_analysis $mode1_constr \[get_ports $port_nm\]"
# Skip input delay time for case-analysis inputs
			continue
		    } elseif {$mode1_constr == "1" && $mode2_constr == "0"} {
# Active-high scan enable, must be constrained for DFTMAX Ultra
			set update_edges "[expr 2 * $wft1_period] [expr 4 * $wft1_period]"
			puts $fh "create_clock -name ${port_nm}_wft1 -period $total_period -waveform { $update_edges } \[get_ports $port_nm\]"
# Skip input delay time for clock inputs
			continue
		    } elseif {$mode1_constr == "0" && $mode2_constr == "1"} {
# Active-low scan enable, must be constrained for DFTMAX Ultra
			set update_edges "$wft1_period [expr 2 * $wft1_period]"
			puts $fh "create_clock -name ${port_nm}_wft1 -period $total_period -waveform { $update_edges } \[get_ports $port_nm\]"
# Skip input delay time for clock inputs
			continue
		    }
		}
	    } else {
# single cycle

# apply set_case_analysis in single cycle mode for PI in capture or shift.
		set constr [get_attribute $port ${mode1}_constraint]

		if {$debug} {
		    puts $fh "# port: $port_nm: 1st mode constraint: $constr."
		}

		if {[string length $constr]} {
		    if {$constr == "X" || $constr == "Z"} {
			puts $fh "set_false_path -from \[get_ports $port_nm\]"
		    } else {
			puts $fh \
			    "set_case_analysis $constr \[get_ports $port_nm\]"
		    }
# Skip input delay time for false-path and case-analysis inputs
		    continue
		}
	    }

# if not scan-in port
	}

# skip real clocks
        set not_clock 1

	if {[get_attribute $port is_clock]} {

# do timing for resets
	    set clk_usage [get_attribute [get_clocks $port_nm] usage]
	    if {[regexp {set} $clk_usage]} {
		set not_clock 0
	    } else {
		continue
	    }
	}

# apply input delays, regardless of constraints, etc.
	set fpi_time1 \
	    [expr [get_attribute [get_timing $port_nm -wft $wft1] force_time] / $timeunit ]
        if {$not_clock} {
	    puts $fh \
		"set_input_delay $fpi_time1 -clock forcePI_wft1 \
                \[get_ports $port_nm\]"
	}

	if {$debug} {
	    puts $fh "# port: $port_nm: force PI time in wft1: $fpi_time1."
	}

	if {$two_cycle} {
	    set fpi_time2 \
		[expr [get_attribute \
			   [get_timing $port_nm -wft $wft2] force_time] / $timeunit ]

	    set input_delay2 [expr $wft1_period + $fpi_time2]
	    if {$not_clock} {
		puts $fh "set_input_delay -add_delay $fpi_time2 \
                -clock forcePI_wft2 \[get_ports $port_nm\]"
	    }
	    if {$debug} {
		puts $fh "# port: $port_nm: force PI time in wft2: $fpi_time2."
	    }

	}

# foreach input port
    }

    puts $fh ""
    puts $fh "# PO and PIO settings"

    if {$only_scanouts} {
	if {$sta_mode != "shift"} {
	    puts $fh "# -only_constrain_scanouts was specified with -mode $sta_mode."
	    puts $fh "# Ignoring -only_constrain_scanouts specification."
	    echo "TMAX2PT WARNING: -only_constrain_scanouts specified with -mode $sta_mode."
	    echo "Ignoring -only_constrain_scanouts specification."
	    set only_scanouts 0
	}
# Get scan-out ports from external chains from get_scan_chains
	foreach_in_collection chn [get_scan_chains -all] {
	    set scan_out_pins([get_attribute $chn output_pin]) 1
	}
# Get scan-out ports from compressors (if applicable) from get_compressors
	foreach_in_collection udp [get_compressors -unload_data_ports] {
	    set scan_out_pins([get_attribute $udp port_name]) 1
	}
    }

# go thru all the outputs
    foreach_in_collection port [add_to_collection [get_cells -type PO] \
    [get_cells -type PIO]] {

	set port_nm [get_attribute $port cell_name]

	if {$only_scanouts} {
	    if {[llength [array names scan_out_pins -exact $port_nm]] == 0} {
		continue
	    }
	}

# apply output delays, regardless of constraints, etc.
	set mpo_time1 \
	    [expr [get_attribute [get_timing $port_nm -wft $wft1] measure_time] / $timeunit ]

	if {$debug} {
	    puts $fh "# port $port_nm: measure PO time of 1st wft: $mpo_time1."
	}

# compute time from po measure time to measure time.
	set out_delay1 [expr $mpo_time1 - $po_meas_wft1]
	if {$out_delay1 >0} {
	    set out_delay1 "-$out_delay1"
	}

	puts $fh \
	    "set_output_delay $out_delay1 -clock measurePO_wft1 \
            \[get_ports $port_nm\] -clock_fall"

	if {$two_cycle} {


	    set mpo_time2 \
		[expr [get_attribute [get_timing $port_nm -wft $wft2] measure_time] / $timeunit ]

	    if {$debug} {
		puts $fh "# port $port_nm: measure PO time of 2nd wft: $mpo_time2."
	    }

	    set out_delay2 [expr $mpo_time2 - $min_mpo_time2]
	    if {$out_delay2 >0} {
		set out_delay2 "-$out_delay2"
	    }

	    puts $fh "set_output_delay -add_delay $out_delay2 \
                -clock measurePO_wft2 \[get_ports $port_nm\] -clock_fall"

# false_path to all masked POs in 2nd cycle
	    if {[get_attribute $port is_masked]} {
		if {$sta_mode == "last_shift"} {
		    puts $fh "set_false_path \
		    -through \[get_ports $port_nm\] \
                    -fall_to \[get_clocks measurePO_wft2\]"
		} elseif {$sta_mode == "capture"} {
		    puts $fh "set_false_path -to \[get_ports $port_nm\]"
		} else {
		    puts $fh "Error: script error.  sta_mode=$sta_mode."
		    close $fh
		    error "Error: script error.  sta_mode=$sta_mode."
		}
	    }

	} elseif {$sta_mode == "capture"} {
# single cycle capture mode

# false_path masked POs in capture cycle
	    if {[get_attribute $port is_masked]} {
		puts $fh "set_false_path -to \[get_ports $port_nm\]"
	    }
	}


# foreach output port
    }



    puts $fh ""
    puts $fh "# -nopi_changes"

# set_delay -nopi_changes
    if {[get_attribute [filter_collection [get_settings delay] \
			    command_type==pi_changes] value] == "false"} {

        if {$two_cycle && ($sta_mode == "capture")} {
# PIs don't change for system clock launch, between launch and capture.
	    puts $fh "set_false_path -rise_from forcePI_wft2 \
            -to \[get_clocks *_wft2\]"
	}
    }

    puts $fh ""
    puts $fh "# black_boxes, and empty_boxes"

    set all_boxes [add_to_collection  [get_instances -type black_box] \
		   [get_instances -type empty_box]]

    if {[sizeof_collection $all_boxes] > 0} {
        puts $fh "suppress_message UITE-216"
    }
    foreach_in_collection inst $all_boxes {
	set inst_nm [get_attribute $inst instance_name]
	puts $fh "set_false_path -through \[get_cells $inst_nm\]"



	puts $fh "set_false_path -to \[get_cells $inst_nm\]"
	puts $fh "set_false_path -from \[get_cells $inst_nm\]"

    }
    if {[sizeof_collection $all_boxes] > 0} {
        puts $fh "unsuppress_message UITE-216"
    }


# in shift mode, don't check hold time to memories and nonscan cells.
# but exclude compressor pipeline cells from the set_false_path list.

# Set pindata to find clock gating cells
    set_pindata -shift

    puts $fh ""
    puts $fh "# nonscan sequential elements "
    foreach_in_collection cell [remove_from_collection [remove_from_collection \
    [remove_from_collection [remove_from_collection \
    [remove_from_collection [remove_from_collection \
    [add_to_collection [get_cells -nonscan] [get_cells -type MEMORY]] \
    [get_compressors -load_pipeline]] [get_compressors -unload_pipeline]] \
    [get_compressors -sas_serial_load_reg]] [get_compressors -sas_cache_reg]] \
    [get_compressors -sas_serial_unload_reg]] [get_compressors -spc_chain_cache_reg]] {

# exclude loadable nonscan cells
	if {[get_attribute $cell is_load]} continue
# exclude lockup latches using attribute added in J-2014.09
	if {[get_attribute $cell is_trailing_lockup]} continue
	if {[get_attribute $cell scan_type] == "SCANTLA"} continue

	set inst_nm [get_attribute $cell cell_name]

# false path to nonscan devices during shift.  from handled by case_analysis
# of scan-enable.
	if {$sta_mode == "shift"} {
	    puts $fh "set_false_path -to \[get_cells $inst_nm]"
	} elseif {$sta_mode == "last_shift"} {

# false_path to the nonscan cells during first cycle
	    puts $fh "set_false_path -from \[get_clocks *_wft1\] \
                    -to \[get_cells $inst_nm\]"

# false_path from the nonscan cells to other cells clocked in first cycle
	    puts $fh "set_false_path -from \[get_cells $inst_nm\]"

# if last_shift mode
	}

# case analysis for constant value nonscan cells during all modes.
	set constr [get_attribute $cell nonscan_behavior]
	if {[regexp {C[01]} $constr]} {

# Valid in capture mode, but shift and last_shift need additional check.
	    set sh_beh [get_attribute $cell load_unload_behav]
	    if {$sta_mode == "capture" || $sh_beh == "STABLE_HI" || $sh_beh == "STABLE_LO"} {

# find the pin with the constraint
		foreach_in_collection pin [get_attribute $cell pins] {

		    if {[get_attribute $pin direction] == "IN"} continue

		    set c_val [get_attribute $pin constraint_data]

		    regexp {.*,([01])/.*,} $c_val unused c_val
		    if {$c_val == "0" || $c_val == "1"} {
# If 01 is in the shift pindata, this is a probable clock gating cell
			if {$sta_mode == "shift" && [regexp {01} [get_attribute $pin pin_data]] } continue
			set pin_nm [get_attribute $pin pin_pathname]
			puts $fh "set_case_analysis $c_val $pin_nm"
		    }
		}
	    }

# if nonscan_behavior
	}

# foreach nonscan cell
    }

# Tail pipeline is masked for scan out, so don't check in capture mode
    if {$sta_mode == "capture" && [sizeof_collection [get_compressors -unload_pipeline]] > 0} {
	puts $fh ""
	puts $fh "# tail pipeline cells (capture mode only)"
	foreach_in_collection cell [get_compressors -unload_pipeline] {
	    puts $fh "set_false_path -to \[get_cells [get_attribute $cell cell_name]]"
	}
    }

    puts $fh ""
    puts $fh "# masked scan cells"

# sequential cells with masking.
    foreach_in_collection cell [add_to_collection [get_cells -type DFF] \
				[get_cells -type DLAT]] {
        set inst_nm [get_attribute $cell cell_name]

	set is_masked [get_attribute $cell is_masked]
	set is_slow   [get_attribute $cell is_slow]


	if {$is_masked} {
	    if {$sta_mode == "capture"} {
# both 1 & 2 cycle cases
		puts $fh "set_false_path -to \[get_cells $inst_nm\]"
		puts $fh "set_false_path -through \[get_cells $inst_nm\]"
	    } elseif {$sta_mode == "last_shift"} {
# need to mask paths through d pin of cell in 2nd cycle.
# need to find input data pin in PT since tmax doesn't know it.
		puts $fh "set_false_path -through \[get_pins \
                    $inst_nm/* -filter {is_data_pin == true}\] \
                    -to \[get_clocks *_wft2\]"
	    }
	}
	if {$is_slow && $two_cycle} {
# slow cells work for LOS but not for stuck-at
	    puts $fh "set_false_path -from \[get_cells $inst_nm\]"
	}
    }

# if mode is capture, with two wfts, need to set false paths from
# 2nd cycle back to the 1st.
    if {$sta_mode == "capture" && $two_cycle} {
        puts $fh ""
        puts $fh "# false path from capture cycle back to launch"
        puts $fh "set_false_path -from \[get_clocks *_wft2\] \
        -to \[get_clocks *_wft1\]"
        puts $fh "set_false_path -hold -from \[get_clocks *_wft1\] \
        -to \[get_clocks *_wft2\]"
        puts $fh "set_false_path -from \[get_clocks forcePI_wft1\] \
        -to \[get_clocks *_wft2\]"
    }

# Define variable for update mode:
    if {$sta_mode == "update"} {

# sas_cache_regs is already defined just after parsing the arguments
	if {[sizeof_collection $sas_cache_regs] > 0} {
	    puts $fh ""
	    puts $fh "# Define variable for update mode"
	    puts $fh "set dftmax_ultra_cache_cells \[list \\"
	    foreach_in_collection cell $sas_cache_regs {
		puts $fh "[get_attribute $cell cell_name] \\"
	    }
	    puts $fh "\]"
	    puts $fh ""
	    puts $fh "echo \"TMAX2PT INFO: Use variable dftmax_ultra_cache_cells for update-mode STA.\""
	    puts $fh "echo \"Separate checks should be made -to and -from \\\$dftmax_ultra_cache_cells.\""
	}

# spcc_cache_regs is already defined just after parsing the arguments
	if {[sizeof_collection $spcc_cache_regs] > 0} {
	    puts $fh ""
	    puts $fh "# Define variable for SPCC update mode"
	    puts $fh "set spcc_cache_cells \[list \\"
	    foreach_in_collection cell $spcc_cache_regs {
		puts $fh "[get_attribute $cell cell_name] \\"
	    }
	    puts $fh "\]"
	    puts $fh ""
	    puts $fh "echo \"TMAX2PT INFO: Use variable spcc_cache_cells for update-mode STA.\""
	    puts $fh "echo \"Separate checks should be made -to and -from \\\$spcc_cache_cells.\""
	}

    }

    close $fh
}

define_proc_attributes write_timing_constraints \
    -info "Writes timing constraints for post-DRC test mode." \
    -define_args { \
        { outfn "Name of PrimeTime script file" <output_filename> string required } \
        { -man "Print man page and return" "" boolean optional } \
        { -mode "Mode in which to perform the timing analysis" <sta_mode> one_of_string { "optional" "value_help" "values { shift capture last_shift update }" } } \
        { -only_constrain_scanouts "Reduce number of constrained ports" "" boolean optional } \
        { -replace "Overwrite existing output file" "" boolean optional } \
        { -unit "Time unit of SPF file" <time_unit> one_of_string { "optional" "value_help" "values { ns ps }" } } \
        { -wft "WaveformTable to be used" <wft_name> string { "optional" "merge_duplicates" } } \
        { -debug "Print debug info" "" boolean optional } \
        { -no_header "Suppress header in output file" "" boolean optional } \
    }
