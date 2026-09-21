# Synchronous FIFO with Assertions (Verilog)

Parameterized synchronous FIFO with a self-checking testbench and simulation-time assertions.

## Design
- `DATA_W` and `ADDR_W` parameters (depth = 2^ADDR_W)
- Read/write pointers are `ADDR_W+1` bits wide; the extra MSB separates **full** from **empty**
  - empty: `wptr == rptr`
  - full: MSBs differ and the lower bits match
- Writes while full and reads while empty are ignored (no overflow/underflow corruption)
- Registered read data (valid one cycle after `rd_en`)

## Verification
- **Scoreboard**: cycle-accurate reference model compares read data and full/empty flags every cycle
- **Directed tests**: reset state, fill to full, overflow attempts, drain, underflow attempts,
  simultaneous read+write, mid-operation reset
- **Random traffic**: 5000 cycles biased to hit both full and empty corners
- **Assertions** (`rtl/sync_fifo.v`, under `ifndef SYNTHESIS`):
  A1 full&empty never together, A2 occupancy <= depth, A3/A4 flags match occupancy,
  A5 pointer moves only on a valid write, A6 same for read, A7 pointer moves at most 1/cycle

## Run
```
sudo apt install iverilog gtkwave
bash sim/run.sh
gtkwave sim/fifo.vcd
```
Expected: `RESULT: PASS` and no assertion errors.

## Structure
```
rtl/sync_fifo.v      design + assertions
tb/tb_sync_fifo.v    testbench + scoreboard
sim/run.sh           compile and run script
```
