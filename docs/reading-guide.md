# Starter reading guide

Use this guide to understand the system before implementing it. Start with the shared foundation, then follow the path for your next ticket. Each path names the sections worth reading and a small exercise that connects them to this capstone. You do not need to read every manual before starting.

The learning exercises below are proposed preparation, not completed project tests. The linked material is freely readable and comes from original textbook authors, tool maintainers, or hardware vendors. Board models and tool versions are still open decisions in S01/H01; select matching implementation instructions once those are known.

[Shared foundation](#shared-foundation) · [Networking and embedded software](#networking-and-embedded-software) · [FPGA and Verilog](#fpga-and-verilog) · [Modem DSP](#modem-dsp) · [Hardware and beamforming](#hardware-and-beamforming) · [Host tools and team workflow](#host-tools-and-team-workflow) · [Readiness check](#team-readiness-check)

## Shared foundation

For the first team session, skim these three readings in order. The goal is to explain the path through the system; the specialist paths provide the implementation detail.

| Order | Read | Focus and connection to our project |
|---|---|---|
| 1 | [Our architecture and dependency graph](project-plan.md) | Read the proposed architecture, module boundaries and milestone exit criteria. Identify what runs on the PCs, embedded processors and FPGA logic, and what belongs to the RF hardware. |
| 2 | [A Systems Approach — Internet (IP)](https://github.com/SystemsApproach/book/blob/master/internetworking/basic-ip.rst), Larry Peterson and Bruce Davie | Start with **What Is an Internetwork?**, **Datagram Forwarding in IP**, **Subnetting and Classless Addressing**, **Address Translation (ARP)** and **Error Reporting (ICMP)**. Understand destination IP, local next hop and return route. Save fragmentation details for the MTU decision. |
| 3 | [PySDR — IQ Sampling](https://pysdr.org/content/sampling), Marc Lichtman | Read **Sampling Basics**, **Quadrature Sampling**, **Complex Numbers**, **Receiver Side**, and **Baseband and Bandpass Signals**; revisit Nyquist sampling if needed. Learn what an I/Q sample represents and how samples differ from packet bytes. |

Use this project-specific sketch while reading. It describes the proposed raw-IP radio design; the receive path reverses the relevant conversions.

```text
PC application
  -> IP packet inside a local Ethernet frame
  -> node Ethernet interface and embedded lwIP forwarding
  -> radio link frame containing the IP packet
  -> modem symbols and complex baseband samples
  -> per-channel beam weights, converters and RF front end
  -> wireless channel
  -> peer node receiver, modem and lwIP
  -> remote PC
```

**Team exercise:** Draw both nodes and all three proposed subnets from the architecture. Mark Ethernet frames, IP packets, radio frames, symbols and samples on the drawing. Explain why a successful local PC-to-node ping proves M1 but does not prove PC-to-PC forwarding or a working radio modem.

## Choose a reading path

Use the [work-area labels](github-setup.md#work-area-labels) to pick your path. Stable ticket IDs map to live issues in the [issue index](github-issues.md).

| Your work area | Read first | First useful tickets |
|---|---|---|
| `area:embedded-software` | Networking path; AXI/DMA sections when working on drivers | F01, N01, N02, then F03/N03 |
| `area:fpga-verilog` | RTL and AXI basics; modem DSP for datapath work | F02, F03, D02–D05, B01 |
| `area:hardware-rf` | I/Q sampling, link budgets and the selected board's documentation | H01–H03, then H04/H05 |
| `area:host-software` | Modem DSP for reference models; host tools for automation | D01/D02, S04, B02 |
| `area:integration-testing` | Shared foundation, host tools, and both sides of the interface being tested | S01–S05, N02, N05, D05–D07 |

## Networking and embedded software

**Goal:** Understand local Ethernet first, then packet ownership and the extra work required for routing. Basic C pointers, callbacks and interrupt concepts are useful prerequisites.

| When | Reading | What to read and why |
|---|---|---|
| Start | [AMD — Standalone LWIP library](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842366/Standalone%2BLWIP%2Blibrary) | Read **Introduction**, **How to enable**, the relevant Ethernet-controller support, **Echo server**, and **Known issues/Limitations**. Follow the example links for the selected release. This is the starting reference for F01/N01/N02. The echo application is a TCP endpoint test; capture ICMP ping separately. |
| Start if using bare metal | [lwIP — Mainloop mode (`NO_SYS`)](https://www.nongnu.org/lwip/2_1_x/group__lwip__nosys.html) | Follow the sample's initialization, input processing and `sys_check_timeouts`. Identify where interrupts hand off work and where the main loop services networking. This informs F01 and S03. If the team selects an RTOS, use its supported lwIP port and execution rules instead of copying this loop unchanged. |
| Before the radio adapter | [lwIP — Network interface API](https://www.nongnu.org/lwip/2_1_x/netif_8h.html) | Look up `netif_add`, input/output callback types, and interface/link state. Trace which callbacks handle IP packets versus Ethernet frames before implementing N03. |
| Before DMA integration | [lwIP — Packet buffers (`pbuf`)](https://www.nongnu.org/lwip/2_1_x/group__pbuf.html) | Read the overview and `pbuf_alloc`, `pbuf_copy_partial`, `pbuf_ref`, and `pbuf_free`. Pay attention to packet chains, `len` versus `tot_len`, and lifetime during asynchronous transmission. Supports F03/N03/N05. |
| Later, for forwarding | [lwIP — IPv4 options](https://www.nongnu.org/lwip/2_1_x/group__lwip__opts__ipv4.html) and [routing hooks](https://www.nongnu.org/lwip/2_1_x/group__lwip__opts__hooks.html) | Look up `IP_FORWARD`, MTU-related fragmentation/reassembly options, and `LWIP_HOOK_IP4_ROUTE` / `LWIP_HOOK_IP4_ROUTE_SRC`. These are references for N04 and B04, after ordinary interface behavior is understood. Hook return values matter: `NULL` allows normal route lookup to continue. |

**Version check:** The upstream lwIP links above describe the 2.1.x documentation series; AMD's library guide also documents `lwip220`. Pin the actual Vivado/Vitis, platform/BSP, embeddedsw and lwIP versions in S02. Confirm symbols and configuration in that source before adapting an example.

**Preparation exercise:** For one packet, draw `Ethernet RX -> lwIP -> radio0 -> TX buffer -> DMA completion`. State which code owns the bytes at every step, what happens if the radio queue is full, and when the memory can be reused. Then draw the return path. Keep the IP destination-to-interface decision separate from peer-to-beam selection.

**First practical result:** Reproduce the selected board's Ethernet example and observe local ping and TCP echo as separate tests. Save configuration and captures. For AMD's supplied performance examples, check its stated iperf version: those examples use iperf2, which is a separate consideration from testing ordinary routed PC traffic. [AMD test guidance](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842366/Standalone%2BLWIP%2Blibrary).

## FPGA and Verilog

**Goal:** Build confidence with clocked logic and interfaces before joining the full modem. Start with Boolean logic, registers and binary arithmetic; use D02's reference-model work to learn the required fixed-point formats.

| When | Reading | What to read and why |
|---|---|---|
| Start | [HDLBits — Problem sets](https://hdlbits.01xz.net/wiki/Problem_sets) | Work through **Vectors**, **Modules**, combinational and clocked **Always blocks**, **Avoiding Latches**, **DFFs**, **Counters**, and basic **FSMs**. Then try **Reading Simulations** and **Writing Testbenches**. This establishes the RTL skills used in F02, D03/D04 and B01. |
| Start before F02/F03 | [AMD UG1037 — AXI Reference Guide](https://docs.amd.com/v/u/en-US/ug1037-vivado-axi-reference-guide) | Read Chapter 1's **What is AXI?** / **How AXI Works**, then the stream interoperability and signal-summary sections. Distinguish AXI4-Lite register access, memory transactions and AXI4-Stream data movement. This older guide explains protocol concepts; match configuration details to the installed IP documentation. |
| Reference for F03/D05 | [AMD PG021 — Simple DMA](https://docs.amd.com/r/en-US/pg021_axi_dma/Direct-Register-Mode-Simple-DMA) and [AXI DMA standalone driver documentation](https://xilinx.github.io/embeddedsw.github.io/axidma/doc/html/api/index.html) | Read the simple-transfer sequence and driver sections on **Examples**, **Cache Coherency**, **Alignment**, and **Address Translation**. Understand memory-to-stream versus stream-to-memory, completion, errors and buffer visibility. Read descriptor-ring ownership when scatter/gather is actually selected. |
| Before hardware integration | [AMD UG949 — Clock Domain Crossing](https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Clock-Domain-Crossing) | Read the single-bit and multibit CDC sections; consult the same guide's reset and timing-constraint guidance. Identify crossings between processor/control, DMA and converter/sample clocks. Simulation results do not replace timing and CDC review. |

Choose the processor tutorial after H01: [AMD's Zynq-7000 PS/PL tutorial](https://docs.amd.com/r/en-US/ug1165-zynq-embedded-design-tutorial/Using-the-Zynq-SoC-Processing-System) explains hardware export, processor software and adding programmable-logic IP; the [MicroBlaze tutorial](https://xilinx.github.io/Embedded-Design-Tutorials/docs/2023.1/build/html/docs/Feature_Tutorials/microblaze-system/README.html) illustrates a soft-processor flow. These are conditional examples, not a board selection or universal build recipe. Use the tutorial for your actual family and release.

**Exercise 1:** Write an 8-bit counter with synchronous reset and enable. A self-checking testbench should cover reset, disabled cycles and wraparound.

**Exercise 2:** Simulate a packet source and sink with random stalls. Count a transfer only when `TVALID && TREADY`; check data and sideband stability while stalled, correct `TLAST`, and `TKEEP` where the chosen interface uses it. Verify that no word is lost, duplicated or reordered. These are preparation for F03's packet boundary.

**Exercise 3:** Draw the DMA buffer lifecycle and a clock/reset table. For every crossing, identify whether it carries a status bit, an event, a multibit value or a stream. Explain the selected synchronization or buffering method.

Our packet and sample interfaces need separate rate assumptions: continuous converter streams may require overflow/underflow handling instead of arbitrary stalling. Record that behavior in S03. [AXI stream interoperability reference](https://docs.amd.com/v/u/en-US/ug1037-vivado-axi-reference-guide).

## Modem DSP

**Goal:** Create a software reference that recovers a complete packet before translating its arithmetic into RTL. Start after the shared I/Q chapter. The following are chapters of Marc Lichtman's original [PySDR textbook](https://pysdr.org/content/sampling).

| Order | Reading | Selected sections and ticket connection |
|---|---|---|
| 1 | [Digital Modulation](https://pysdr.org/content/digital_modulation) | Read **Symbols**, **Phase Shift Keying (PSK)** and **IQ Plots/Constellations**. Use this to understand the proposed BPSK/QPSK starting point in D01; the exact waveform is still a team decision. |
| 2 | [Pulse Shaping](https://pysdr.org/content/pulse_shaping) | Read **Inter-Symbol-Interference**, **Matched Filter**, **Splitting a Filter in Half**, and raised-cosine/root-raised-cosine filtering; then try the Python exercise. Connect TX/RX filtering to D01–D04. |
| 3 | [Synchronization](https://pysdr.org/content/sync) | Read channel simulation, time synchronization, coarse/fine frequency synchronization, and especially **Frame Synchronization**. Keep symbol timing, carrier recovery and packet-start detection distinct. This informs D04 and the short HAIL/ACK bursts in B02/B03. |

**Exercise:** Generate a known bit sequence, map symbols, apply TX/RX filters, and recover the original bits in an ideal channel. Then add noise, carrier offset and timing offset one at a time. Add a preamble and measure whether the receiver finds the start of a burst. Record the settings and failure cases. These exercises are reference-model preparation; the capstone frame format, CRC, receiver state machine and robustness tests remain implementation work.

**Before D03/D04:** Write down bit order, symbol mapping, sample rate, samples per symbol, numeric widths, rounding/saturation and pipeline latency expectations. Export golden vectors from D02. A constellation plot alone is not a complete packet-delivery result.

## Hardware and beamforming

**Goal:** Understand the physical signal path and build a measured array model. Start with the shared I/Q reading; conventional beam steering is enough for the first directional prototype.

| When | Reading | Selected sections and ticket connection |
|---|---|---|
| Start before H03 | [PySDR — Link Budgets](https://pysdr.org/content/link_budgets) | Read **Signal Power Budget**, antenna gains/path loss and the noise/SNR discussion. Make separate A-to-B and B-to-A budgets using your actual components and measured losses. Treat worked-example numbers as examples. |
| Start for H04/H05 | [Analog Devices — Phased Array Antenna Patterns, Part 1](https://www.analog.com/en/resources/analog-dialogue/articles/phased-array-antenna-patterns-part1.html) | Read **Beam Direction**, **Array Factor for a Linear Array**, and the beamwidth discussion. Connect element spacing, phase progression and steering angle. |
| Then, for B01 | [PySDR — Beamforming and DOA](https://pysdr.org/content/doa) | Read the overview, array types, steering vectors, receiving a signal and **Conventional Beamforming & DOA**. Connect complex weights to TX steering and RX combining. Advanced MVDR/MUSIC methods can wait. |
| Later, before measured array validation | [PySDR — 2D Beamforming](https://pysdr.org/content/2d_beamforming) | Go directly to **Processing Signals from an Actual 2D Array**, especially the phase/amplitude calibration example. Its recorded-data exercise is useful even if this project uses a different array geometry. It does not require adopting the illustrated hardware. |

**Exercise:** Simulate the proposed four-element geometry, generate weights for several beam IDs, and plot the resulting patterns. Introduce channel phase/gain errors, apply estimated corrections, and compare the result. Record channel ordering and angle/sign conventions. H05 will compare the model with measurements through the B01 datapath.

Keep two problems separate: synchronization between independent radio nodes concerns carrier, symbol and frame timing; array calibration concerns relative channel response inside one node. Deterministic channel timing and clock/LO behavior also need hardware verification. See the [synchronization chapter](https://pysdr.org/content/sync), the [array calibration example](https://pysdr.org/content/2d_beamforming), and our [hardware decisions](project-plan.md#hardware-and-modem-decisions-that-can-block-progress).

For H01/H02, collect the selected board's schematic/user guide, processor memory map, Ethernet MAC/PHY documents, converter/transceiver guide, and clock/LO configuration guide. Use them to establish how many complete RF antenna paths the hardware provides; converter count alone is insufficient to choose the architecture.

## Discovery discussion exercise

Before B02, draw a HAIL/ACK timeline for both nodes. Show each node's current TX/RX beam, listening intervals, transmit/receive turnaround, ACK return beam, lost frames, timeout and retry. Try different startup phases.

Explain how the first link-control exchange can succeed before an IP route exists, what decoded information identifies the peer, and what validates the return path. Then show how its result reaches the neighbor table and route manager. This is a design exercise for our protocol; the beamforming readings do not provide a ready-made discovery/routing solution.

## Host tools and team workflow

| Reading | Focus | Preparation task |
|---|---|---|
| [Wireshark introduction](https://www.wireshark.org/docs/wsug_html_chunked/ChapterIntroduction.html) and [display filters](https://www.wireshark.org/docs/wsug_html_chunked/ChWorkBuildDisplayFilterSection.html) | Understand capture/packet inspection and simple protocol filters. Useful display filters for this project include `arp`, `icmp`, `udp`, `tcp` and `ip.addr == 192.168.10.1`; use the address from the actual test configuration. | On an available lab connection, capture a ping and identify its request/reply and any observed ARP exchange. Record interface and address settings. If ARP is already cached, explain why a new exchange may be absent. Save the capture and a short explanation for S04/N02. |
| [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow) | Read branch, commit, pull request, review and merge. Relate the workflow to our issue and PR templates. | Make a small documentation change on a branch, link the relevant issue in a pull request, and ask another teammate to review the result and evidence. |

## Team readiness check

Before implementation begins, each module owner should be able to explain these project questions in a short team walkthrough:

- **Networking:** Which packets are delivered to the local FPGA, which are forwarded, and how does the return path work?
- **Firmware/transport:** Who owns a packet buffer before, during and after DMA, and what happens when the radio is slower than Ethernet?
- **RTL:** What constitutes a valid transfer, how are packet boundaries represented, and which clocks/resets does the path cross?
- **Modem:** What separates bits, symbols and samples, and what must the receiver recover before declaring a valid frame?
- **Hardware/beamforming:** What are the actual RF paths, which impairments require calibration, and how are beam weights applied and measured?
- **Discovery:** How do two scanning nodes meet, acknowledge each other and make a route usable without relying on an already-established IP route?

Use unclear answers to refine S01/S03 or the relevant implementation ticket. The next deliverables remain the [existing milestone demonstrations](project-plan.md#milestone-exit-criteria); reading is preparation for those demonstrations.

Links and selected sections checked on October 4, 2026. Vendor manuals and upstream examples are references; the chosen board and pinned toolchain determine the implementation details.
