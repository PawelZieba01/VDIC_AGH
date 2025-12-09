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
class dual_test extends uvm_test;
    `uvm_component_utils(dual_test)

//------------------------------------------------------------------------------
// the env
//------------------------------------------------------------------------------

    env env_h;

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name,parent);
    endfunction : new

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);

        virtual tinyalu_bfm class_bfm;
        virtual tinyalu_bfm module_bfm;

        env_config env_config_h;

        if(!uvm_config_db #(virtual tinyalu_bfm)::get(this, "","class_bfm", class_bfm))
            `uvm_fatal("DUAL TEST", "Failed to get CLASS BFM");
        if(!uvm_config_db #(virtual tinyalu_bfm)::get(this, "","module_bfm", module_bfm))
            `uvm_fatal("DUAL TEST", "Failed to get MODULE BFM");

        env_config_h = new(.class_bfm(class_bfm), .module_bfm(module_bfm));

        uvm_config_db #(env_config)::set(this, "env_h*", "config", env_config_h);

        env_h        = env::type_id::create("env_h",this);

    endfunction : build_phase

//------------------------------------------------------------------------------
// start-of-simulation phase
//------------------------------------------------------------------------------

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        // other printers available:
        // - uvm_default_line_printer
        // - uvm_default_tree_printer
        set_print_color(COLOR_BLUE_ON_WHITE);
        this.print(uvm_default_table_printer); // print test env topology
        set_print_color(COLOR_DEFAULT);
    endfunction : start_of_simulation_phase



endclass

