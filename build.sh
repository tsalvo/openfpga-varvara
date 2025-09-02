#!/bin/sh

~/intelFPGA_lite/24.1std/quartus/bin/quartus_sh --flow compile ./src/fpga/ap_core.qpf
rbfrmake ./src/fpga/output_files/ap_core.rbf ./src/fpga/output_files/bitstream.rbf_r