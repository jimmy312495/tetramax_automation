#########################################################################
#
#                                  pt2tmax
#                  Copyright (c) 1998-2021 by Synopsys, Inc.
#                             ALL RIGHTS RESERVED
#
#
# This program is proprietary and confidential information of Synopsys, Inc.
# and may be used and disclosed only as authorized in a license agreement
# controlling such use and disclosure.
#
##########################################################################

##########################################################################
#
# Tcl script to write critical paths from PrimeTime in the Tetramax format
# for path delay test.
#
##########################################################################

proc write_delay_paths {args} {

  global timing_enable_preset_clear_arcs

  set version "S-2021.06-SP1"

  set max_paths_use 0 
  set launch_clock_use 0
  set capture_clock_use 0
  set IO_use 0
  set each_use 0
  set zstate_use 1
  set group_use 0
  set net_use 0
  set cell_use 0

  set max_paths 1
  set paths_per 1
  set launch_clock "*"
  set capture_clock "*"
  set thru_pin "*"
  set delay_type max

  set crit_slack 1000000
  set pba_mode none

  parse_proc_arguments -args $args results
  set outfile $results(outfn)
  if {[info exists results(-capture)]} {
    set capture_clock $results(-capture)
    set capture_clock_use 1
  }
  if {[info exists results(-launch)]} {
    set launch_clock $results(-launch)
    set launch_clock_use 1
  }
  if {[info exists results(-clock)]} {
    if {$capture_clock_use == 1 || $launch_clock_use == 1} {
      error "-clock cannot be specified with either -launch or -capture"
    }
    set launch_clock $results(-clock)
    set capture_clock $results(-clock)
    set launch_clock_use 1
    set capture_clock_use 1
  }
  if {[info exists results(-cell)]} {
    set thru_pin $results(-cell)
    set cell_use 1
  }
  if {[info exists results(-net)]} {
    if {$cell_use == 1} {
      error "-cell and -net cannot be specified together"
    }
    set thru_pin $results(-net)
    set net_use 1
  }
  if {[info exists results(-delay_type)]} {
    set delay_type $results(-delay_type)
  }
  if {[info exists results(-IO)]} {
    if {$capture_clock_use == 1 || $launch_clock_use == 1} {
      error "-IO cannot be specified with -clock, -launch or -capture"
    }
    set IO_use 1
  }
  if {[info exists results(-each)]} {
    if {$IO_use == 0} {
      error "-each cannot be specified without -IO"
    }
    if {$cell_use == 1 || $net_use == 1} {
      error "-each cannot be specified with -cell or -net"
    }
    set each_use 1
  }
  if {[info exists results(-group)]} {
    if {$capture_clock_use == 1 || $launch_clock_use == 1} {
      error "-group cannot be specified with -clock, -launch or -capture"
    }
    if {$IO_use == 1} {
      error "-group cannot be specified with -IO"
    }
    set grouplist $results(-group)
    set group_use 1
  }
  if {[info exists results(-max_paths)]} {
    set max_paths $results(-max_paths)
    set max_paths_use 1
  }
  if {[info exists results(-noZ)]} {
    set zstate_use 0
  }
  if {[info exists results(-nworst)]} {
    set paths_per $results(-nworst)
  }
  if {[info exists results(-pba)]} {
    set pba_mode exhaustive
  }
  if {[info exists results(-slack)]} {
    set crit_slack $results(-slack)
  }
  if {[info exists results(-version)]} {
    echo "pt2tmax Version $version\n"
    return
  }
  if {[info exists results(-man)]} {
    echo "
Usage: write_delay_paths \[-capture <clock_name>\] \[-cell <pin_name>\]
    \[-clock <clock_name>\] \[-delay_type <max|min>\] \[-each\]
    \[-group <group_name>\] \[-IO\] \[-launch <clock_name>\] \[-man\]
    \[-max_paths <num_paths>\] \[-net <pin_name>\] \[-noZ\]
    \[-nworst <num_per>\] \[-pba\] \[-slack <crit_time>\] \[-version\]
    <output_filename>

Select paths for delay fault test generation and write them in TetraMAX delay path format.

    -capture <clock_name>
        Select paths ending at the <clock_name> clock domain.
        The -capture option is incompatible with the -clock, -group and -IO options.
    -cell <pin_name>
        Select path(s) for each input of cell connected to <pin_name>.
        The -cell option is incompatible with the -each and -net options.
    -clock <clock_name>
        Select paths within the <clock_name> clock domain.
        The -clock option is incompatible with the -capture, -group, -IO and -launch options.
    -delay_type <max|min>
        Use max (default) to get delay paths, use min to get hold paths.
    -each
        Select path(s) for each I/O. The -IO option must also be specified.
        The -each option is incompatible with the -cell and -net options.
    -group <group_name>
        Select paths from existing <group_name>. A list may be supplied.
        When multiple group names are provided, -max_paths is applied separately to each group.
        The -group option is incompatible with the -capture, -clock, -IO and -launch options.
    -IO
        Select I/O paths. By default only internal paths are written.
        The -IO option is incompatible with the -capture, -clock, -group and -launch options.
    -launch <clock_name>
        Select paths starting from the <clock_name> clock domain.
        The -launch option is incompatible with the -clock, -group and -IO options.
    -man
        Print this help message and return.
    -max_paths <num_paths>
        Specify the maximum number of paths to be written (default is 1).
    -net <pin_name>
        Select path(s) for each fanout connected to <pin_name>.
        The -net option is incompatible with the -cell and -each options.
    -noZ
        Suppress paths through three state enables.
    -nworst <num_per>
        Specify the number of paths to each endpoint  (default is 1).
    -pba
        Use exhaustive path based analysis for path selection.
    -slack <crit_time>
        Only select paths with slack less than <crit_time> (default is large).
    -version
        Display current version.
"
    return
  }

  if {$max_paths_use == 1} {
    if {[expr $each_use + $net_use + $cell_use] > 0} {
	echo "Warning: \"-max_paths\" is ignored with \"-each\", \"-net\" or \"-cell\". The \"-nworst\" setting is applied to both paths per endpoint and total paths."
    }
  }


  if {$group_use == 0} {
    remove_path_group -all
    update_timing
    if {$IO_use == 1} {
      set group1 "IO"
    } elseif {[expr $launch_clock_use + $capture_clock_use] > 0} {
      set group1 $launch_clock
      append group1 "-"
      append group1 $capture_clock
      group_path -name $group1 -from [get_clocks $launch_clock] -to [get_clocks $capture_clock]
    } else {
      set group1 "internal"
      group_path -name internal -from [all_clocks] -to [all_clocks]
    }
    group_path -name IO -from [all_inputs]
    group_path -name IO -to [all_outputs]
    foreach_in_collection clock [all_clocks] {
      set clk_ports [get_ports -quiet [get_attribute -quiet $clock sources]]
      if {[sizeof_collection $clk_ports] > 0} {
        group_path -name **clock** -from $clk_ports
      }
    }
    if {$timing_enable_preset_clear_arcs == "true"} {
      set async_pins [get_pins -quiet -filter "is_async_pin == true" -hierarchical *]
      if {[sizeof_collection $async_pins] > 0} {
        #set_disable_timing $async_pins
        group_path -name **clock** -from [all_clocks] -through $async_pins -to [all_clocks]
        group_path -name **clock** -from [all_inputs] -through $async_pins
        group_path -name **clock** -through $async_pins -to [all_outputs]
      }
    }
    if {$zstate_use == 0} {
      set zstate_pins [get_pins -quiet -filter "is_three_state_enable_pin == true" -hierarchical *]
      if {[sizeof_collection $zstate_pins] > 0} {
        #set_disable_timing $zstate_pins
        group_path -name **zstate** -from [all_clocks] -through $zstate_pins -to [all_clocks]
        group_path -name **zstate** -from [all_inputs] -through $zstate_pins
        group_path -name **zstate** -through $zstate_pins -to [all_outputs]
      }
    }
  }
  update_timing
  check_timing


  set OUT [open $outfile w]
  puts $OUT ""
  puts $OUT "// pt2tmax"
  puts $OUT "// Version $version"
  puts $OUT ""

if {$group_use == 0} {
  set grouplist $group1
}
foreach group $grouplist {
  set path_num 0
  if {$each_use == 1} {
    set inputs [all_inputs]
    set input_cnt [sizeof_collection $inputs]
    set outputs [all_outputs]
    set path_items [add_to_collection $inputs $outputs]
  } elseif {$net_use == 1} {
    set path_items [get_pins -filter "direction == in" -leaf -of_objects [get_nets -of_objects $thru_pin]]
  } elseif {$cell_use == 1} {
    set path_items [get_pins -filter "direction == in" -of_objects [get_cells -of_objects $thru_pin]]
  } else {
    set path_items [get_path_groups $group]
  }
  foreach_in_collection item $path_items {
    if {[get_attribute $item object_class] == "path_group"} {
	  set crit_paths [get_timing_paths -group $item \
					   -delay_type $delay_type \
					   -slack_lesser_than $crit_slack \
					   -max_paths $max_paths \
					   -nworst $paths_per \
					   -unique_pins \
					   -pba_mode $pba_mode ]
    } elseif {[get_attribute $item object_class] == "port"} {
      if {$input_cnt > 0} {
	  set crit_paths [get_timing_paths -from $item \
					   -delay_type $delay_type \
					   -slack_lesser_than $crit_slack \
					   -max_paths $paths_per \
					   -nworst $paths_per \
					   -unique_pins \
					   -pba_mode $pba_mode ]
      } else {
	  set crit_paths [get_timing_paths -to $item \
					   -delay_type $delay_type \
					   -slack_lesser_than $crit_slack \
					   -max_paths $paths_per \
					   -nworst $paths_per \
					   -unique_pins \
					   -pba_mode $pba_mode ]
      }
      set input_cnt [expr $input_cnt - 1]
    } elseif {[get_attribute $item object_class] == "pin"} {
	  set crit_paths [get_timing_paths -through $item \
					   -delay_type $delay_type \
					   -slack_lesser_than $crit_slack \
					   -max_paths $paths_per \
					   -nworst $paths_per \
					   -unique_pins \
					   -pba_mode $pba_mode ]
    }

    foreach_in_collection path $crit_paths {
      set path_group [get_attribute -quiet $path path_group]
      if {$path_group == ""} {
        # ports/pins without timing paths
        continue
      }
      if {[get_object_name $path_group] != $group} {
        # paths in another timing group
        continue
      }
      set path_pins [get_attribute $path points]
      if {$delay_type == "min" || [sizeof_collection $path_pins] < 4} {
        # paths without combinational cells cause P10 without special care
        # hold_time ATPG requires driving cell output to prevent M763
        set short_path 1
      } else {
        set short_path 0
      }
      set start [get_attribute $path startpoint]
      set end [get_attribute $path endpoint]
      set slack [get_attribute $path slack]
      set lent [get_attribute -quiet $path time_lent_to_startpoint]
      set borrowed [get_attribute -quiet $path time_borrowed_from_endpoint]

      if {[get_attribute $start object_class] == "port"} {
        set start_point $start
        set start_time [get_attribute -quiet $path startpoint_input_delay_value]
        if {$start_time == ""} {
          # paths from clock ports
          continue
        }
        set start_clk ""
        set start_edge ""
      } else {
        set start_point [get_cells -of_objects $start]
        set start_time [get_attribute -quiet $path startpoint_clock_open_edge_value]
        set start_clk [get_attribute $path startpoint_clock]
        set start_edge [get_attribute $path startpoint_clock_open_edge_type]
      }
      if {[get_attribute $end object_class] == "port"} {
        set end_point $end
        # output paths do not have start/end times
        set required [get_attribute $path required]
        set start_time ""
        set end_time ""
        set end_clk ""
        set end_edge ""
      } else {
        set end_point [get_cells -of_objects $end]
        set end_time [get_attribute $path endpoint_clock_close_edge_value]
        set required "Inf"
        set end_clk [get_attribute $path endpoint_clock]
        set end_edge [get_attribute $path endpoint_clock_close_edge_type]
      }

      set path_num [expr $path_num + 1]
      puts $OUT "\$path \{"
      puts $OUT "  // from: [get_object_name $start_point]"
      puts $OUT "  // to: [get_object_name $end_point]"
      puts $OUT "  \$name \"${group}_${path_num}\" ;"

      if {$start_time != ""} {
        puts $OUT "  \$cycle [expr $end_time - $start_time] ;"
      } else {
        if {$required != "Inf"} {
          puts $OUT "  \$cycle $required ;"
        }
      }
      if {$slack != "Inf"} {
        if {$lent > 0} {
          if {$borrowed > 0} {
            puts $OUT "  \$slack $slack ; // (lent $lent) // (borrowed $borrowed)"
          } else {
            puts $OUT "  \$slack $slack ; // (lent $lent)"
          }
        } elseif {$borrowed > 0} {
          puts $OUT "  \$slack $slack ; // (borrowed $borrowed)"
        } else {
          puts $OUT "  \$slack $slack ;"
        }
      } else {
        puts $OUT ""
      }

      if {$start_clk != ""} {
        set clk_ports [get_ports -quiet [get_attribute -quiet $start_clk sources]]
        if {[sizeof_collection $clk_ports] == 1} {
          puts $OUT "  \$launch \"[get_object_name $clk_ports]\" ; // ($start_edge edge)"
        }
      }
      if {$end_clk != ""} {
        set clk_ports [get_ports -quiet [get_attribute -quiet $end_clk sources]]
        if {[sizeof_collection $clk_ports] == 1} {
          puts $OUT "  \$capture \"[get_object_name $clk_ports]\" ; // ($end_edge edge)"
        }
      }

      puts $OUT "  \$transition \{"
      set pin_num 0
      set start_pin "true"

      foreach_in_collection point $path_pins {
        set pin [get_attribute $point object]
        set pin_num [expr $pin_num + 1]
        set direction [get_attribute $pin direction]
        if {$pin_num < 2} {
          # source cell input pins cause P6/P5 error
          # input ports for short IO paths must be printed to avoid P10
          if {$short_path == 0 || [get_attribute -quiet $pin is_port] == "false"} {
            continue
          }
        }
        if {$direction == "inout"} {
          if {$start_pin == "false"} {
            if {[get_attribute -quiet $pin is_port] == "false"} {
              # intermediate inout pins cause P5 error
              continue
            }
          }
        } elseif {$direction != "in" && $short_path == 0} {
          # output pins are redundant in path list
          continue
        } 
        set start_pin "false"

        if { [get_attribute $pin object_class] != "port"  } {
          if {[get_attribute $point rise_fall] == "rise"} {
            puts $OUT "    \"[get_object_name $pin]\" ^ ; // ([get_attribute -quiet [get_cells -of_objects $pin] ref_name])"
          } else {
            puts $OUT "    \"[get_object_name $pin]\" v ; // ([get_attribute -quiet [get_cells -of_objects $pin] ref_name])"
          }
        } else {
          if {[get_attribute $point rise_fall] == "rise"} {
            puts $OUT "    \"[get_object_name $pin]\" ^ ; // ([get_object_name $pin])"
          } else {
            puts $OUT "    \"[get_object_name $pin]\" v ; // ([get_object_name $pin])"
          }
        }
      }
      puts $OUT "  \}"
      puts $OUT "\}"
      puts $OUT ""
    }
  }
}
  close $OUT
}

define_proc_attributes write_delay_paths \
    -info "Writes delay paths in TetraMAX delay path file format." \
    -define_args { \
	{ outfn "Name of delay path file" <output_filename> string required } \
	{ -capture "Select paths ending at specified clock domain" <clock_name> string optional } \
	{ -cell "Select paths for each input of cell" <pin_name> string optional } \
	{ -clock "Select paths within specified clock domain" <clock_name> string optional } \
	{ -delay_type "Delay type for timing analysis" <type> one_of_string { "optional" "value_help" "values { max min }" } } \
	{ -each "Select paths for each I/O" "" boolean optional } \
	{ -group "Select paths from existing path group" <group_name> list optional } \
	{ -IO "Select I/O paths" "" boolean optional } \
	{ -launch "Select paths starting from specified clock domain" <clock_name> string optional } \
	{ -man "Print man page and return" "" boolean optional } \
	{ -max_paths "Number of paths to be written" <num_paths> int optional } \
	{ -net "Select paths for each fanout of net" <pin_name> string optional } \
	{ -noZ "Suppress paths through 3-state enables" "" boolean optional } \
	{ -nworst "Number of paths for each endpoint" <num_per> int optional } \
	{ -pba "Use path-based analysis" "" boolean optional } \
	{ -slack "Select paths with lesser slack" <crit_time> float optional } \
	{ -version "Display current version" "" boolean optional } \
    }


##########################################################################
#
# Tcl script to convert PrimeTime timing violations to timing exceptions.
#
##########################################################################

proc write_exceptions_from_violations {args} {
	set version "S-2021.06-SP1"
	set output tmax_exceptions.sdc
	set path_position 0
	set full_update_timing 0
	set max_iter_num 40
	set delay_type min_max
	set pba_mode none
	set crit_slack 0.0
        set groups [get_object_name [get_path_groups *]]
        set sdc_hier ""

	parse_proc_arguments -args $args results
	if {[info exists results(-delay_type)]} {
		set delay_type $results(-delay_type)
	}
	if {[info exists results(-full_update_timing)]} {
		set full_update_timing 1
	}
	if {[info exists results(-max_iterations)]} {
		set max_iter_num $results(-max_iterations)
	}
	if {[info exists results(-output)]} {
		set output $results(-output)
	}
	if {[info exists results(-pba)]} {
		set pba_mode path
	}
	if {[info exists results(-slack)]} {
		set crit_slack $results(-slack)
	}
	if {[info exists results(-specific_start_pin)]} {
		set path_position 1
	}
	if {[info exists results(-group)]} {
		set groups $results(-group)
	}
	if {[info exists results(-instance)]} {
		set sdc_hier $results(-instance)
	}
	if {[info exists results(-man)]} {
		echo "
Usage: write_exceptions_from_violations \[-delay_type <max|min|min_max>\]
    \[-full_update_timing\] \[-man\] \[-max_iterations <number>\]
    \[-output <filename>\] \[-pba\] \[-slack <crit_slack>\]
    \[-specific_start_pin\] \[-group <path_group_list>\]
    \[-instance <instance_prefix_path>\]

Converts timing violations to exceptions for TMAX in SDC format.

    -delay_type <max|min|min_max>
        Use max for setup, min for hold, or min_max for both.
        Default is min_max.
    -full_update_timing
        Force full timing update for 2nd and later iterations.
        Use if too many violating paths causes excessive update_timing runtime.
    -man
        Print this help message and return.
    -max_iterations <number>
        Iterate <number> times before placing blanket exceptions on endpoints.
        Default is 40.
    -output <filename>
        Default is tmax_exceptions.sdc.
    -pba
        Use path-based analysis to reduce pessimism at the expense of runtime.
        Note: Delays in SDF used for full-timing simulation use full pessimism.
    -slack <crit_slack>
        Use <crit_slack> as minimum non-violating slack. The critical slack
        may be positive or negative.
        Default is 0.0.
    -specific_start_pin
        Write separate exceptions for different outputs of a violating cell.
        Default is one exception per startpoint cell.
    -group <path_group_list>
        Provide a specific timing path group or list of groups to use during
        timing analysis.
        Default is to use all defined timng path groups.
    -instance <instance_prefix_path>
        Add an instance prefix to each instance path in the output file
        Default is no prefix.
"
		return
	}

	set OUT [open $output w]
	puts $OUT "# Timing Exceptions for TMAX in SDC "
	puts $OUT "# Generated by pt2tmax Version $version"
	puts $OUT "#"

	# Iterate until timing is clean.  Necessary for multiple-output
	# startpoints, since the start_end_pair will only report the worst
	# output pin for a given startpoint.
	# Not really needed unless -specific_start_pin is specified.

	set path_num 1
	set iter_num 1
	set last_iter_path_num 1
	for {set iter_num 1} {$iter_num <= $max_iter_num} {incr iter_num} {
		echo "Iteration $iter_num update_timing..."
		if {$iter_num > 1 && $full_update_timing == 1} {
			update_timing -full
		} else {
			update_timing
		}
		set paths [get_timing_paths -start_end_pair -delay_type $delay_type -slack_lesser_than $crit_slack -pba_mode $pba_mode -group $groups]
		set num_paths [sizeof_collection $paths]
		echo "Iteration $iter_num found $num_paths Paths..."
		if {$num_paths < 1} {
			echo "Iteration $iter_num Exiting because timing is clean!"
			puts $OUT "# Exiting because timing is clean!  Iteration = $iter_num"
			break
		}
		if {$iter_num == $max_iter_num} {
			puts $OUT "# "
			puts $OUT "# Iteration limit reached, suppressing path startpoints"
		}

		echo "Iteration $iter_num Path processing..."
		# If we are still here, then we are below the iteration limit,
		# and there are still violating paths in this collection.
		foreach_in_collection path $paths {

			# Report the path info from PT:
			set Start_obj [get_attribute $path startpoint]
			set Start_name [get_object_name $Start_obj]
			set Start_name_sdc "${sdc_hier}[get_object_name $Start_obj]"
			set End_obj [get_attribute $path endpoint]
			set End_name [get_object_name $End_obj]
			set End_name_sdc "${sdc_hier}[get_object_name $End_obj]"
			set path_group_name [get_object_name [get_attribute $path path_group]]
			set path_delay_type [get_attribute $path path_type]
			set slack_value [get_attribute $path slack]

			if { $slack_value >= $crit_slack } {
				continue
			}

			puts $OUT "# Path Index: $path_num    Iteration: $iter_num"
			puts $OUT "#  Start:      $Start_name"
			puts $OUT "#  End:        $End_name"
			puts $OUT "#  Group:      $path_group_name"
			puts $OUT "#  Type:       $path_delay_type"
			puts $OUT "#  Slack:      $slack_value"

			if {$path_delay_type == "max"} {
				set exception_type "-setup"
			} else {
				set exception_type "-hold"
			}

			if {$iter_num == $max_iter_num} {
				# Force a false path just to the endpoint:
				puts $OUT "set_false_path $exception_type -to $End_name_sdc"
				set_false_path $exception_type -to $End_name
			} elseif {[get_attribute $Start_obj object_class] == "port"} {
				# Screen out startpoints at ports
				puts $OUT "set_false_path $exception_type -from $Start_name_sdc -to $End_name_sdc"
				set_false_path $exception_type -from $Start_name -to $End_name
			} elseif {$path_position} {
				# The 0th index is the clock pin of the startpoint on reg->reg paths:
				# The 1st index is the output pin of the startpoint on reg->reg paths:
				set Points_coll [get_attribute $path points]
				set Point1_pin [index_collection $Points_coll 1]
				set Point1_name [get_object_name [get_attribute $Point1_pin object] ]
				set Point1_name_sdc "${sdc_hier}[get_object_name [get_attribute $Point1_pin object] ]"
				puts $OUT "set_false_path $exception_type -through $Point1_name_sdc -to $End_name_sdc"
				set_false_path $exception_type -through $Point1_name -to $End_name
			} else {
				puts $OUT "set_false_path $exception_type -from $Start_name_sdc -to $End_name_sdc"
				set_false_path $exception_type -from $Start_name -to $End_name
			}

			# Increment path count:
			incr path_num
		}
		if {$path_num == $last_iter_path_num} {
			echo "Iteration $iter_num Exiting because post-PBA timing is clean!"
			puts $OUT "# Exiting because post-PBA timing is clean!  Iteration = $iter_num"
			break
		}
		set last_iter_path_num $path_num
	}

	close $OUT
}

define_proc_attributes write_exceptions_from_violations \
    -info "Converts timing violations to exceptions for TMAX in SDC format." \
    -define_args { \
	{ -delay_type "Delay type for timing analysis" <type> one_of_string { "optional" "value_help" "values { max min min_max }" } } \
	{ -full_update_timing "Prevent incremental timing updates" "" boolean optional } \
	{ -man "Print man page and return" "" boolean optional } \
	{ -max_iterations "Limit on timing updates" <number> int optional } \
	{ -output "Name of SDC file" <output_filename> string optional } \
	{ -pba "Use path-based analysis" "" boolean optional } \
	{ -slack "Minimum non-violating slack" <crit_slack> float optional } \
	{ -specific_start_pin "Write exceptions from pins" "" boolean optional } \
	{ -group "Path group list - to limit runtime & memory usage" <path_group_list> list optional } \
	{ -instance "Hierarchical instance prefix" <instance_prefix> string optional } \
    }
