# Implementation ticket backlog

These **34 task specifications are published as GitHub issues** in [le21-j/wireless-beamforming-network](https://github.com/le21-j/wireless-beamforming-network/issues). Each task uses its GitHub issue number. The list follows M0 to M5, with prerequisites first. Issue numbers are fixed identifiers, not the work sequence. The [issue index](github-issues.md) links to each task and its prerequisites. Use the [project plan](project-plan.md) for the architecture, dependency graph, address plan and module boundaries.

Owner roles below name workstreams, not individual teammates. Assign one primary owner and one reviewer to each ticket. A shared interface change needs review from both affected modules. Priorities are P0 for M0–M3, P1 for M4, and P2 for optional M5 work. Milestones identify the required demonstration; they do not prevent useful work from starting in parallel once prerequisites are met.

Numeric acceptance gates are **proposed initial targets for ratification in #1**, not measured results or hardware performance guarantees. Throughput, RF operating point, MTU and discovery timeout remain decisions until the hardware and budgets are known. If #14, #13 or another ticket grows beyond roughly three focused working days, split it into child tasks while preserving the parent ID and its acceptance gate. No calendar estimates or teammate assignments are implied.

## Work order

| Issue | Task | Milestone | Priority | Depends on |
|---|---|---|---|---|
| [#1](#issue-1) | Decide hardware, scope and demo targets | M0 | P0 | None |
| [#2](#issue-2) | Verify board Ethernet, clock and processor feasibility | M0 | P0 | #1 |
| [#3](#issue-3) | Make the repository and tool versions reproducible | M0 | P0 | #1 |
| [#4](#issue-4) | Freeze IP, frame, register and buffer contracts | M0 | P0 | #1 |
| [#6](#issue-6) | Bring up boot, BSP, UART and timers | M1 | P0 | #2, #3 |
| [#8](#issue-8) | Build the host test harness and evidence format | M1 | P0 | #1, #4 |
| [#11](#issue-11) | Bring up Ethernet MAC, PHY, eth0 and lwIP | M1 | P0 | #6 |
| [#17](#issue-17) | Prove local PC ICMP and UDP on both boards | M1 | P0 | #11, #8 |
| [#5](#issue-5) | Build the floating-point modem reference and link framing | M2 | P0 | #4 |
| [#7](#issue-7) | Prepare the RF bench, link budget and attenuators | M2 | P0 | #2, #1 |
| [#9](#issue-9) | Produce fixed-point reference vectors | M2 | P0 | #5 |
| [#10](#issue-10) | Implement AXI-Lite control/status RTL and driver | M2 | P0 | #6, #4 |
| [#12](#issue-12) | Implement the FPGA transmit modem | M2 | P0 | #9 |
| [#13](#issue-13) | Implement the FPGA receive modem | M2 | P0 | #9 |
| [#14](#issue-14) | Prove DMA packet loopback and buffer ownership | M2 | P0 | #10, #4 |
| [#16](#issue-16) | Bring up converters and one RF I/Q path | M2 | P0 | #2, #10 |
| [#19](#issue-19) | Prove digital frame modem loopback | M2 | P0 | #12, #13, #14 |
| [#21](#issue-21) | Prove bidirectional conducted RF with independent oscillators | M2 | P0 | #19, #16, #7 |
| [#15](#issue-15) | Implement the half-duplex TDD scheduler | M3 | P0 | #4, #10, #5 |
| [#20](#issue-20) | Implement radio0 with a mock IP backend | M3 | P0 | #17, #4 |
| [#22](#issue-22) | Prove routes and actual IP forwarding without RF | M3 | P0 | #20 |
| [#23](#issue-23) | Prove an OTA packet link with fixed antennas or beams | M3 | P0 | #21, #15 |
| [#27](#issue-27) | Bind radio0 to wireless DMA and connect the PCs | M3 | P0 | #22, #14, #15, #23 |
| [#29](#issue-29) | Measure PC-to-PC performance and run regression | M3 | P0 | #27, #8 |
| [#18](#issue-18) | Simulate discovery and rendezvous | M4 | P1 | #4, #15 |
| [#24](#issue-24) | Establish coherent timing and calibration for four RF paths | M4 | P1 | #16, #7, #21 |
| [#26](#issue-26) | Implement the beamformer and atomic beam control | M4 | P1 | #24, #10 |
| [#28](#issue-28) | Create the beam codebook and measure patterns | M4 | P1 | #24, #26 |
| [#31](#issue-31) | Run directional HAIL/ACK sweeps over the air | M4 | P1 | #26, #18, #23, #28 |
| [#32](#issue-32) | Integrate fresh neighbor/beam state with routing | M4 | P1 | #31, #27 |
| [#33](#issue-33) | Prove blockage, rediscovery and end-to-end recovery | M4 | P1 | #32, #29 |
| [#25](#issue-25) | Evaluate adaptive throughput or a FEC upgrade | M5 | P2 | #21 |
| [#30](#issue-30) | Add per-LAN DHCP or host provisioning convenience | M5 | P2 | #27 |
| [#34](#issue-34) | Optionally implement an actual L2 Ethernet bridge | M5 | P2 | #33 |

## Prerequisites and parallel work

- **Ready now:** #1. Resolve the exact hardware, intended demonstrations and proposed gates as a team.
- **After #1:** #3, #4 and #2 can proceed in parallel.
- **After those foundations:** #6 begins platform/network bring-up; #5 begins modem modeling; #7 prepares the RF fixture; #8 builds host tests. Each starts only after its listed prerequisites.
- **Next independent integration targets:** #10/#14 provide packet transport; #20/#22 exercise forwarding using the mock backend; #9/#12/#13 develop the modem. Hardware work prepares #16 while the digital models mature.
- **Main demonstrations:** #17 closes M1, #21 closes M2, #29 closes M3 and #33 closes M4. Preserve a working fixed-link M3 configuration while developing discovery.

For every completed ticket, link the code/design changes and store an evidence report with build IDs, configuration, commands or procedure, expected result, actual result and failures. RF reports also record carrier, modulation, symbol/sample rates, payload lengths, gains, attenuation or distance/orientation, and oscillator arrangement. Keep first-attempt packet error rate separate from final delivery after retries.

## M0 Foundations

<a id="s01--decide-hardware-scope-and-demo-targets"></a>
<a id="issue-1"></a>

### #1 — Decide hardware, scope and demo targets

**Owner role:** Integration and tooling, with all module owners. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** None.

**Scope:** Record the two FPGA/processor boards, converter/transceiver and antenna topology, equipment access, team ownership, and intended L3 demonstration. Ratify or revise the proposed gates and identify unresolved feasibility questions.

**Acceptance:**

- Inventory names exact board/front-end parts, real versus complex converter channels, available Ethernet MAC/PHY, clocks/LOs and required licenses.
- Team agrees on the order local ping → modem bench → fixed-link PC-to-PC routing → directional discovery; L2 bridging remains optional.
- Record initial MTU/rate/range constraints and a process for choosing a feasible operating point. Ratify M1 1,000 loss-free local pings, M2 10,000 frames per direction at ≤1% PER, M3 ICMP/UDP/TCP gates, and M4 19 of 20 recoveries within an agreed timeout, or document revisions.
- Assign primary/reviewer roles and name each open question with an owner; do not invent performance guarantees or dates.

**Evidence:** Decision record, hardware inventory, owner matrix and approved gate table.

<a id="h01--verify-board-ethernet-clock-and-processor-feasibility"></a>
<a id="issue-2"></a>

### #2 — Verify board Ethernet, clock and processor feasibility

**Owner role:** Hardware and RF. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** #1.

**Scope:** Check the physical platform against the proposed architecture before committing to processor, converter, Ethernet and beamformer implementations.

**Acceptance:**

- Draw the processor/memory, Ethernet MAC/PHY, converter/transceiver, clocks/LO and antenna-path map for each node.
- Confirm usable Ethernet ports, processor memory, FPGA interfaces/pin constraints, converter data path and tool/IP support against the selected hardware documentation.
- Resolve whether four DAC/ADC channels actually provide four RF antenna paths; record any missing hardware and a feasible single-path baseline.

**Evidence:** Annotated block diagram, part/document references, port/channel map and feasibility decision.

<a id="s02--make-the-repository-and-tool-versions-reproducible"></a>
<a id="issue-3"></a>

### #3 — Make the repository and tool versions reproducible

**Owner role:** Integration and tooling. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** #1.

**Scope:** Establish the repository layout, pinned FPGA/embedded/model tool versions, setup steps, build entry points and handling of generated outputs.

**Acceptance:**

- Document exact tool/BSP/lwIP versions and required licensed components, with accessible setup instructions.
- A teammate can reproduce the available baseline or template build from a clean checkout; record any hardware/vendor dependency still awaiting #2/#6.
- Source, constraints, scripts and configuration are versioned; generated binaries, caches and large build directories have an explicit storage policy.

**Evidence:** Setup/build guide, version manifest and clean-checkout build log.

<a id="s03--freeze-ip-frame-register-and-buffer-contracts"></a>
<a id="issue-4"></a>

### #4 — Freeze IP, frame, register and buffer contracts

**Owner role:** Integration and tooling, reviewed by networking, transport, modem and discovery owners. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** #1.

**Scope:** Define the versioned boundaries that let module teams work independently: raw IPv4 radio packets, radio frame fields, CPU/FPGA registers, DMA ownership, beam application and link-state events.

**Acceptance:**

- Specify IP MTU and oversize/DF behavior; frame lengths/endianness/CRC coverage; DATA, HAIL and ACK identifiers; peer, sequence and transaction fields.
- Specify register/reset behavior, AXI packet boundaries, DMA alignment/cache duties, completion/errors, bounded queues and lwIP callback context.
- Define separate local TX/RX beam fields, calibration version, applied-beam acknowledgement, freshness/expiry events and fixed peer-to-remote-prefix mapping.
- A worked packet example and ownership/state diagrams are reviewed by both sides of every shared interface.

**Evidence:** Versioned interface specification, example frame bytes and review record.

## M1 Local network

<a id="f01--bring-up-boot-bsp-uart-and-timers"></a>
<a id="issue-6"></a>

### #6 — Bring up boot, BSP, UART and timers

**Owner role:** Embedded platform and transport. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** #2, #3.

**Scope:** Create the supported processor/BSP baseline and minimal runtime needed by Ethernet, control drivers and timestamped diagnostics on both nodes.

**Acceptance:**

- Both boards boot a documented image and report board/build identifiers over UART or an equivalent debug channel.
- Monotonic timers, memory configuration and required interrupts work; reset returns the application to a known state.
- Choose and document the supported bare-metal or RTOS/lwIP execution model and the handoff rules between interrupts and application processing.

**Evidence:** Build/boot instructions, images or artifact references, UART logs from both boards and timer/interrupt checks.

<a id="s04--build-the-host-test-harness-and-evidence-format"></a>
<a id="issue-8"></a>

### #8 — Build the host test harness and evidence format

**Owner role:** Integration and tooling. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** #1, #4.

**Scope:** Provide reusable host traffic, capture and reporting tools for local Ethernet, modem and later routed-wireless demonstrations.

**Acceptance:**

- Scripts send/count ICMP and sequenced UDP traffic with known payloads, distinguish missing/duplicate/corrupt packets, and compute file SHA-256.
- Host setup records interface addresses, specific remote-LAN routes, MTU and firewall rules used, with a documented cleanup procedure.
- Reports include build/configuration IDs, timestamps, offered load, duration, counters and pass/fail thresholds; simulated loss/corruption produces a failure rather than a false pass.

**Evidence:** Runnable harness, example passing/failing reports and capture procedure.

<a id="n01--bring-up-ethernet-mac-phy-eth0-and-lwip"></a>
<a id="issue-11"></a>

### #11 — Bring up Ethernet MAC, PHY, eth0 and lwIP

The [Linux/USB adapter](../firmware/net/lwip_ethernet/README.md) passed ARP, link recovery and local traffic on both Plutos. Linux supplies the USB driver. The bare-metal or RTOS MAC/PHY work specified below remains open.

**Owner role:** Networking. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** #6.

**Scope:** Bring up the selected Ethernet MAC/PHY driver and a static IPv4 `eth0` interface using the pinned vendor lwIP/BSP configuration on both boards.

**Acceptance:**

- PHY link state/speed and MAC addresses are visible and correct for both nodes; disconnect/reconnect is handled.
- `eth0` has the planned address/netmask and handles ARP plus received Ethernet traffic through the intended lwIP context/timer path.
- Memory/pbuf settings, checksum configuration and required lwIP features are recorded; errors and drops are observable.

**Evidence:** lwIP/BSP configuration, initialization logs, ARP capture and link reconnect results.

<a id="n02--prove-local-pc-icmp-and-udp-on-both-boards"></a>
<a id="issue-17"></a>

### #17 — Prove local PC ICMP and UDP on both boards

The [Linux USB endpoint](../firmware/net/lwip_ethernet/README.md) supports local ping and UDP checks. The original two-PC and board-support requirements remain open. Saved bench results stay local.

**Owner role:** Networking, verified by integration and tooling. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** #11, #8.

**Scope:** Demonstrate each companion PC communicating with its own FPGA endpoint over Ethernet. This is endpoint connectivity, not the routing milestone.

**Acceptance:**

- After ARP warm-up, all 1,000 ICMP requests receive replies on each of the two local PC↔node links.
- Known UDP payloads arrive unchanged at the endpoint/echo test; test lengths include agreed boundaries.
- Repeat the documented test after node restart and save addressing, host configuration and interface/error counters.

**Evidence:** Separate reports for both boards, packet captures, UART/build IDs and UDP payload comparison.

## M2 Modem bench

<a id="d01--build-the-floating-point-modem-reference-and-link-framing"></a>
<a id="issue-5"></a>

### #5 — Build the floating-point modem reference and link framing

**Owner role:** Modem, reviewed by link scheduling and beam control. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #4.

**Scope:** Choose the initial feasible burst waveform and build the reference transmitter/receiver with the agreed frame format and acquisition behavior.

**Acceptance:**

- DATA, HAIL and ACK examples encode/decode with the agreed preamble/header/length/CRC fields and preserve known payloads in an ideal channel.
- Define modulation, filters, rates, burst overhead and acquisition/turnaround assumptions; document amplitude, frequency and timing conventions.
- Exercise documented noise, timing offset and carrier-offset cases; reject invalid lengths/CRC rather than returning unchecked payloads.

**Evidence:** Reproducible reference model, parameter file, golden frame examples and impairment results.

<a id="h03--prepare-the-rf-bench-link-budget-and-attenuators"></a>
<a id="issue-7"></a>

### #7 — Prepare the RF bench, link budget and attenuators

**Owner role:** Hardware and RF. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #2, #1.

**Scope:** Design and document the conducted RF fixture and initial RF operating envelope using the actual selected hardware and test equipment.

**Acceptance:**

- Record expected/measured TX power, path and attenuator losses, RX limits, gain settings and measurement uncertainty at the selected frequency.
- The cabled fixture, connectors, attenuators and any required isolation are identified; calculated receive levels remain within selected equipment ratings and usable range.
- Provide a repeatable setup diagram and operating-point checklist, including independent-node oscillator configuration for #21.

**Evidence:** Link-budget worksheet, fixture diagram, component ratings and measured power/loss results.

<a id="d02--produce-fixed-point-reference-vectors"></a>
<a id="issue-9"></a>

### #9 — Produce fixed-point reference vectors

**Owner role:** Modem. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #5.

**Scope:** Define fixed-point widths/scaling, rounding/saturation and deterministic golden vectors for hardware implementation.

**Acceptance:**

- Specify formats at every modem boundary and reproduce representative minimum/maximum/boundary-length frames.
- Ideal cases decode payloads bit-exactly; quantify fixed-point effects against the floating-point reference at agreed impairment points.
- Publish repeatable TX sample and RX intermediate/output vectors with explicit tolerances where implementation arithmetic differs.

**Evidence:** Fixed-point model, format table, versioned vectors, comparison script and results.

<a id="f02--implement-axi-lite-controlstatus-rtl-and-driver"></a>
<a id="issue-10"></a>

### #10 — Implement AXI-Lite control/status RTL and driver

**Owner role:** Embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #6, #4.

**Scope:** Implement the versioned CPU-to-FPGA control/status bank and matching firmware driver, including reset, capability and error visibility.

**Acceptance:**

- RTL and driver agree on offsets, widths, access permissions, endianness, version and reset values; read/write tests pass on hardware.
- Status/event handling is deterministic across reset and clock-domain boundaries; invalid or unsupported requests have defined outcomes.
- Counters and error/status fields needed by converter, transport and modem bring-up are readable without disturbing active operation.

**Evidence:** Register map, RTL test results, driver API and on-board register/status log.

<a id="d03--implement-the-fpga-transmit-modem"></a>
<a id="issue-12"></a>

### #12 — Implement the FPGA transmit modem

**Owner role:** Modem. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #9.

**Scope:** Implement framing, symbol mapping, pulse shaping and sample output for the selected burst modem.

**Acceptance:**

- Ideal RTL outputs match the fixed-point reference at defined comparison boundaries, including complete preamble/header/payload/CRC framing.
- Minimum/maximum frames, inter-frame gaps, reset and backpressure produce correct boundaries and no extra/missing payload symbols.
- Resource/timing results support the agreed sample/clock rate, or record the required rate/design revision before integration.

**Evidence:** RTL simulation/vector comparison, representative waveforms and synthesis/timing report.

<a id="d04--implement-the-fpga-receive-modem"></a>
<a id="issue-13"></a>

### #13 — Implement the FPGA receive modem

**Owner role:** Modem. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #9.

**Scope:** Implement burst detection, filtering, symbol timing, carrier-frequency/phase recovery, frame parsing and CRC. Split into focused child tasks if needed, keeping one integrated receiver gate.

**Acceptance:**

- Ideal reference vectors yield bit-exact payloads; frames with bad CRC, invalid length or incomplete acquisition never reach the valid-payload output.
- Detection and recovery work over the explicitly agreed timing/carrier/noise envelope, including the shortest HAIL/ACK bursts.
- Reset, truncated frames, false detections and receive-output backpressure recover without deadlock or unbounded buffering.
- Expose acquisition, length, CRC and drop counters and record implementation timing/resource results.

**Evidence:** Receiver test matrix, reference comparisons, impairment/acquisition plots, RTL traces and synthesis report.

<a id="f03--prove-dma-packet-loopback-and-buffer-ownership"></a>
<a id="issue-14"></a>

### #14 — Prove DMA packet loopback and buffer ownership

**Owner role:** Embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #10, #4.

**Scope:** Transfer complete packets through CPU→FPGA→CPU loopback with explicit buffer ownership, alignment, cache maintenance, completion and interrupt handoff. Split into child tasks if implementation exceeds a small ticket.

**Acceptance:**

- Minimum, maximum and boundary-length payloads return byte-for-byte with correct packet boundaries and completion lengths.
- Ownership and cache operations are correct through repeated transfers, concurrent producer/consumer activity and ring wraparound; no buffer is reused early.
- Backpressure, queue-full, invalid-length, timeout and reset paths release or reclaim resources predictably and increment the right counters.
- Interrupt work follows the agreed execution model; a sustained run shows bounded buffer/descriptor usage rather than growth.

**Evidence:** Loopback test logs, length/stress/error cases, buffer-state diagram, cache/interrupt notes and relevant logic traces.

<a id="h02--bring-up-converters-and-one-rf-iq-path"></a>
<a id="issue-16"></a>

### #16 — Bring up converters and one RF I/Q path

**Owner role:** Hardware and RF, supported by embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #2, #10.

**Scope:** Configure clocks, resets and converter/transceiver interfaces; prove a single transmit and receive sample path with known stimuli.

**Acceptance:**

- Converter clocks and status reach the documented stable state after reset; sample rate and I/Q/channel ordering are verified.
- A known digital tone/pattern reaches the selected TX path and a known RX stimulus produces expected samples without unexplained clipping, lane swaps or data loss.
- Gain, scaling, DC offset and frequency/sign conventions are recorded for the modem team; status/errors are visible through #10.

**Evidence:** Bring-up procedure, register configuration, captured samples, instrument plots and clock/reset status logs.

<a id="d05--prove-digital-frame-modem-loopback"></a>
<a id="issue-19"></a>

### #19 — Prove digital frame modem loopback

**Owner role:** Modem, supported by embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #12, #13, #14.

**Scope:** Connect the complete CPU packet→DMA→TX modem→digital loopback→RX modem→DMA→CPU path before introducing analog RF.

**Acceptance:**

- Ideal loopback delivers known payloads bit-exactly for the agreed packet-length suite and repeated back-to-back frames.
- Injected corruption produces CRC failures and no falsely accepted payload; known missing/truncated frames are counted.
- Reset, pacing/backpressure and sustained traffic leave DMA descriptors, queues and receiver state bounded and reusable.

**Evidence:** Full-path test report, payload comparisons, CRC/error counters and selected logic traces.

<a id="d06--prove-bidirectional-conducted-rf-with-independent-oscillators"></a>
<a id="issue-21"></a>

### #21 — Prove bidirectional conducted RF with independent oscillators

**Owner role:** Modem, supported by hardware and RF. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** #19, #16, #7.

**Scope:** Exchange framed packets between two physical nodes over the documented attenuated RF fixture. Separate manual-role A→B and B→A runs are valid here; automated TDD is implemented in #15.

**Acceptance:**

- With the intended independent node oscillators, send 10,000 frames in each direction and obtain first-attempt packet error rate ≤1% at the recorded operating point.
- Received valid payloads match transmitted bytes; malformed/bad-CRC frames are rejected, with unique delivered frames and retry effects reported separately.
- Record acquisition behavior, error counters, rates, gains, attenuation and oscillator arrangement; any shared-reference debug result is labeled separately.

**Evidence:** M2 bench report, RF fixture/settings, transmitted/received frame logs, payload checks and acquisition/error plots.

## M3 Routed wireless

<a id="f04--implement-the-half-duplex-tdd-scheduler"></a>
<a id="issue-15"></a>

### #15 — Implement the half-duplex TDD scheduler

**Owner role:** Link scheduling and beam control. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** #4, #10, #5.

**Scope:** Define and implement transmit ownership, receive windows, turnaround/guard time, matching ACKs, bounded retries and control-frame priority for the first bidirectional link.

**Acceptance:**

- Both roles follow a documented state machine with measured or modeled airtime/turnaround budgets; concurrent startup has a deterministic resolution.
- Lost, late and duplicate ACKs do not acknowledge the wrong packet; retries/timeouts are bounded and duplicate delivery behavior is defined.
- DATA traffic cannot indefinitely starve HAIL/ACK/control service; all queues have explicit limits and overflow outcomes.
- Simulated or loopback traces cover normal exchange, timeout, contention and reset/rejoin without deadlock.

**Evidence:** Timing/state diagrams, scheduling configuration, fault-case traces and queue/retry counter results.

<a id="n03--implement-radio0-with-a-mock-ip-backend"></a>
<a id="issue-20"></a>

### #20 — Implement radio0 with a mock IP backend

**Owner role:** Networking. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** #17, #4.

**Scope:** Add a raw-IP `radio0` lwIP interface and mock transport adapter so networking can be developed before RF integration.

**Acceptance:**

- Known IPv4 packets pass between the mock backend and `radio0` with correct lengths, checksums and agreed pbuf ownership/context.
- MTU/oversize behavior, queue-full and link-down outcomes match #4; raw-IP radio traffic does not require Ethernet headers or ARP on the radio link.
- Mock injection/capture supports controlled loss, delayed completion and malformed input without leaks or a crash.

**Evidence:** Adapter API, mock harness, packet captures and ownership/error-path results.

<a id="n04--prove-routes-and-actual-ip-forwarding-without-rf"></a>
<a id="issue-22"></a>

### #22 — Prove routes and actual IP forwarding without RF

**Owner role:** Networking. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** #20.

**Scope:** Enable actual IPv4 forwarding between `eth0` and `radio0`; implement the static remote-LAN policy and prove it with mock, injected-packet or two-node harness traffic.

**Acceptance:**

- Packets for the remote PC leave the intended interface with original PC source/destination addresses and correct TTL/checksum handling; return traffic routes correctly.
- Tests distinguish local delivery from forwarding and cover no route, TTL expiry and the chosen MTU/DF behavior.
- Removing the remote route or taking the radio link down prevents stale forwarding; restoration resumes without reboot.

**Evidence:** lwIP forwarding/route configuration, address/route tables and ingress/egress captures. An application relay does not satisfy this ticket.

<a id="d07--prove-an-ota-packet-link-with-fixed-antennas-or-beams"></a>
<a id="issue-23"></a>

### #23 — Prove an OTA packet link with fixed antennas or beams

**Owner role:** Modem, supported by hardware and RF and link scheduling and beam control. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** #21, #15.

**Scope:** Move the framed link over the air using a fixed antenna configuration or manually selected fixed beam and the TDD scheduler.

**Acceptance:**

- Both nodes exchange known DATA/control payloads over the fixed RF path with logged first-attempt error rate and final delivery; record the agreed distance/orientation and operating point.
- Simultaneous offered traffic follows TDD ownership, ACK/retry bounds and control priority without persistent collisions or starvation.
- Measure sustainable payload capacity and latency sufficiently to set a below-capacity UDP offered rate for #29.
- Link interruption/reappearance recovers the fixed-path packet service without requiring automatic beam discovery.

**Evidence:** OTA setup diagram, frame/counter logs, throughput/latency measurements and interruption trace.

<a id="n05--bind-radio0-to-wireless-dma-and-connect-the-pcs"></a>
<a id="issue-27"></a>

### #27 — Bind radio0 to wireless DMA and connect the PCs

**Owner role:** Networking, supported by embedded platform and transport, link scheduling and modem owners. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** #22, #14, #15, #23.

**Scope:** Replace the mock backend with the packet transport and fixed-wireless link; route ordinary IP traffic between the two companion PCs.

**Acceptance:**

- Both PCs ping each other through their local node and the RF link using documented static routes; known UDP payloads cross intact in both directions.
- Captures/counters trace the same PC-addressed packets through Ethernet, `radio0`, DMA and the modem without TCP proxying or unintended NAT.
- MTU, Ethernet-to-radio backpressure and link-down/recovery paths follow the shared contract with bounded resources.
- The integrated build and RF settings are reproducible and ready for the full #29 performance gate.

**Evidence:** End-to-end packet traces, route/configuration dumps, build references and integrated smoke-test report.

<a id="s05--measure-pc-to-pc-performance-and-run-regression"></a>
<a id="issue-29"></a>

### #29 — Measure PC-to-PC performance and run regression

**Owner role:** Integration and tooling, supported by networking and modem owners. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** #27, #8.

**Scope:** Run the full fixed-wireless demonstration between companion PCs and establish a reproducible baseline for future beam/discovery changes.

**Acceptance:**

- At least 99% of 1,000 ICMP requests succeed in each direction; report RTT distribution and timeout count.
- A 10-minute sequenced UDP run at a stated rate below measured sustainable capacity loses at most 1%; report offered/delivered rates, duplicates and payload integrity for each tested direction.
- A 10 MB TCP file crosses the link with identical source/destination SHA-256; captures confirm preserved PC endpoints and expected routed TTL handling.
- Link interruption and restoration have bounded queues and no crash/leak; a repeatable regression run includes local ping and the fixed-link baseline.

**Evidence:** M3 report, scripts/configurations, packet captures, RF operating point, counters and file hashes.

## M4 Direction aware

<a id="b02--simulate-discovery-and-rendezvous"></a>
<a id="issue-18"></a>

### #18 — Simulate discovery and rendezvous

**Owner role:** Discovery and directional policy, reviewed by link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #4, #15.

**Scope:** Define initiator/responder roles, TX/RX sweep order, receive dwell, guard time, ACK return path and timeout/retry behavior before OTA sweeps.

**Acceptance:**

- State-machine simulation demonstrates rendezvous for the intended beam-pair coverage and different startup phases; document assumptions and any bounded search limit.
- Lost/late/duplicate HAILs or ACKs cannot validate the wrong peer/transaction; a responder returns the ACK on a usable planned path.
- Choose discovery/expiry/recovery timeouts from the scan schedule and RF switching/acquisition budgets, and preserve control opportunities during payload traffic.

**Evidence:** Protocol/state/timing specification, simulation scenarios and traces, timeout derivation and agreed recovery gate.

<a id="h04--establish-coherent-timing-and-calibration-for-four-rf-paths"></a>
<a id="issue-24"></a>

### #24 — Establish coherent timing and calibration for four RF paths

**Owner role:** Hardware and RF. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #16, #7, #21.

**Scope:** Extend the proven single-path system to the intended four RF antenna paths; measure deterministic alignment and separate TX/RX amplitude/phase corrections.

**Acceptance:**

- All intended RF paths have a verified channel map and deterministic timing/coherence behavior under the chosen clock/LO/reset arrangement.
- Measure relative amplitude/phase across TX paths and across RX paths; validate calculated corrections offline or with existing converter controls and compare residuals against agreed tolerances. #26/#28 verify application in the implemented beamformer.
- Repeat calibration checks after restart; document recalibration triggers and store versioned correction data with frequency/settings.

**Evidence:** Multichannel timing captures, before/after calibration measurements, coefficients and restart-repeatability report.

<a id="b01--implement-the-beamformer-and-atomic-beam-control"></a>
<a id="issue-26"></a>

### #26 — Implement the beamformer and atomic beam control

**Owner role:** Link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #24, #10.

**Scope:** Implement or integrate the multichannel beamformer and matching driver. Distribute and weight TX samples across antenna paths; align, weight and combine RX samples before modem decoding. Apply calibrated coefficients atomically at allowed boundaries. Document any weighting/combining performed inside the selected RF front end. Split datapath and control into child issues if needed.

**Acceptance:**

- TX fanout/complex weights and RX alignment/weighted sum match a fixed-point reference for known channel inputs and coefficients, including phase convention, scaling, saturation and latency.
- Firmware requests and hardware confirms the correct local TX/RX coefficient bank/beam ID and calibration version; known weights support #28 codebook measurements.
- Bank commit/switching honors frame boundaries and measured settling time; no frame uses an unintended mixture of old/new coefficients.
- Invalid IDs, reset and interrupted updates have defined behavior; implementation meets the agreed per-channel sample rate and records timing/resource usage.

**Evidence:** Datapath reference/vector comparisons, driver/register tests, coefficient/bank traces, boundary-switch tests and timing/resource report.

<a id="h05--create-the-beam-codebook-and-measure-patterns"></a>
<a id="issue-28"></a>

### #28 — Create the beam codebook and measure patterns

**Owner role:** Hardware and RF, reviewed by link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #24, #26.

**Scope:** Define array geometry, angle conventions and discrete steering entries; validate them using measured TX/RX directional behavior through the #26 beamformer and control interface.

**Acceptance:**

- Codebook identifies beam IDs, angle convention, channel order, coefficient format and calibration composition for separate TX/RX use.
- Measure representative or all intended sector responses using a repeatable geometry; compare intended and observed direction and document coverage gaps/ambiguities.
- Choose the initial discovery sector set and switching/settling requirements from measured behavior rather than assuming ideal array patterns.

**Evidence:** Versioned codebook, array drawing, pattern plots, measurement setup and validated sector list.

<a id="b03--run-directional-hailack-sweeps-over-the-air"></a>
<a id="issue-31"></a>

### #31 — Run directional HAIL/ACK sweeps over the air

**Owner role:** Discovery and directional policy, supported by link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #26, #18, #23, #28.

**Scope:** Connect the discovery state machine to measured beam entries and the functioning RF link; validate a bidirectional HAIL/ACK exchange before declaring a peer reachable.

**Acceptance:**

- Sweeps produce logs of requested/applied TX/RX beam IDs, peer/transaction IDs, timestamps and measured quality with units.
- Only a matching valid exchange marks a beam pair usable; energy detection or unrelated/stale ACKs cannot establish reachability.
- Discovery works across the planned orientations/startup cases and can restart after a timeout using the #18 schedule.

**Evidence:** OTA sweep logs, geometry/beam settings, valid/invalid exchange traces and discovery-time results.

<a id="b04--integrate-fresh-neighborbeam-state-with-routing"></a>
<a id="issue-32"></a>

### #32 — Integrate fresh neighbor/beam state with routing

**Owner role:** Discovery and directional policy, reviewed by networking. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #31, #27.

**Scope:** Maintain peer-to-beam/quality/freshness state and notify the route manager when the configured remote LAN becomes reachable or unreachable through `radio0`.

**Acceptance:**

- A validated peer activates the intended remote-prefix route and uses the selected local TX/RX beams; IP routing policy remains separate from beam metadata.
- Stale or failed neighbor state withdraws usable forwarding within the agreed expiry interval without unintended fallback to a default interface; duplicate/stale events cannot reinstall an invalid route. Account for lwIP route-hook `NULL` continuing ordinary lookup rather than explicitly dropping a packet.
- Wireless TX revalidates or discards already queued packets after expiry; queues remain bounded. Quality changes/hysteresis are observable, and recovery restores the route without changing PC addresses or rebooting.

**Evidence:** Neighbor/route event traces, before/after tables, expiry tests and PC traffic captures.

<a id="b05--prove-blockage-rediscovery-and-end-to-end-recovery"></a>
<a id="issue-33"></a>

### #33 — Prove blockage, rediscovery and end-to-end recovery

**Owner role:** Discovery and directional policy, verified by integration and tooling. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** #32, #29.

**Scope:** Run controlled end-to-end trials that disturb the usable directional link and demonstrate stale-state expiry, rediscovery and resumed PC traffic.

**Acceptance:**

- Across 20 controlled trials, at least 19 restore PC traffic within the timeout agreed from #1/#18; define the disturbance and the recovery start/end events before testing.
- Logs show the lost/expired neighbor, route withdrawal, new matching exchange, selected beam pair, route restoration and first restored PC payload.
- Record discovery/recovery time, quality, geometry, packet loss and failure reasons; no stale route persists beyond expiry, no remote traffic falls back to an unintended interface, and queued packets/resources remain bounded during loss and recovery.
- The fixed-link M3 configuration remains reproducible and the #29 regression does not introduce an unexplained failure.

**Evidence:** M4 trial table, synchronized event/traffic logs, geometry/beam records and regression report.

## M5 Optional extensions

<a id="x03--evaluate-adaptive-throughput-or-a-fec-upgrade"></a>
<a id="issue-25"></a>

### #25 — Evaluate adaptive throughput or a FEC upgrade

**Owner role:** Modem, reviewed by link scheduling and beam control. **Milestone:** M5 stretch. **Priority:** P2. **Depends on:** #21.

**Scope:** Choose one measured improvement, such as FEC or a controlled throughput mode, after identifying the baseline limitation. Do not bundle several new modem architectures into one ticket.

**Acceptance:**

- Define the selected change, compatibility/mode agreement, added latency/resources and success metric before implementation.
- Compare baseline and upgraded first-attempt errors, delivered goodput and latency at the same recorded operating points; account for coding/handshake overhead.
- Mismatched mode or a failed upgrade has defined behavior, and the original modem mode still passes its relevant regression tests.

**Evidence:** Design decision, reference/RTL changes, controlled comparison report and compatibility/regression results.

<a id="x02--add-per-lan-dhcp-or-host-provisioning-convenience"></a>
<a id="issue-30"></a>

### #30 — Add per-LAN DHCP or host provisioning convenience

**Owner role:** Networking, supported by integration and tooling. **Milestone:** M5 stretch. **Priority:** P2. **Depends on:** #27.

**Scope:** Select either per-LAN DHCP support or repeatable host setup tooling to reduce manual address/route configuration for demonstrations.

**Acceptance:**

- Chosen setup method produces the correct non-overlapping LAN addresses, remote connectivity and MTU settings on both PCs without disrupting unrelated interfaces.
- DHCP, if selected, is scoped per routed LAN and tested for renewal/reconnect; provisioning scripts, if selected, can show and undo their changes.
- A fresh-host setup reaches the fixed-link PC-to-PC test using documented steps; static configuration remains a usable fallback.

**Evidence:** Provisioning code/configuration, fresh-host test, lease or route captures and cleanup/fallback instructions.

<a id="x01--optionally-implement-an-actual-l2-ethernet-bridge"></a>
<a id="issue-34"></a>

### #34 — Optionally implement an actual L2 Ethernet bridge

**Owner role:** Networking. **Milestone:** M5 stretch. **Priority:** P2. **Depends on:** #33.

**Scope:** If selected after the baseline, extend or replace the raw-IP radio adapter with Ethernet-frame transport and implement actual same-subnet bridging.

**Acceptance:**

- Two same-subnet PCs communicate through the bridge without remote-subnet routes; preserve Ethernet frame semantics and the agreed MTU.
- Verify ARP/broadcast handling, MAC learning/ageing and unknown-unicast behavior with bounded tables/queues and a documented loop-free topology assumption.
- A dedicated L2 test suite passes and the separate routed L3 baseline can still be reproduced.

**Evidence:** Revised architecture/frame contract, MAC/ARP captures, L2 tests and baseline regression results.
