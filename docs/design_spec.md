# Synchronous FIFO Design Specification

## Configuration
- Data width: 8 bits (parameterized)
- Depth: 16 words (parameterized)
- Clock: single rising-edge clock
- Reset: asynchronous, active-low
- Status: `full`, `empty`, and occupancy `count`

## Transaction semantics
A write is accepted on a rising edge when `wr_en=1` and the pre-edge
`full=0`. A read is accepted when `rd_en=1` and the pre-edge
`empty=0`.

The acceptance decisions use pre-edge status. Consequently, a simultaneous
read and write while full accepts the read but rejects the write. A
simultaneous read and write while empty accepts the write but rejects the read.
When occupancy is between zero and depth, both operations are accepted.

## Data output
`dout` is registered and changes only after an accepted read. It holds its
previous value on cycles without an accepted read. Memory contents are not reset.

## Status
`empty` is asserted when count is zero. `full` is asserted when count equals
DEPTH. Count is constrained to the range 0 through DEPTH.

## Build and run
Install Icarus Verilog, then run:

```bash
chmod +x scripts/run_sim.sh
./scripts/run_sim.sh
```

The testbench uses a queue scoreboard and checks ordering, occupancy, status
flags, overflow/underflow attempts, simultaneous operations, pointer wrap, and
deterministic stress traffic.

## Scope and limitations
This is a compact baseline verification environment, not a formal proof.
The current testbench uses Icarus-compatible SystemVerilog constructs. Run it
with the documented simulator before treating it as a verified baseline.
