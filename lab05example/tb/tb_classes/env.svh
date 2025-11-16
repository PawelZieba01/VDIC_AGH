/*
 Copyright 2013 Ray Salemi

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
class env extends uvm_env;
    `uvm_component_utils(env)

//------------------------------------------------------------------------------
// testbench elements
//------------------------------------------------------------------------------
    random_tpgen tpgen_h;
    coverage coverage_h;
    scoreboard scoreboard_h;

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        tpgen_h      = random_tpgen::type_id::create("tpgen_h",this);
        coverage_h   = coverage::type_id::create ("coverage_h",this);
        scoreboard_h = scoreboard::type_id::create("scoreboard_h",this);
    endfunction : build_phase

//------------------------------------------------------------------------------
// end-of-elaboration phase
//------------------------------------------------------------------------------
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        // display created tpgen type
        set_print_color(COLOR_BOLD_BLACK_ON_YELLOW);
        $write("*** Created tpgen type: %s ***", tpgen_h.get_type_name());
        set_print_color(COLOR_DEFAULT);
        $write("\n");

    endfunction : end_of_elaboration_phase

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------
    function new (string name, uvm_component parent);
        super.new(name,parent);
    endfunction : new

endclass


