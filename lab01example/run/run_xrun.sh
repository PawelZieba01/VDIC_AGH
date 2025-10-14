#!/bin/bash
#------------------------------------------------------------------------------
# (C) Copyright 2023 AGH University of Krakow, All Rights Reserved
#------------------------------------------------------------------------------
# Run script for MTM, Verification of Digital Integrated Circuis
# 
# Commmand arguments:
# -g          - starts xrun simulation with gui, with separate database
# -q          - xrun quiet operation, less information on screen
# -d          - define verilog `DEBUG macro
# -f <file.f> - use file.f instead of the default tb.f 
# -c          - run imc after simulation to merge the coverage results and
#               display the statistics

# To set the paths for xrun and imc, execute the following command in the terminal:
# source ../../common/env.sh

# Help library if available with command:
# cdnshelp &

#------------------------------------------------------------------------------
# The list of tests; in GUI mode only the first test is started.
TESTS=(lab01_example);
#------------------------------------------------------------------------------
# Default .f file
FFILE="../tb/tb.f"
#------------------------------------------------------------------------------
# MAIN
function main(){
  xrun_compile
  xrun_elaborate
  xrun_run_all_tests
  if [[ "$RUN_IMC" != "" ]]; then
    run_imc
  fi
  time_meas_report
}
#------------------------------------------------------------------------------
# PROCEDURES
#------------------------------------------------------------------------------
function syntax() { #<<<
   echo -e "Valid option are:"
   echo -e "    -c - run coverage analysis (merge coverage results)"
   echo -e "    -d - set DEBUG verilog macro"
   echo -e "    -f <file.f> (default: ${FFILE})"
   echo -e "    -g - for GUI"
   echo -e "    -h - display this help information"
   echo -e "    -q - for quiet run"
} #>>>
#------------------------------------------------------------------------------
function xrun_info() { #<<<
  # Prints string between separators
  # args: string
  echo $separator
  echo -n `date +[%k:%M:%S]`
  echo " # $*"
  echo $separator
  return 0
} #>>>
#------------------------------------------------------------------------------
function xrun_check_status() { #<<<
  # Checks the status of the action;
  # args: int (status), string (action name)

  status=$1
  action=$2

  if [[ "$status" != "0" ]]; then
    echo -e "$action $FAILED with status $status".
    exit -1
  fi
  echo -e "$action finished with status 0 ($PASSED)."
  return 0
} #>>>
#------------------------------------------------------------------------------
function xrun_compile() { #<<<
  time_meas_start
  xrun_info "# Compiling. Log saved to xrun_compile.log"
  xrun -compile -l xrun_compile.log $XRUN_ARGS 
  xrun_check_status $? "Compilation"
  time_meas_end "Compilation"
} #>>>
#------------------------------------------------------------------------------
function xrun_elaborate() { #<<<
  time_meas_start
  xrun_info "# Elaborating. Log saved to xrun_elaborate.log"
  xrun -elaborate  -l xrun_elaborate.log $XRUN_ARGS
  xrun_check_status $? "Elaboration"
  time_meas_end "Elaboration"
} #>>>
#------------------------------------------------------------------------------
function xrun_run_all_tests() { #<<<
  time_meas_start
  COV_TEST=""
  if [[ "$GUI" != "" ]] ; then
      if [[ "$RUN_IMC" != "" ]]; then
        COV_TEST="-covtest ${TESTS[0]}"
      fi
      xrun $XRUN_ARGS \
        $COV_TEST \
        +UVM_TESTNAME=${TESTS[0]} \
        -l xrun_gui.log
  else  
    TEST_LIST=""

    for TEST in ${TESTS[@]} ; do
      TEST_LIST="$TEST_LIST $TEST"
      xrun_info "# Running test: $TEST. Log saved to xrun_test_$TEST.log"
      if [[ "$RUN_IMC" != "" ]]; then
        COV_TEST="-covtest $TEST"
      fi
      # run the simulation
      xrun $XRUN_ARGS \
        $COV_TEST \
        +UVM_TESTNAME=$TEST \
        -l xrun_test_$TEST.log
      check_uvm_fatal "xrun_test_$TEST.log"
      xrun_check_status $? "Test $TEST"
    done

    echo "# End of tests."
  fi
  xrun_check_status $? "Simulation"
  time_meas_end "Simulation"
} #>>>
#------------------------------------------------------------------------------
function run_imc { #<<<
  xrun_info "# Running imc."
  time_meas_start
  #------------------------------------------------------------------------------
  # print the coverage results summary (non-GUI mode)
  if [[ "$GUI" == "" ]] ; then

    # merging the coverage results from different tests
    imc -nocopyright -batch -initcmd \
      "load -run $TEST; merge -out merged_results $TEST_LIST; exit" |& tee xrun_cov.rpt
    xrun_check_status $? "IMC MERGE"

    # printing the summary
    imc -nocopyright -batch -initcmd \
      "load -run merged_results; report -summary; exit" |& tee -a xrun_cov.rpt
    xrun_check_status $? "IMC REPORT"

    xrun_info "\
 The coverage report was saved to xrun_cov.rpt file.
 To browse the results with gui use:
   imc -load merged_results"
  fi
  time_meas_end "IMC"
} #>>>
#------------------------------------------------------------------------------
function time_meas_start { #<<<
  start_time=$(date +%s)
} #>>>
function time_meas_end { #<<<
  end_time=$(date +%s)
  info=$*;
  time_report+=$'\n'
  time_report+="  $info : $((end_time - start_time))s"
} #>>>
function time_meas_report { #<<<
  echo $separator
  echo -n "Time measurement results:"
  echo "$time_report"
  echo $separator
} #>>>
#------------------------------------------------------------------------------
function check_uvm_fatal() { #<<<
# check for the UVM_FATAL in the given log file
# args: string - log file name
  logfile=$1
  echo "CHECKING LOG FILE: $logfile"
  if [[ $(egrep  -c "^UVM_FATAL *: *[123456789]" $logfile) != "0" ]]; then
    echo -e "Simulation $FAILED with UVM_FATAL";
    exit -1
  fi
  if [[ $(egrep  -c "ERROR" $logfile) != "0" ]]; then
    echo -e "Simulation $FAILED with ERROR in the log file.";
    exit -1
  fi
  if [[ $(egrep  -c '*F,NOLICN' $logfile) != "0" ]]; then
    echo -e "Simulation $FAILED - license error.";
    exit -1
  fi
} #>>>
#------------------------------------------------------------------------------
# local variables#<<<
XCELIUM_CONFIG="../../common/env.sh";
INCA="INCA_libs"
GUI=""
QUIET=""
DEBUG=""
RUN_IMC=""
start_time=0
time_report=""
# PASSED="PASSED"
# FAILED="FAILED"
PASSED="\033[1;30m\033[102m-OK-\033[0m"
FAILED="\033[1;30m\033[101m-FAILED-\033[0m"
#>>>
#------------------------------------------------------------------------------
# check input script arguments and env#<<<
while getopts cdf:gqh option
  do case "${option}" in
    g) GUI="+access+r +gui"; INCA="${INCA}_gui";;
    q) QUIET="-q";;
    d) DEBUG="-define DEBUG";;
    f) FFILE=$OPTARG;;
    c) RUN_IMC=1;;
    h) syntax; exit 0;;
    *) syntax; exit -1;;
  esac
done
#>>>
#------------------------------------------------------------------------------
# init #<<<
rm -rf $INCA      # remove previous database
rm -rf cov_work   # remove previous coverage results
cols=`tput cols`
separator=`perl -e "print \"#\" x $cols"` >> /dev/null 2>&1
which xrun >> /dev/null 2>&1
if [[ "$?" != "0" ]]; then
  echo ERROR: xrun simulator not found. Execute the command:
  echo source $XCELIUM_CONFIG
  exit -1
fi
#>>>
#------------------------------------------------------------------------------
# simulator arguments #<<<
# COV_ARGS=""
# if [[ "$RUN_IMC" != "" ]]; then
  COV_ARGS="-coverage all -covoverwrite -covfile xrun_covfile.txt" 
# fi
XRUN_ARGS="\
  -F $FFILE \
  -v93 \
  $QUIET \
  $DEBUG \
  +nowarnDSEM2009 \
  +nowarnDSEMEL \
  +nowarnCGDEFN \
  +nowarnCOVUTA \
  +nowarnBADPRF \
  +nowarnXCLGNOPTM \
  +nowarnRNDXCELON \
  +nowarnSAWSTP \
  -xmlibdirname $INCA \
  $GUI \
  +overwrite \
  -nocopyright \
  $COV_ARGS \
"
#>>>
# run the main
main

# vim: fdm=marker foldmarker=<<<\,>>>
