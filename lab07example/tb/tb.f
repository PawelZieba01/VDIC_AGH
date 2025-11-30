-F ../../common/tinyalu/tinyalu.f
tinyalu_tb_pkg.sv
tinyalu_bfm.sv
top.sv
-timescale 1ns/1ps
+incdir+tb_classes
+incdir+.
+nowarn+DSEMEL
+nowarnBADPRF
-uvm
-uvmhome /eda/cadence/2021-22/RHELx86/XCELIUM_21.03.009/tools/methodology/UVM/CDNS-1.2/sv
+UVM_NO_RELNOTES
+UVM_VERBOSITY=MEDIUM
-linedebug
-fsmdebug
-uvmlinedebug
