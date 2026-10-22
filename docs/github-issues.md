# Project work order

Work through M0 to M5 in the order below. Each task uses its GitHub issue number and plain title. Issue numbers show when tasks were created, so follow this list when choosing what to work on next.

Finish a task's prerequisites before starting it. Tasks whose prerequisites are complete can run in parallel. Work-area labels show which team skills each task needs.

[All issues](https://github.com/le21-j/wireless-beamforming-network/issues) · [Milestones](https://github.com/le21-j/wireless-beamforming-network/milestones) · [Project plan](project-plan.md) · [Task requirements](backlog.md)

## Milestone order

| Milestone | Work order |
|---|---|
| M0 Foundations | [#1](https://github.com/le21-j/wireless-beamforming-network/issues/1) → [#2](https://github.com/le21-j/wireless-beamforming-network/issues/2) → [#3](https://github.com/le21-j/wireless-beamforming-network/issues/3) → [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4) |
| M1 Local network | [#6](https://github.com/le21-j/wireless-beamforming-network/issues/6) → [#8](https://github.com/le21-j/wireless-beamforming-network/issues/8) → [#11](https://github.com/le21-j/wireless-beamforming-network/issues/11) → [#17](https://github.com/le21-j/wireless-beamforming-network/issues/17) |
| M2 Modem bench | [#5](https://github.com/le21-j/wireless-beamforming-network/issues/5) → [#7](https://github.com/le21-j/wireless-beamforming-network/issues/7) → [#9](https://github.com/le21-j/wireless-beamforming-network/issues/9) → [#10](https://github.com/le21-j/wireless-beamforming-network/issues/10) → [#12](https://github.com/le21-j/wireless-beamforming-network/issues/12) → [#13](https://github.com/le21-j/wireless-beamforming-network/issues/13) → [#14](https://github.com/le21-j/wireless-beamforming-network/issues/14) → [#16](https://github.com/le21-j/wireless-beamforming-network/issues/16) → [#19](https://github.com/le21-j/wireless-beamforming-network/issues/19) → [#21](https://github.com/le21-j/wireless-beamforming-network/issues/21) |
| M3 Routed wireless | [#15](https://github.com/le21-j/wireless-beamforming-network/issues/15) → [#20](https://github.com/le21-j/wireless-beamforming-network/issues/20) → [#22](https://github.com/le21-j/wireless-beamforming-network/issues/22) → [#23](https://github.com/le21-j/wireless-beamforming-network/issues/23) → [#27](https://github.com/le21-j/wireless-beamforming-network/issues/27) → [#29](https://github.com/le21-j/wireless-beamforming-network/issues/29) |
| M4 Direction aware | [#18](https://github.com/le21-j/wireless-beamforming-network/issues/18) → [#24](https://github.com/le21-j/wireless-beamforming-network/issues/24) → [#26](https://github.com/le21-j/wireless-beamforming-network/issues/26) → [#28](https://github.com/le21-j/wireless-beamforming-network/issues/28) → [#31](https://github.com/le21-j/wireless-beamforming-network/issues/31) → [#32](https://github.com/le21-j/wireless-beamforming-network/issues/32) → [#33](https://github.com/le21-j/wireless-beamforming-network/issues/33) |
| M5 Optional extensions | [#25](https://github.com/le21-j/wireless-beamforming-network/issues/25) → [#30](https://github.com/le21-j/wireless-beamforming-network/issues/30) → [#34](https://github.com/le21-j/wireless-beamforming-network/issues/34) |

M5 contains optional work. Complete the M4 demonstration first.

In M1, #6 startup work and #8 host tools can run in parallel. In M2, #5 modem modeling, #7 RF bench preparation and #10 control registers can start in parallel once their prerequisites are complete.

## Current M1 work

The Linux USB checks passed on both Plutos using one PC. The original two-PC and board-support requirements remain open. See the [M1 issue status](sw_m1_pr_preview.md#issue-status) before treating M1 as complete.

## M0 Foundations

| Issue | Prerequisites |
|---|---|
| [#1 — Decide hardware, scope and demo targets](https://github.com/le21-j/wireless-beamforming-network/issues/1) | None |
| [#2 — Verify board Ethernet, clock and processor feasibility](https://github.com/le21-j/wireless-beamforming-network/issues/2) | [#1](https://github.com/le21-j/wireless-beamforming-network/issues/1) |
| [#3 — Make the repository and tool versions reproducible](https://github.com/le21-j/wireless-beamforming-network/issues/3) | [#1](https://github.com/le21-j/wireless-beamforming-network/issues/1) |
| [#4 — Freeze IP, frame, register and buffer contracts](https://github.com/le21-j/wireless-beamforming-network/issues/4) | [#1](https://github.com/le21-j/wireless-beamforming-network/issues/1) |

## M1 Local network

| Issue | Prerequisites |
|---|---|
| [#6 — Bring up boot, BSP, UART and timers](https://github.com/le21-j/wireless-beamforming-network/issues/6) | [#2](https://github.com/le21-j/wireless-beamforming-network/issues/2), [#3](https://github.com/le21-j/wireless-beamforming-network/issues/3) |
| [#8 — Build the host test harness and evidence format](https://github.com/le21-j/wireless-beamforming-network/issues/8) | [#1](https://github.com/le21-j/wireless-beamforming-network/issues/1), [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4) |
| [#11 — Bring up Ethernet MAC, PHY, eth0 and lwIP](https://github.com/le21-j/wireless-beamforming-network/issues/11) | [#6](https://github.com/le21-j/wireless-beamforming-network/issues/6) |
| [#17 — Prove local PC ICMP and UDP on both boards](https://github.com/le21-j/wireless-beamforming-network/issues/17) | [#11](https://github.com/le21-j/wireless-beamforming-network/issues/11), [#8](https://github.com/le21-j/wireless-beamforming-network/issues/8) |

## M2 Modem bench

| Issue | Prerequisites |
|---|---|
| [#5 — Build the floating-point modem reference and link framing](https://github.com/le21-j/wireless-beamforming-network/issues/5) | [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4) |
| [#7 — Prepare the RF bench, link budget and attenuators](https://github.com/le21-j/wireless-beamforming-network/issues/7) | [#2](https://github.com/le21-j/wireless-beamforming-network/issues/2), [#1](https://github.com/le21-j/wireless-beamforming-network/issues/1) |
| [#9 — Produce fixed-point reference vectors](https://github.com/le21-j/wireless-beamforming-network/issues/9) | [#5](https://github.com/le21-j/wireless-beamforming-network/issues/5) |
| [#10 — Implement AXI-Lite control/status RTL and driver](https://github.com/le21-j/wireless-beamforming-network/issues/10) | [#6](https://github.com/le21-j/wireless-beamforming-network/issues/6), [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4) |
| [#12 — Implement the FPGA transmit modem](https://github.com/le21-j/wireless-beamforming-network/issues/12) | [#9](https://github.com/le21-j/wireless-beamforming-network/issues/9) |
| [#13 — Implement the FPGA receive modem](https://github.com/le21-j/wireless-beamforming-network/issues/13) | [#9](https://github.com/le21-j/wireless-beamforming-network/issues/9) |
| [#14 — Prove DMA packet loopback and buffer ownership](https://github.com/le21-j/wireless-beamforming-network/issues/14) | [#10](https://github.com/le21-j/wireless-beamforming-network/issues/10), [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4) |
| [#16 — Bring up converters and one RF I/Q path](https://github.com/le21-j/wireless-beamforming-network/issues/16) | [#2](https://github.com/le21-j/wireless-beamforming-network/issues/2), [#10](https://github.com/le21-j/wireless-beamforming-network/issues/10) |
| [#19 — Prove digital frame modem loopback](https://github.com/le21-j/wireless-beamforming-network/issues/19) | [#12](https://github.com/le21-j/wireless-beamforming-network/issues/12), [#13](https://github.com/le21-j/wireless-beamforming-network/issues/13), [#14](https://github.com/le21-j/wireless-beamforming-network/issues/14) |
| [#21 — Prove bidirectional conducted RF with independent oscillators](https://github.com/le21-j/wireless-beamforming-network/issues/21) | [#19](https://github.com/le21-j/wireless-beamforming-network/issues/19), [#16](https://github.com/le21-j/wireless-beamforming-network/issues/16), [#7](https://github.com/le21-j/wireless-beamforming-network/issues/7) |

## M3 Routed wireless

| Issue | Prerequisites |
|---|---|
| [#15 — Implement the half-duplex TDD scheduler](https://github.com/le21-j/wireless-beamforming-network/issues/15) | [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4), [#10](https://github.com/le21-j/wireless-beamforming-network/issues/10), [#5](https://github.com/le21-j/wireless-beamforming-network/issues/5) |
| [#20 — Implement radio0 with a mock IP backend](https://github.com/le21-j/wireless-beamforming-network/issues/20) | [#17](https://github.com/le21-j/wireless-beamforming-network/issues/17), [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4) |
| [#22 — Prove routes and actual IP forwarding without RF](https://github.com/le21-j/wireless-beamforming-network/issues/22) | [#20](https://github.com/le21-j/wireless-beamforming-network/issues/20) |
| [#23 — Prove an OTA packet link with fixed antennas or beams](https://github.com/le21-j/wireless-beamforming-network/issues/23) | [#21](https://github.com/le21-j/wireless-beamforming-network/issues/21), [#15](https://github.com/le21-j/wireless-beamforming-network/issues/15) |
| [#27 — Bind radio0 to wireless DMA and connect the PCs](https://github.com/le21-j/wireless-beamforming-network/issues/27) | [#22](https://github.com/le21-j/wireless-beamforming-network/issues/22), [#14](https://github.com/le21-j/wireless-beamforming-network/issues/14), [#15](https://github.com/le21-j/wireless-beamforming-network/issues/15), [#23](https://github.com/le21-j/wireless-beamforming-network/issues/23) |
| [#29 — Measure PC-to-PC performance and run regression](https://github.com/le21-j/wireless-beamforming-network/issues/29) | [#27](https://github.com/le21-j/wireless-beamforming-network/issues/27), [#8](https://github.com/le21-j/wireless-beamforming-network/issues/8) |

## M4 Direction aware

| Issue | Prerequisites |
|---|---|
| [#18 — Simulate discovery and rendezvous](https://github.com/le21-j/wireless-beamforming-network/issues/18) | [#4](https://github.com/le21-j/wireless-beamforming-network/issues/4), [#15](https://github.com/le21-j/wireless-beamforming-network/issues/15) |
| [#24 — Establish coherent timing and calibration for four RF paths](https://github.com/le21-j/wireless-beamforming-network/issues/24) | [#16](https://github.com/le21-j/wireless-beamforming-network/issues/16), [#7](https://github.com/le21-j/wireless-beamforming-network/issues/7), [#21](https://github.com/le21-j/wireless-beamforming-network/issues/21) |
| [#26 — Implement the beamformer and atomic beam control](https://github.com/le21-j/wireless-beamforming-network/issues/26) | [#24](https://github.com/le21-j/wireless-beamforming-network/issues/24), [#10](https://github.com/le21-j/wireless-beamforming-network/issues/10) |
| [#28 — Create the beam codebook and measure patterns](https://github.com/le21-j/wireless-beamforming-network/issues/28) | [#24](https://github.com/le21-j/wireless-beamforming-network/issues/24), [#26](https://github.com/le21-j/wireless-beamforming-network/issues/26) |
| [#31 — Run directional HAIL/ACK sweeps over the air](https://github.com/le21-j/wireless-beamforming-network/issues/31) | [#26](https://github.com/le21-j/wireless-beamforming-network/issues/26), [#18](https://github.com/le21-j/wireless-beamforming-network/issues/18), [#23](https://github.com/le21-j/wireless-beamforming-network/issues/23), [#28](https://github.com/le21-j/wireless-beamforming-network/issues/28) |
| [#32 — Integrate fresh neighbor/beam state with routing](https://github.com/le21-j/wireless-beamforming-network/issues/32) | [#31](https://github.com/le21-j/wireless-beamforming-network/issues/31), [#27](https://github.com/le21-j/wireless-beamforming-network/issues/27) |
| [#33 — Prove blockage, rediscovery and end-to-end recovery](https://github.com/le21-j/wireless-beamforming-network/issues/33) | [#32](https://github.com/le21-j/wireless-beamforming-network/issues/32), [#29](https://github.com/le21-j/wireless-beamforming-network/issues/29) |

## M5 Optional extensions

| Issue | Prerequisites |
|---|---|
| [#25 — Evaluate adaptive throughput or a FEC upgrade](https://github.com/le21-j/wireless-beamforming-network/issues/25) | [#21](https://github.com/le21-j/wireless-beamforming-network/issues/21) |
| [#30 — Add per-LAN DHCP or host provisioning convenience](https://github.com/le21-j/wireless-beamforming-network/issues/30) | [#27](https://github.com/le21-j/wireless-beamforming-network/issues/27) |
| [#34 — Optionally implement an actual L2 Ethernet bridge](https://github.com/le21-j/wireless-beamforming-network/issues/34) | [#33](https://github.com/le21-j/wireless-beamforming-network/issues/33) |
