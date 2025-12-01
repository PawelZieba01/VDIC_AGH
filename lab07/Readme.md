a) Which objects in the diagram instantiate which?
    random_test instancjonuje:
        env_h
    
    env_h instancjonuje:
        random_tester_h
        driver_h
        coverage_h
        scoreboard_h
        command_monitor_h
        result_monitor_h
        uvm_tlm_fifo (dla sequencera/testera)
    
    scoreboard instancjonuje:
        uvm_tlm_analysis_fifo

b) The following objects in the diagram are created by the new() function:
    uvm_tlm_fifo
    uvm_tlm_analysis_fifo

c) The following objects in the diagram are created by reference to the UVM factory:
    random_tester_h
    driver_h
    coverage_h
    scoreboard_h
    command_monitor_h
    result_monitor_h
    env_h

d) Objects of the following classes retrieve BFM information from UVM by calling uvm_config_db:
    driver_h
    command_monitor_h
    result_monitor_h

e) Objects of the following classes instantiate uvm_analysis_port:
    command_monitor_h
    result_monitor_h

f) Objects of the following classes instantiate uvm_get_port:
    driver_h

g) Objects of the following classes instantiate uvm_put_port:
    base_tpgen_h

h) The following classes include the implementation of the void write() method:
    coverage_h
    scoreboard_h