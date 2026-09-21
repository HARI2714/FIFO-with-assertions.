#!/bin/bash
# Run from repo root:  ./sim/run.sh   (needs Icarus Verilog: sudo apt install iverilog gtkwave)
set -e
mkdir -p sim
iverilog -g2012 -o sim/fifo.vvp rtl/sync_fifo.v tb/tb_sync_fifo.v
vvp sim/fifo.vvp
echo "Waveform: gtkwave sim/fifo.vcd"
