# AirComp references for M2

These standalone FPGA blocks show how AirComp handles sample timing and playback. Each block has its own testbench. They are reference examples for the new modem's control and sample path.

## Files and starting points

| Source | Testbench | What to reuse |
|---|---|---|
| [hw_route_b_sync.sv](rtl/hw_route_b_sync.sv) | [hw_tb_route_b_sync.sv](tb/hw_tb_route_b_sync.sv) | Count accepted receive samples, latch timestamps and fire a scheduled transmit trigger when the buffer is ready. |
| [hw_tx_window_sched.sv](rtl/hw_tx_window_sched.sv) | [hw_tb_tx_window_sched.sv](tb/hw_tb_tx_window_sched.sv) | Calculate transmit windows, handle counter rollover and reject expired schedules. |
| [hw_tx_player.sv](rtl/hw_tx_player.sv) | [hw_tb_tx_player.sv](tb/hw_tb_tx_player.sv) | Play a preloaded complex-sample buffer when the DAC requests samples. |

The new M2 design still needs its modem, FEC, Es/N0 measurement, packet DMA interface and board integration. These three blocks have not been tested together as a pipeline in this project.

## Run the tests

Install Python 3.10 or newer and [Icarus Verilog](https://steveicarus.github.io/iverilog/usage/installation.html), including `iverilog` and `vvp`. No Python packages, vendor IP, generated ROMs or FPGA board are needed.

From the repository root, with both Icarus commands on `PATH`:

```bash
python3 references/aircomp/sw_run_tests.py
```

On Windows, use `python` and supply the installed tool paths if needed:

```powershell
python references/aircomp/sw_run_tests.py --iverilog C:/iverilog/bin/iverilog.exe --vvp C:/iverilog/bin/vvp.exe
```

The runner requires each bench's success message, rejects failure messages and applies a timeout. Simulator outputs stay in ignored `build/aircomp_references/`.

## Integration rules

- `route_b_sync` and the scheduler use accepted ADC samples as their time unit. Their counters do not measure FPGA clock cycles. Keep scheduled deadlines within the signed counter-comparison range.
- The scheduler's defaults and register offsets describe the historical AirComp system. Choose the capstone settings through the packet, register and buffer contract in [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4).
- `tx_player` advances on `dac_sample_tick`. Preload its RAM, keep the requested length within its capacity and keep playback contents stable while active. It is not an AXI-stream input adapter.
- Historical deployment and timing comments belong to AirComp. The included simulations check the individual blocks, without RF or FPGA deployment.

## Source and local changes

The snapshot comes from `aircomp-regret-pluto` commit `9b4458f1add263af9e2623d85d3a7d6ff7de2d7b`, under `hdl/rtl/` and `hdl/tb/`. Original source headers and module names are retained. Filenames have the project's `hw_` prefix.

The three RTL files and the player and scheduler testbenches match their original Git contents. The copied Route-B testbench drives inputs on falling edges and checks outputs after rising-edge updates. This removes testbench races while retaining its 22 original checks. The original AirComp checkout is unchanged.

The selected files contain no separate license notices. This reference drop adds no new license. Sahin-derived PPDU, polar-FEC and receive-FIFO ports are outside this snapshot while their third-party notices are reviewed. The [original Sahin project](https://github.com/alphansahin/Over-the-Air-Computation/tree/e92f721d7a800c5ef5d7ff124f5927e07e021048) remains a source reference for that work.
