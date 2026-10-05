# Implementation ticket backlog

These **34 ticket specifications are published as GitHub issues** in [le21-j/wireless-beamforming-network](https://github.com/le21-j/wireless-beamforming-network/issues). The IDs are stable planning references, distinct from GitHub issue numbers; use the [live issue index](github-issues.md) for direct links. Published issue bodies include linked prerequisites and acceptance checkboxes. Use the [project plan](project-plan.md) for the architecture, dependency graph, address plan and module boundaries.

Owner roles below name workstreams, not individual teammates. Assign one primary owner and one reviewer to each ticket. A shared interface change needs review from both affected modules. Priorities are P0 for M0–M3, P1 for M4, and P2 for optional M5 work. Milestones identify the required demonstration; they do not prevent useful work from starting in parallel once prerequisites are met.

Numeric acceptance gates are **proposed initial targets for ratification in S01**, not measured results or hardware performance guarantees. Throughput, RF operating point, MTU and discovery timeout remain decisions until the hardware and budgets are known. If F03, D04 or another ticket grows beyond roughly three focused working days, split it into child tasks while preserving the parent ID and its acceptance gate. No calendar estimates or teammate assignments are implied.

## Index

| ID | Ticket | Milestone | Priority | Depends on |
|---|---|---|---|---|
| [S01](#s01--decide-hardware-scope-and-demo-targets) | Decide hardware, scope and demo targets | M0 | P0 | None |
| [S02](#s02--make-the-repository-and-tool-versions-reproducible) | Make the repository and tool versions reproducible | M0 | P0 | S01 |
| [S03](#s03--freeze-ip-frame-register-and-buffer-contracts) | Freeze IP, frame, register and buffer contracts | M0 | P0 | S01 |
| [S04](#s04--build-the-host-test-harness-and-evidence-format) | Build the host test harness and evidence format | M1 | P0 | S01, S03 |
| [S05](#s05--measure-pc-to-pc-performance-and-run-regression) | Measure PC-to-PC performance and run regression | M3 | P0 | N05, S04 |
| [H01](#h01--verify-board-ethernet-clock-and-processor-feasibility) | Verify board Ethernet, clock and processor feasibility | M0 | P0 | S01 |
| [H02](#h02--bring-up-converters-and-one-rf-iq-path) | Bring up converters and one RF I/Q path | M2 | P0 | H01, F02 |
| [H03](#h03--prepare-the-rf-bench-link-budget-and-attenuators) | Prepare the RF bench, link budget and attenuators | M2 | P0 | H01, S01 |
| [H04](#h04--establish-coherent-timing-and-calibration-for-four-rf-paths) | Establish coherent timing and calibration for four RF paths | M4 | P1 | H02, H03, D06 |
| [H05](#h05--create-the-beam-codebook-and-measure-patterns) | Create the beam codebook and measure patterns | M4 | P1 | H04, B01 |
| [F01](#f01--bring-up-boot-bsp-uart-and-timers) | Bring up boot, BSP, UART and timers | M1 | P0 | H01, S02 |
| [F02](#f02--implement-axi-lite-controlstatus-rtl-and-driver) | Implement AXI-Lite control/status RTL and driver | M2 | P0 | F01, S03 |
| [F03](#f03--prove-dma-packet-loopback-and-buffer-ownership) | Prove DMA packet loopback and buffer ownership | M2 | P0 | F02, S03 |
| [F04](#f04--implement-the-half-duplex-tdd-scheduler) | Implement the half-duplex TDD scheduler | M3 | P0 | S03, F02, D01 |
| [N01](#n01--bring-up-ethernet-mac-phy-eth0-and-lwip) | Bring up Ethernet MAC, PHY, eth0 and lwIP | M1 | P0 | F01 |
| [N02](#n02--prove-local-pc-icmp-and-udp-on-both-boards) | Prove local PC ICMP and UDP on both boards | M1 | P0 | N01, S04 |
| [N03](#n03--implement-radio0-with-a-mock-ip-backend) | Implement radio0 with a mock IP backend | M3 | P0 | N02, S03 |
| [N04](#n04--prove-routes-and-actual-ip-forwarding-without-rf) | Prove routes and actual IP forwarding without RF | M3 | P0 | N03 |
| [N05](#n05--bind-radio0-to-wireless-dma-and-connect-the-pcs) | Bind radio0 to wireless DMA and connect the PCs | M3 | P0 | N04, F03, F04, D07 |
| [D01](#d01--build-the-floating-point-modem-reference-and-link-framing) | Build the floating-point modem reference and link framing | M2 | P0 | S03 |
| [D02](#d02--produce-fixed-point-reference-vectors) | Produce fixed-point reference vectors | M2 | P0 | D01 |
| [D03](#d03--implement-the-fpga-transmit-modem) | Implement the FPGA transmit modem | M2 | P0 | D02 |
| [D04](#d04--implement-the-fpga-receive-modem) | Implement the FPGA receive modem | M2 | P0 | D02 |
| [D05](#d05--prove-digital-frame-modem-loopback) | Prove digital frame modem loopback | M2 | P0 | D03, D04, F03 |
| [D06](#d06--prove-bidirectional-conducted-rf-with-independent-oscillators) | Prove bidirectional conducted RF with independent oscillators | M2 | P0 | D05, H02, H03 |
| [D07](#d07--prove-an-ota-packet-link-with-fixed-antennas-or-beams) | Prove an OTA packet link with fixed antennas or beams | M3 | P0 | D06, F04 |
| [B01](#b01--implement-the-beamformer-and-atomic-beam-control) | Implement the beamformer and atomic beam control | M4 | P1 | H04, F02 |
| [B02](#b02--simulate-discovery-and-rendezvous) | Simulate discovery and rendezvous | M4 | P1 | S03, F04 |
| [B03](#b03--run-directional-hailack-sweeps-over-the-air) | Run directional HAIL/ACK sweeps over the air | M4 | P1 | B01, B02, D07, H05 |
| [B04](#b04--integrate-fresh-neighborbeam-state-with-routing) | Integrate fresh neighbor/beam state with routing | M4 | P1 | B03, N05 |
| [B05](#b05--prove-blockage-rediscovery-and-end-to-end-recovery) | Prove blockage, rediscovery and end-to-end recovery | M4 | P1 | B04, S05 |
| [X01](#x01--optionally-implement-an-actual-l2-ethernet-bridge) | Optionally implement an actual L2 Ethernet bridge | M5 | P2 | B05 |
| [X02](#x02--add-per-lan-dhcp-or-host-provisioning-convenience) | Add per-LAN DHCP or host provisioning convenience | M5 | P2 | N05 |
| [X03](#x03--evaluate-adaptive-throughput-or-a-fec-upgrade) | Evaluate adaptive throughput or a FEC upgrade | M5 | P2 | D06 |

## Ready and next

- **Ready now:** S01. Resolve the exact hardware, intended demonstrations and proposed gates as a team.
- **After S01:** S02, S03 and H01 can proceed in parallel.
- **After those foundations:** F01 begins platform/network bring-up; D01 begins modem modeling; H03 prepares the RF fixture; S04 builds host tests. Each starts only after its listed prerequisites.
- **Next independent integration targets:** F02/F03 provide packet transport; N03/N04 exercise forwarding using the mock backend; D02/D03/D04 develop the modem. Hardware work prepares H02 while the digital models mature.
- **Main demonstrations:** N02 closes M1, D06 closes M2, S05 closes M3 and B05 closes M4. Preserve a working fixed-link M3 configuration while developing discovery.

For every completed ticket, link the code/design changes and store an evidence report with build IDs, configuration, commands or procedure, expected result, actual result and failures. RF reports also record carrier, modulation, symbol/sample rates, payload lengths, gains, attenuation or distance/orientation, and oscillator arrangement. Keep first-attempt packet error rate separate from final delivery after retries.

## System and integration tickets

### S01 — Decide hardware, scope and demo targets

**Owner role:** Integration and tooling, with all module owners. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** None.

**Scope:** Record the two FPGA/processor boards, converter/transceiver and antenna topology, equipment access, team ownership, and intended L3 demonstration. Ratify or revise the proposed gates and identify unresolved feasibility questions.

**Acceptance:**

- Inventory names exact board/front-end parts, real versus complex converter channels, available Ethernet MAC/PHY, clocks/LOs and required licenses.
- Team agrees on the order local ping → modem bench → fixed-link PC-to-PC routing → directional discovery; L2 bridging remains optional.
- Record initial MTU/rate/range constraints and a process for choosing a feasible operating point. Ratify M1 1,000 loss-free local pings, M2 10,000 frames per direction at ≤1% PER, M3 ICMP/UDP/TCP gates, and M4 19 of 20 recoveries within an agreed timeout, or document revisions.
- Assign primary/reviewer roles and name each open question with an owner; do not invent performance guarantees or dates.

**Evidence:** Decision record, hardware inventory, owner matrix and approved gate table.

### S02 — Make the repository and tool versions reproducible

**Owner role:** Integration and tooling. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** S01.

**Scope:** Establish the repository layout, pinned FPGA/embedded/model tool versions, setup steps, build entry points and handling of generated outputs.

**Acceptance:**

- Document exact tool/BSP/lwIP versions and required licensed components, with accessible setup instructions.
- A teammate can reproduce the available baseline or template build from a clean checkout; record any hardware/vendor dependency still awaiting H01/F01.
- Source, constraints, scripts and configuration are versioned; generated binaries, caches and large build directories have an explicit storage policy.

**Evidence:** Setup/build guide, version manifest and clean-checkout build log.

### S03 — Freeze IP, frame, register and buffer contracts

**Owner role:** Integration and tooling, reviewed by networking, transport, modem and discovery owners. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** S01.

**Scope:** Define the versioned boundaries that let module teams work independently: raw IPv4 radio packets, radio frame fields, CPU/FPGA registers, DMA ownership, beam application and link-state events.

**Acceptance:**

- Specify IP MTU and oversize/DF behavior; frame lengths/endianness/CRC coverage; DATA, HAIL and ACK identifiers; peer, sequence and transaction fields.
- Specify register/reset behavior, AXI packet boundaries, DMA alignment/cache duties, completion/errors, bounded queues and lwIP callback context.
- Define separate local TX/RX beam fields, calibration version, applied-beam acknowledgement, freshness/expiry events and fixed peer-to-remote-prefix mapping.
- A worked packet example and ownership/state diagrams are reviewed by both sides of every shared interface.

**Evidence:** Versioned interface specification, example frame bytes and review record.

### S04 — Build the host test harness and evidence format

**Owner role:** Integration and tooling. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** S01, S03.

**Scope:** Provide reusable host traffic, capture and reporting tools for local Ethernet, modem and later routed-wireless demonstrations.

**Acceptance:**

- Scripts send/count ICMP and sequenced UDP traffic with known payloads, distinguish missing/duplicate/corrupt packets, and compute file SHA-256.
- Host setup records interface addresses, specific remote-LAN routes, MTU and firewall rules used, with a documented cleanup procedure.
- Reports include build/configuration IDs, timestamps, offered load, duration, counters and pass/fail thresholds; simulated loss/corruption produces a failure rather than a false pass.

**Evidence:** Runnable harness, example passing/failing reports and capture procedure.

### S05 — Measure PC-to-PC performance and run regression

**Owner role:** Integration and tooling, supported by networking and modem owners. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** N05, S04.

**Scope:** Run the full fixed-wireless demonstration between companion PCs and establish a reproducible baseline for future beam/discovery changes.

**Acceptance:**

- At least 99% of 1,000 ICMP requests succeed in each direction; report RTT distribution and timeout count.
- A 10-minute sequenced UDP run at a stated rate below measured sustainable capacity loses at most 1%; report offered/delivered rates, duplicates and payload integrity for each tested direction.
- A 10 MB TCP file crosses the link with identical source/destination SHA-256; captures confirm preserved PC endpoints and expected routed TTL handling.
- Link interruption and restoration have bounded queues and no crash/leak; a repeatable regression run includes local ping and the fixed-link baseline.

**Evidence:** M3 report, scripts/configurations, packet captures, RF operating point, counters and file hashes.

## Hardware and RF tickets

### H01 — Verify board Ethernet, clock and processor feasibility

**Owner role:** Hardware and RF. **Milestone:** M0 foundations. **Priority:** P0. **Depends on:** S01.

**Scope:** Check the physical platform against the proposed architecture before committing to processor, converter, Ethernet and beamformer implementations.

**Acceptance:**

- Draw the processor/memory, Ethernet MAC/PHY, converter/transceiver, clocks/LO and antenna-path map for each node.
- Confirm usable Ethernet ports, processor memory, FPGA interfaces/pin constraints, converter data path and tool/IP support against the selected hardware documentation.
- Resolve whether four DAC/ADC channels actually provide four RF antenna paths; record any missing hardware and a feasible single-path baseline.

**Evidence:** Annotated block diagram, part/document references, port/channel map and feasibility decision.

### H02 — Bring up converters and one RF I/Q path

**Owner role:** Hardware and RF, supported by embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** H01, F02.

**Scope:** Configure clocks, resets and converter/transceiver interfaces; prove a single transmit and receive sample path with known stimuli.

**Acceptance:**

- Converter clocks and status reach the documented stable state after reset; sample rate and I/Q/channel ordering are verified.
- A known digital tone/pattern reaches the selected TX path and a known RX stimulus produces expected samples without unexplained clipping, lane swaps or data loss.
- Gain, scaling, DC offset and frequency/sign conventions are recorded for the modem team; status/errors are visible through F02.

**Evidence:** Bring-up procedure, register configuration, captured samples, instrument plots and clock/reset status logs.

### H03 — Prepare the RF bench, link budget and attenuators

**Owner role:** Hardware and RF. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** H01, S01.

**Scope:** Design and document the conducted RF fixture and initial RF operating envelope using the actual selected hardware and test equipment.

**Acceptance:**

- Record expected/measured TX power, path and attenuator losses, RX limits, gain settings and measurement uncertainty at the selected frequency.
- The cabled fixture, connectors, attenuators and any required isolation are identified; calculated receive levels remain within selected equipment ratings and usable range.
- Provide a repeatable setup diagram and operating-point checklist, including independent-node oscillator configuration for D06.

**Evidence:** Link-budget worksheet, fixture diagram, component ratings and measured power/loss results.

### H04 — Establish coherent timing and calibration for four RF paths

**Owner role:** Hardware and RF. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** H02, H03, D06.

**Scope:** Extend the proven single-path system to the intended four RF antenna paths; measure deterministic alignment and separate TX/RX amplitude/phase corrections.

**Acceptance:**

- All intended RF paths have a verified channel map and deterministic timing/coherence behavior under the chosen clock/LO/reset arrangement.
- Measure relative amplitude/phase across TX paths and across RX paths; validate calculated corrections offline or with existing converter controls and compare residuals against agreed tolerances. B01/H05 verify application in the implemented beamformer.
- Repeat calibration checks after restart; document recalibration triggers and store versioned correction data with frequency/settings.

**Evidence:** Multichannel timing captures, before/after calibration measurements, coefficients and restart-repeatability report.

### H05 — Create the beam codebook and measure patterns

**Owner role:** Hardware and RF, reviewed by link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** H04, B01.

**Scope:** Define array geometry, angle conventions and discrete steering entries; validate them using measured TX/RX directional behavior through the B01 beamformer and control interface.

**Acceptance:**

- Codebook identifies beam IDs, angle convention, channel order, coefficient format and calibration composition for separate TX/RX use.
- Measure representative or all intended sector responses using a repeatable geometry; compare intended and observed direction and document coverage gaps/ambiguities.
- Choose the initial discovery sector set and switching/settling requirements from measured behavior rather than assuming ideal array patterns.

**Evidence:** Versioned codebook, array drawing, pattern plots, measurement setup and validated sector list.

## Embedded platform, transport and scheduling tickets

### F01 — Bring up boot, BSP, UART and timers

**Owner role:** Embedded platform and transport. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** H01, S02.

**Scope:** Create the supported processor/BSP baseline and minimal runtime needed by Ethernet, control drivers and timestamped diagnostics on both nodes.

**Acceptance:**

- Both boards boot a documented image and report board/build identifiers over UART or an equivalent debug channel.
- Monotonic timers, memory configuration and required interrupts work; reset returns the application to a known state.
- Choose and document the supported bare-metal or RTOS/lwIP execution model and the handoff rules between interrupts and application processing.

**Evidence:** Build/boot instructions, images or artifact references, UART logs from both boards and timer/interrupt checks.

### F02 — Implement AXI-Lite control/status RTL and driver

**Owner role:** Embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** F01, S03.

**Scope:** Implement the versioned CPU-to-FPGA control/status bank and matching firmware driver, including reset, capability and error visibility.

**Acceptance:**

- RTL and driver agree on offsets, widths, access permissions, endianness, version and reset values; read/write tests pass on hardware.
- Status/event handling is deterministic across reset and clock-domain boundaries; invalid or unsupported requests have defined outcomes.
- Counters and error/status fields needed by converter, transport and modem bring-up are readable without disturbing active operation.

**Evidence:** Register map, RTL test results, driver API and on-board register/status log.

### F03 — Prove DMA packet loopback and buffer ownership

**Owner role:** Embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** F02, S03.

**Scope:** Transfer complete packets through CPU→FPGA→CPU loopback with explicit buffer ownership, alignment, cache maintenance, completion and interrupt handoff. Split into child tasks if implementation exceeds a small ticket.

**Acceptance:**

- Minimum, maximum and boundary-length payloads return byte-for-byte with correct packet boundaries and completion lengths.
- Ownership and cache operations are correct through repeated transfers, concurrent producer/consumer activity and ring wraparound; no buffer is reused early.
- Backpressure, queue-full, invalid-length, timeout and reset paths release or reclaim resources predictably and increment the right counters.
- Interrupt work follows the agreed execution model; a sustained run shows bounded buffer/descriptor usage rather than growth.

**Evidence:** Loopback test logs, length/stress/error cases, buffer-state diagram, cache/interrupt notes and relevant logic traces.

### F04 — Implement the half-duplex TDD scheduler

**Owner role:** Link scheduling and beam control. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** S03, F02, D01.

**Scope:** Define and implement transmit ownership, receive windows, turnaround/guard time, matching ACKs, bounded retries and control-frame priority for the first bidirectional link.

**Acceptance:**

- Both roles follow a documented state machine with measured or modeled airtime/turnaround budgets; concurrent startup has a deterministic resolution.
- Lost, late and duplicate ACKs do not acknowledge the wrong packet; retries/timeouts are bounded and duplicate delivery behavior is defined.
- DATA traffic cannot indefinitely starve HAIL/ACK/control service; all queues have explicit limits and overflow outcomes.
- Simulated or loopback traces cover normal exchange, timeout, contention and reset/rejoin without deadlock.

**Evidence:** Timing/state diagrams, scheduling configuration, fault-case traces and queue/retry counter results.

## Networking tickets

### N01 — Bring up Ethernet MAC, PHY, eth0 and lwIP

**Owner role:** Networking. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** F01.

**Scope:** Bring up the selected Ethernet MAC/PHY driver and a static IPv4 `eth0` interface using the pinned vendor lwIP/BSP configuration on both boards.

**Acceptance:**

- PHY link state/speed and MAC addresses are visible and correct for both nodes; disconnect/reconnect is handled.
- `eth0` has the planned address/netmask and handles ARP plus received Ethernet traffic through the intended lwIP context/timer path.
- Memory/pbuf settings, checksum configuration and required lwIP features are recorded; errors and drops are observable.

**Evidence:** lwIP/BSP configuration, initialization logs, ARP capture and link reconnect results.

### N02 — Prove local PC ICMP and UDP on both boards

**Owner role:** Networking, verified by integration and tooling. **Milestone:** M1 local ping. **Priority:** P0. **Depends on:** N01, S04.

**Scope:** Demonstrate each companion PC communicating with its own FPGA endpoint over Ethernet. This is endpoint connectivity, not the routing milestone.

**Acceptance:**

- After ARP warm-up, all 1,000 ICMP requests receive replies on each of the two local PC↔node links.
- Known UDP payloads arrive unchanged at the endpoint/echo test; test lengths include agreed boundaries.
- Repeat the documented test after node restart and save addressing, host configuration and interface/error counters.

**Evidence:** Separate reports for both boards, packet captures, UART/build IDs and UDP payload comparison.

### N03 — Implement radio0 with a mock IP backend

**Owner role:** Networking. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** N02, S03.

**Scope:** Add a raw-IP `radio0` lwIP interface and mock transport adapter so networking can be developed before RF integration.

**Acceptance:**

- Known IPv4 packets pass between the mock backend and `radio0` with correct lengths, checksums and agreed pbuf ownership/context.
- MTU/oversize behavior, queue-full and link-down outcomes match S03; raw-IP radio traffic does not require Ethernet headers or ARP on the radio link.
- Mock injection/capture supports controlled loss, delayed completion and malformed input without leaks or a crash.

**Evidence:** Adapter API, mock harness, packet captures and ownership/error-path results.

### N04 — Prove routes and actual IP forwarding without RF

**Owner role:** Networking. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** N03.

**Scope:** Enable actual IPv4 forwarding between `eth0` and `radio0`; implement the static remote-LAN policy and prove it with mock, injected-packet or two-node harness traffic.

**Acceptance:**

- Packets for the remote PC leave the intended interface with original PC source/destination addresses and correct TTL/checksum handling; return traffic routes correctly.
- Tests distinguish local delivery from forwarding and cover no route, TTL expiry and the chosen MTU/DF behavior.
- Removing the remote route or taking the radio link down prevents stale forwarding; restoration resumes without reboot.

**Evidence:** lwIP forwarding/route configuration, address/route tables and ingress/egress captures. An application relay does not satisfy this ticket.

### N05 — Bind radio0 to wireless DMA and connect the PCs

**Owner role:** Networking, supported by embedded platform and transport, link scheduling and modem owners. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** N04, F03, F04, D07.

**Scope:** Replace the mock backend with the packet transport and fixed-wireless link; route ordinary IP traffic between the two companion PCs.

**Acceptance:**

- Both PCs ping each other through their local node and the RF link using documented static routes; known UDP payloads cross intact in both directions.
- Captures/counters trace the same PC-addressed packets through Ethernet, `radio0`, DMA and the modem without TCP proxying or unintended NAT.
- MTU, Ethernet-to-radio backpressure and link-down/recovery paths follow the shared contract with bounded resources.
- The integrated build and RF settings are reproducible and ready for the full S05 performance gate.

**Evidence:** End-to-end packet traces, route/configuration dumps, build references and integrated smoke-test report.

## Modem tickets

### D01 — Build the floating-point modem reference and link framing

**Owner role:** Modem, reviewed by link scheduling and beam control. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** S03.

**Scope:** Choose the initial feasible burst waveform and build the reference transmitter/receiver with the agreed frame format and acquisition behavior.

**Acceptance:**

- DATA, HAIL and ACK examples encode/decode with the agreed preamble/header/length/CRC fields and preserve known payloads in an ideal channel.
- Define modulation, filters, rates, burst overhead and acquisition/turnaround assumptions; document amplitude, frequency and timing conventions.
- Exercise documented noise, timing offset and carrier-offset cases; reject invalid lengths/CRC rather than returning unchecked payloads.

**Evidence:** Reproducible reference model, parameter file, golden frame examples and impairment results.

### D02 — Produce fixed-point reference vectors

**Owner role:** Modem. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** D01.

**Scope:** Define fixed-point widths/scaling, rounding/saturation and deterministic golden vectors for hardware implementation.

**Acceptance:**

- Specify formats at every modem boundary and reproduce representative minimum/maximum/boundary-length frames.
- Ideal cases decode payloads bit-exactly; quantify fixed-point effects against the floating-point reference at agreed impairment points.
- Publish repeatable TX sample and RX intermediate/output vectors with explicit tolerances where implementation arithmetic differs.

**Evidence:** Fixed-point model, format table, versioned vectors, comparison script and results.

### D03 — Implement the FPGA transmit modem

**Owner role:** Modem. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** D02.

**Scope:** Implement framing, symbol mapping, pulse shaping and sample output for the selected burst modem.

**Acceptance:**

- Ideal RTL outputs match the fixed-point reference at defined comparison boundaries, including complete preamble/header/payload/CRC framing.
- Minimum/maximum frames, inter-frame gaps, reset and backpressure produce correct boundaries and no extra/missing payload symbols.
- Resource/timing results support the agreed sample/clock rate, or record the required rate/design revision before integration.

**Evidence:** RTL simulation/vector comparison, representative waveforms and synthesis/timing report.

### D04 — Implement the FPGA receive modem

**Owner role:** Modem. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** D02.

**Scope:** Implement burst detection, filtering, symbol timing, carrier-frequency/phase recovery, frame parsing and CRC. Split into focused child tasks if needed, keeping one integrated receiver gate.

**Acceptance:**

- Ideal reference vectors yield bit-exact payloads; frames with bad CRC, invalid length or incomplete acquisition never reach the valid-payload output.
- Detection and recovery work over the explicitly agreed timing/carrier/noise envelope, including the shortest HAIL/ACK bursts.
- Reset, truncated frames, false detections and receive-output backpressure recover without deadlock or unbounded buffering.
- Expose acquisition, length, CRC and drop counters and record implementation timing/resource results.

**Evidence:** Receiver test matrix, reference comparisons, impairment/acquisition plots, RTL traces and synthesis report.

### D05 — Prove digital frame modem loopback

**Owner role:** Modem, supported by embedded platform and transport. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** D03, D04, F03.

**Scope:** Connect the complete CPU packet→DMA→TX modem→digital loopback→RX modem→DMA→CPU path before introducing analog RF.

**Acceptance:**

- Ideal loopback delivers known payloads bit-exactly for the agreed packet-length suite and repeated back-to-back frames.
- Injected corruption produces CRC failures and no falsely accepted payload; known missing/truncated frames are counted.
- Reset, pacing/backpressure and sustained traffic leave DMA descriptors, queues and receiver state bounded and reusable.

**Evidence:** Full-path test report, payload comparisons, CRC/error counters and selected logic traces.

### D06 — Prove bidirectional conducted RF with independent oscillators

**Owner role:** Modem, supported by hardware and RF. **Milestone:** M2 modem bench. **Priority:** P0. **Depends on:** D05, H02, H03.

**Scope:** Exchange framed packets between two physical nodes over the documented attenuated RF fixture. Separate manual-role A→B and B→A runs are valid here; automated TDD is implemented in F04.

**Acceptance:**

- With the intended independent node oscillators, send 10,000 frames in each direction and obtain first-attempt packet error rate ≤1% at the recorded operating point.
- Received valid payloads match transmitted bytes; malformed/bad-CRC frames are rejected, with unique delivered frames and retry effects reported separately.
- Record acquisition behavior, error counters, rates, gains, attenuation and oscillator arrangement; any shared-reference debug result is labeled separately.

**Evidence:** M2 bench report, RF fixture/settings, transmitted/received frame logs, payload checks and acquisition/error plots.

### D07 — Prove an OTA packet link with fixed antennas or beams

**Owner role:** Modem, supported by hardware and RF and link scheduling and beam control. **Milestone:** M3 PC-to-PC fixed wireless. **Priority:** P0. **Depends on:** D06, F04.

**Scope:** Move the framed link over the air using a fixed antenna configuration or manually selected fixed beam and the TDD scheduler.

**Acceptance:**

- Both nodes exchange known DATA/control payloads over the fixed RF path with logged first-attempt error rate and final delivery; record the agreed distance/orientation and operating point.
- Simultaneous offered traffic follows TDD ownership, ACK/retry bounds and control priority without persistent collisions or starvation.
- Measure sustainable payload capacity and latency sufficiently to set a below-capacity UDP offered rate for S05.
- Link interruption/reappearance recovers the fixed-path packet service without requiring automatic beam discovery.

**Evidence:** OTA setup diagram, frame/counter logs, throughput/latency measurements and interruption trace.

## Beam and discovery tickets

### B01 — Implement the beamformer and atomic beam control

**Owner role:** Link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** H04, F02.

**Scope:** Implement or integrate the multichannel beamformer and matching driver. Distribute and weight TX samples across antenna paths; align, weight and combine RX samples before modem decoding. Apply calibrated coefficients atomically at allowed boundaries. Document any weighting/combining performed inside the selected RF front end. Split datapath and control into child issues if needed.

**Acceptance:**

- TX fanout/complex weights and RX alignment/weighted sum match a fixed-point reference for known channel inputs and coefficients, including phase convention, scaling, saturation and latency.
- Firmware requests and hardware confirms the correct local TX/RX coefficient bank/beam ID and calibration version; known weights support H05 codebook measurements.
- Bank commit/switching honors frame boundaries and measured settling time; no frame uses an unintended mixture of old/new coefficients.
- Invalid IDs, reset and interrupted updates have defined behavior; implementation meets the agreed per-channel sample rate and records timing/resource usage.

**Evidence:** Datapath reference/vector comparisons, driver/register tests, coefficient/bank traces, boundary-switch tests and timing/resource report.

### B02 — Simulate discovery and rendezvous

**Owner role:** Discovery and directional policy, reviewed by link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** S03, F04.

**Scope:** Define initiator/responder roles, TX/RX sweep order, receive dwell, guard time, ACK return path and timeout/retry behavior before OTA sweeps.

**Acceptance:**

- State-machine simulation demonstrates rendezvous for the intended beam-pair coverage and different startup phases; document assumptions and any bounded search limit.
- Lost/late/duplicate HAILs or ACKs cannot validate the wrong peer/transaction; a responder returns the ACK on a usable planned path.
- Choose discovery/expiry/recovery timeouts from the scan schedule and RF switching/acquisition budgets, and preserve control opportunities during payload traffic.

**Evidence:** Protocol/state/timing specification, simulation scenarios and traces, timeout derivation and agreed recovery gate.

### B03 — Run directional HAIL/ACK sweeps over the air

**Owner role:** Discovery and directional policy, supported by link scheduling and beam control. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** B01, B02, D07, H05.

**Scope:** Connect the discovery state machine to measured beam entries and the functioning RF link; validate a bidirectional HAIL/ACK exchange before declaring a peer reachable.

**Acceptance:**

- Sweeps produce logs of requested/applied TX/RX beam IDs, peer/transaction IDs, timestamps and measured quality with units.
- Only a matching valid exchange marks a beam pair usable; energy detection or unrelated/stale ACKs cannot establish reachability.
- Discovery works across the planned orientations/startup cases and can restart after a timeout using the B02 schedule.

**Evidence:** OTA sweep logs, geometry/beam settings, valid/invalid exchange traces and discovery-time results.

### B04 — Integrate fresh neighbor/beam state with routing

**Owner role:** Discovery and directional policy, reviewed by networking. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** B03, N05.

**Scope:** Maintain peer-to-beam/quality/freshness state and notify the route manager when the configured remote LAN becomes reachable or unreachable through `radio0`.

**Acceptance:**

- A validated peer activates the intended remote-prefix route and uses the selected local TX/RX beams; IP routing policy remains separate from beam metadata.
- Stale or failed neighbor state withdraws usable forwarding within the agreed expiry interval without unintended fallback to a default interface; duplicate/stale events cannot reinstall an invalid route. Account for lwIP route-hook `NULL` continuing ordinary lookup rather than explicitly dropping a packet.
- Wireless TX revalidates or discards already queued packets after expiry; queues remain bounded. Quality changes/hysteresis are observable, and recovery restores the route without changing PC addresses or rebooting.

**Evidence:** Neighbor/route event traces, before/after tables, expiry tests and PC traffic captures.

### B05 — Prove blockage, rediscovery and end-to-end recovery

**Owner role:** Discovery and directional policy, verified by integration and tooling. **Milestone:** M4 direction-aware. **Priority:** P1. **Depends on:** B04, S05.

**Scope:** Run controlled end-to-end trials that disturb the usable directional link and demonstrate stale-state expiry, rediscovery and resumed PC traffic.

**Acceptance:**

- Across 20 controlled trials, at least 19 restore PC traffic within the timeout agreed from S01/B02; define the disturbance and the recovery start/end events before testing.
- Logs show the lost/expired neighbor, route withdrawal, new matching exchange, selected beam pair, route restoration and first restored PC payload.
- Record discovery/recovery time, quality, geometry, packet loss and failure reasons; no stale route persists beyond expiry, no remote traffic falls back to an unintended interface, and queued packets/resources remain bounded during loss and recovery.
- The fixed-link M3 configuration remains reproducible and the S05 regression does not introduce an unexplained failure.

**Evidence:** M4 trial table, synchronized event/traffic logs, geometry/beam records and regression report.

## Optional extension tickets

### X01 — Optionally implement an actual L2 Ethernet bridge

**Owner role:** Networking. **Milestone:** M5 stretch. **Priority:** P2. **Depends on:** B05.

**Scope:** If selected after the baseline, extend or replace the raw-IP radio adapter with Ethernet-frame transport and implement actual same-subnet bridging.

**Acceptance:**

- Two same-subnet PCs communicate through the bridge without remote-subnet routes; preserve Ethernet frame semantics and the agreed MTU.
- Verify ARP/broadcast handling, MAC learning/ageing and unknown-unicast behavior with bounded tables/queues and a documented loop-free topology assumption.
- A dedicated L2 test suite passes and the separate routed L3 baseline can still be reproduced.

**Evidence:** Revised architecture/frame contract, MAC/ARP captures, L2 tests and baseline regression results.

### X02 — Add per-LAN DHCP or host provisioning convenience

**Owner role:** Networking, supported by integration and tooling. **Milestone:** M5 stretch. **Priority:** P2. **Depends on:** N05.

**Scope:** Select either per-LAN DHCP support or repeatable host setup tooling to reduce manual address/route configuration for demonstrations.

**Acceptance:**

- Chosen setup method produces the correct non-overlapping LAN addresses, remote connectivity and MTU settings on both PCs without disrupting unrelated interfaces.
- DHCP, if selected, is scoped per routed LAN and tested for renewal/reconnect; provisioning scripts, if selected, can show and undo their changes.
- A fresh-host setup reaches the fixed-link PC-to-PC test using documented steps; static configuration remains a usable fallback.

**Evidence:** Provisioning code/configuration, fresh-host test, lease or route captures and cleanup/fallback instructions.

### X03 — Evaluate adaptive throughput or a FEC upgrade

**Owner role:** Modem, reviewed by link scheduling and beam control. **Milestone:** M5 stretch. **Priority:** P2. **Depends on:** D06.

**Scope:** Choose one measured improvement, such as FEC or a controlled throughput mode, after identifying the baseline limitation. Do not bundle several new modem architectures into one ticket.

**Acceptance:**

- Define the selected change, compatibility/mode agreement, added latency/resources and success metric before implementation.
- Compare baseline and upgraded first-attempt errors, delivered goodput and latency at the same recorded operating points; account for coding/handshake overhead.
- Mismatched mode or a failed upgrade has defined behavior, and the original modem mode still passes its relevant regression tests.

**Evidence:** Design decision, reference/RTL changes, controlled comparison report and compatibility/regression results.
