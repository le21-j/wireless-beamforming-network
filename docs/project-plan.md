# Our project plan

We're building a wireless link that lets two PCs talk through two FPGA radio nodes. Here's how we're breaking up the work and what we're trying to get working first. The full task map and engineering notes are at the bottom whenever we need more detail.

## The big picture

```mermaid
flowchart LR
  PCA["PC A"] <-->|Ethernet| RA["FPGA radio A"]
  RA <-->|Wireless| RB["FPGA radio B"]
  RB <-->|Ethernet| PCB["PC B"]
```

Each radio has three main pieces: **lwIP on the embedded processor** handles network packets, **FPGA logic written in Verilog** handles modem processing and beam control, and **the RF hardware and phased array** transmit and receive the signal.

We'll first get this working with a fixed wireless connection. Then we'll add the ability to find a beam direction automatically and reconnect when the link is interrupted.

## How we'll build it

We'll start by agreeing on the hardware, tools and basic interfaces between our parts of the project (M0). From there, these are the four main demonstrations:

| Stage | What we're working toward |
|---|---|
| **M1 · Local connection** | Each PC can ping its own radio node over Ethernet using lwIP. |
| **M2 · Working modem** | The two radios can send and receive valid packets on the bench. We'll build up through simulations, FPGA loopback and controlled RF tests. |
| **M3 · PC-to-PC communication** | With a fixed wireless link working, both nodes forward IP packets so the PCs can ping each other and transfer data. |
| **M4 · Automatic beam discovery** | The nodes try beam settings, exchange HAIL/ACK probes, choose a usable connection and recover after an interruption. |

This is the order we'll demonstrate things, while software, FPGA and hardware work can happen alongside each other. Local ping gives us a starting point; M3 is where we prove forwarding between the PCs.

If we have time, M5 covers transparent Ethernet bridging, easier PC setup and modem improvements. Our starting design uses IP routing with configured addresses and routes.

## How we can split the work

These areas overlap, so we can share them based on what everyone wants to work on.

| Area | What's involved |
|---|---|
| **Hardware and RF** | Board connections, converters, clocks, antennas, radio testing and array calibration. |
| **Embedded software** | Booting the processor, drivers, control registers and moving packets between the processor and FPGA. |
| **Networking** | Ethernet, lwIP, the radio interface and forwarding packets between the two PCs. |
| **Modem / FPGA and Verilog** | Simulating the modem, building the transmit and receive logic, and checking it with testbenches. |
| **Link and beam control** | Taking turns transmitting, handling retries, and applying beam weights in the FPGA. |
| **Discovery** | Trying beam directions, tracking which connection works and reconnecting when it drops. |
| **Integration and tools** | Build scripts, PC test programs, packet captures and recording our results. |

## Where we can start

Our first shared task is [#1: hardware, scope and demo targets](https://github.com/le21-j/wireless-beamforming-network/issues/1). Once we've settled those basics, we can work on Ethernet/lwIP bring-up, the modem model and the hardware setup in parallel.

Follow the [project work order](github-issues.md) from M0 to M5. It lists each issue after its prerequisites. Tasks can run in parallel once their prerequisites are complete. The area labels help us find hardware, embedded software, FPGA/Verilog and host software work. The [reading guide](reading-guide.md) has a few starting links for each area.

As we test, we'll track packet delivery, useful throughput, beam settings, discovery time and recovery time. The proposed test targets are in the notes below; we'll refine them around the hardware we choose.

## More detail when we need it

<details>
<summary>Full task map and dependencies</summary>

## Dependency graph

The arrows show which tasks build on earlier work. Separate branches can move in parallel, and the diamonds mark demonstrations. Each task uses its GitHub issue number, matching the [backlog](backlog.md) and [issue index](github-issues.md). The backlog has the full prerequisite list.

```mermaid
flowchart TB
  subgraph foundation["M0 — Scope and shared foundations"]
    issue1["#1 · Board, scope and demo targets"]
    issue3["#3 · Reproducible tools and repository"]
    issue4["#4 · Packet, register and buffer contracts"]
    issue2["#2 · Processor, Ethernet and RF feasibility"]
    issue1 --> issue3
    issue1 --> issue4
    issue1 --> issue2
  end

  subgraph net["Software and network firmware"]
    issue6["#6 · Boot, BSP, UART and timers"]
    issue11["#11 · Ethernet MAC, PHY and lwIP"]
    issue17["#17 · Local ICMP and UDP on both nodes"]
    issue20["#20 · Mock radio0 IP interface"]
    issue22["#22 · Routes and two-interface forwarding"]
    issue27["#27 · Connect routing to wireless transport"]
    issue6 --> issue11 --> issue17 --> issue20 --> issue22 --> issue27
  end

  subgraph transport["Firmware and FPGA packet transport"]
    issue10["#10 · AXI control registers and driver"]
    issue14["#14 · DMA, buffers and packet loopback"]
    issue15["#15 · TDD, ACKs, retry and bounded queues"]
    issue10 --> issue14
    issue10 --> issue15
  end

  subgraph modem["Modem software model and FPGA logic"]
    issue5["#5 · Reference modem and frame format"]
    issue9["#9 · Fixed-point golden vectors"]
    issue12["#12 · TX framing, mapping and filtering"]
    issue13["#13 · RX detection, timing, carrier and CRC"]
    issue19["#19 · Digital modem loopback"]
    issue21["#21 · Two-node conducted RF packets"]
    issue23["#23 · Bidirectional fixed-link OTA packets"]
    issue5 --> issue9
    issue9 --> issue12 --> issue19
    issue9 --> issue13 --> issue19
    issue19 --> issue21 --> issue23
  end

  subgraph hardware["Hardware and RF"]
    issue16["#16 · Converter and single RF path bring-up"]
    issue7["#7 · Link budget and attenuated RF bench"]
    issue24["#24 · Coherent channels and calibration"]
    issue28["#28 · Beam codebook and measured patterns"]
    issue16 --> issue24
    issue7 --> issue24
    issue24 --> issue28
  end

  subgraph direction["Direction-aware firmware and FPGA control"]
    issue26["#26 · FPGA beamformer and atomic control"]
    issue18["#18 · Discovery rendezvous state machine"]
    issue31["#31 · Directional HAIL and matching ACK"]
    issue32["#32 · Fresh neighbor state and route binding"]
    issue33["#33 · Blockage, rediscovery and traffic recovery"]
    issue26 --> issue31
    issue18 --> issue31 --> issue32 --> issue33
  end

  subgraph evidence["Integration and measured demonstrations"]
    issue8["#8 · Host tests, captures and reports"]
    M1{"M1 · Each PC pings its local FPGA"}
    M2{"M2 · Valid modem packets in both directions"}
    issue29["#29 · PC-to-PC regression and performance"]
    M3{"M3 · PC-to-PC ping, UDP and TCP over RF"}
    M4{"M4 · Automatic beam discovery and recovery"}
  end

  subgraph stretch["M5 — Optional extensions"]
    issue34["#34 · Transparent Ethernet L2 bridge"]
    issue30["#30 · DHCP or host provisioning"]
    issue25["#25 · FEC or higher throughput"]
  end

  issue2 --> issue6
  issue3 --> issue6
  issue4 --> issue10
  issue6 --> issue10
  issue4 --> issue5
  issue4 --> issue20
  issue4 --> issue8
  issue8 --> issue17
  issue17 --> M1
  issue2 --> issue16
  issue10 --> issue16
  issue2 --> issue7
  issue14 --> issue19
  issue16 --> issue21
  issue7 --> issue21
  issue21 --> M2
  issue5 --> issue15
  issue15 --> issue23
  issue14 --> issue27
  issue15 --> issue27
  issue23 --> issue27
  issue27 --> issue29
  issue8 --> issue29
  issue29 --> M3
  issue21 --> issue24
  issue24 --> issue26
  issue26 --> issue28
  issue28 --> issue31
  issue10 --> issue26
  issue4 --> issue18
  issue15 --> issue18
  issue23 --> issue31
  issue27 --> issue32
  issue29 --> issue33
  issue33 --> M4
  issue33 --> issue34
  issue27 --> issue30
  issue21 --> issue25
```

</details>

<details>
<summary>Engineering notes: networking, interfaces, hardware and test targets</summary>

These are the details we'll come back to as we build each part. The milestone measurements below are proposed starting targets.

## Architecture to build first

Use routed IPv4 with static addresses and routes for the first PC-to-PC demonstration. A node has an Ethernet interface for its companion PC and one point-to-point radio IP interface for its peer. Application endpoints remain on the PCs.

```mermaid
flowchart LR
  A["PC A"] <-->|Ethernet| AE["Node A · eth0"]
  AE <--> AL["lwIP forwarding"]
  AL <--> AR["radio0 + link driver"]
  AR <--> AM["FPGA modem + RF"]
  AM <-->|Wireless| BM["RF + FPGA modem"]
  BM <--> BR["radio0 + link driver"]
  BR <--> BL["lwIP forwarding"]
  BL <--> BE["Node B · eth0"]
  BE <-->|Ethernet| B["PC B"]
```

| Segment | Node or PC | Proposed address |
|---|---|---|
| LAN A | PC A | `192.168.10.2/24` |
| LAN A | Node A Ethernet | `192.168.10.1/24` |
| Radio transit | Node A radio | `10.255.0.1/30` |
| Radio transit | Node B radio | `10.255.0.2/30` |
| LAN B | Node B Ethernet | `192.168.20.1/24` |
| LAN B | PC B | `192.168.20.2/24` |

PC A routes `192.168.20.0/24` through `192.168.10.1`; PC B routes `192.168.10.0/24` through `192.168.20.1`. Each node routes the remote LAN through its radio peer. Use specific remote-LAN routes so the experiment need not change the PCs' ordinary Internet default routes. Check that these example ranges do not overlap other active host networks. NAT is unnecessary for this topology.

A local ping only proves Ethernet, addressing, ARP and ICMP. The forwarding milestone must send packets addressed to the remote PC through two interfaces, preserving the PC source and destination addresses and performing normal IP TTL handling. A program that receives a TCP stream and creates a new connection is an application relay; it does not satisfy this routing demonstration.

lwIP supplies IPv4 forwarding and routing hooks; pin and inspect the actual AMD BSP version before using them. `IP_FORWARD` must be enabled for forwarding. A route hook selects an interface, while the project owns the desired route policy and metadata. [lwIP configuration](https://www.nongnu.org/lwip/2_1_x/opt_8h.html), [lwIP hooks](https://www.nongnu.org/lwip/2_1_x/group__lwip__opts__hooks.html).

For the proposed design, keep one `radio0` netif and store beam choices in a separate neighbor/link table. A beam change selects a new physical path for the same peer; it need not create a new IP interface or subnet. Model the lookup as:

`destination prefix → radio0 + peer ID → current local TX/RX beam selections → modem`

The direction-aware research contribution remains measurable: discovery determines whether a peer is reachable, which beam pair serves it, its link quality, and when the usable route must be withdrawn or restored. With only two nodes, the experiment demonstrates directional link selection and route availability, not multi-hop path selection.

HAIL and ACK are link-control frames that work before an IP route exists. A matching bidirectional exchange updates the neighbor table; the route manager then activates the remote-LAN route using a configured peer-to-prefix mapping. Energy detection alone does not validate a neighbor. Record separate local TX and RX beam IDs and remote selections where exchanged; local angle conventions are not automatically identical at the two nodes.

Route expiry must prevent unintended forwarding. Returning `NULL` from the lwIP route hook resumes ordinary route lookup rather than explicitly dropping the packet. Ensure a withdrawn remote-LAN route cannot fall back to an inappropriate default interface, and revalidate or discard queued radio packets when their neighbor expires. #32/#33 must demonstrate this behavior. [lwIP hook return behavior](https://www.nongnu.org/lwip/2_1_x/group__lwip__opts__hooks.html).

## Modules and ownership boundaries

We can split these areas across the team, with a primary owner and someone to review each part. When a change affects two modules, the people working on both can check it together.

| Module | Work and suggested location | Inputs and deliverable | Issues |
|---|---|---|---|
| Hardware and RF | `hardware/`: board map, Ethernet PHY connections, converters/transceivers, clocks/LO, antennas, RF fixtures, calibration measurements | Selected hardware → known sample path and measured calibrated beams | #2, #16, #7, #24, #28 |
| Embedded platform and transport | `firmware/platform/`, `firmware/drivers/`, `fpga/rtl/transport/`: boot, timers, AXI registers, DMA, interrupts, caches, buffer ownership | CPU packets and control → reliable FPGA transfers with bounded queues | #6, #10, #14 |
| Networking | `firmware/net/`: Ethernet adapter, `radio0`, lwIP settings, route policy, IP packet forwarding | Valid IP packets and link state → local ICMP plus PC-to-PC connectivity | #11, #17, #20, #22, #27 |
| Modem | `sim/`, `fpga/rtl/modem/`: reference models, framing, fixed point, modulation, filtering, burst acquisition, timing/carrier recovery, CRC | Link frames ↔ baseband samples | #5, #9, #12, #13, #19, #21, #23 |
| Link scheduling and beam control | `firmware/link/`, `fpga/rtl/beam/`: TDD ownership, ACK/retry, TX weighting, RX combining, atomic coefficient application | Frames, samples, beam requests and RF timing → scheduled transmissions, steered samples and confirmed beam state | #15, #26 |
| Discovery and directional policy | `firmware/discovery/`: rendezvous, HAIL validation, neighbor lifecycle, quality, freshness, hysteresis | Validated link events → usable peer and beam selection, expiry and recovery | #18, #31, #32, #33 |
| Integration and tooling | `tools/`, `tests/`, `docs/`: contracts, repeatable builds, host traffic tools, evidence, regression and demonstrations | All module outputs → reproducible milestone evidence | #1, #3, #4, #8, #29 |

The hardware owner owns channel calibration in #24 and the measured codebook in #28. The beam-control owner implements or integrates the sample-weighting/combining datapath and coefficient application in #26. The discovery owner chooses among validated beam entries. The network owner turns usable-neighbor state into forwarding policy. This separates tasks that otherwise tend to be assigned ambiguously as "beamforming."

#26 first validates known weights against #24 calibration: TX distributes and weights samples across antenna paths; RX aligns, weights and combines samples before modem decoding. #28 then measures the resulting patterns and validates the steering codebook. If the chosen front end performs part of this in hardware, document that boundary and test the integrated behavior. #21 can test each direction in separate manually controlled runs before #15 supplies automated half-duplex scheduling.

## Milestone exit criteria

The M1 source uses lwIP over Linux USB Ethernet. The original bare-metal or RTOS board support, physical cable reconnection and second companion PC still need validation. See the [M1 team guide](bringup/sw_m1_team_review.md) for the source and setup steps. Saved bench results stay local.

| Milestone | Required demonstration | Proposed evidence and initial gate |
|---|---|---|
| M0 Foundations | Hardware feasibility, scope and shared interfaces are written down | Exact parts, RF channel map, tool versions, link/frame and CPU/FPGA contracts; owners agree on achievable operating envelope |
| M1 Local network | Each PC can ping its own node over Ethernet | After ARP warm-up, 1,000 ICMP replies out of 1,000 on each local connection; UDP payload preserved; save capture, UART log and build ID |
| M2 Modem bench | Independent nodes exchange CRC-valid payloads over conducted RF | Ideal digital cases match reference; corrupt frames rejected; 10,000 frames per direction with packet error rate at most 1% at a recorded operating point; report unique payload delivery separately from retries |
| M3 Routed wireless | PC A and PC B communicate through both FPGA nodes over a fixed wireless path | At least 99% of 1,000 pings each direction; 10-minute sequenced UDP run at a stated rate below measured capacity with at most 1% loss; 10 MB TCP file with matching SHA-256; route/TTL and link interruption evidence |
| M4 Direction aware | Nodes discover a beam pair, install usable forwarding state, and recover after disturbance | 20 controlled discovery/recovery trials; at least 19 restore traffic within a timeout chosen from the scan schedule in #1/#18; record angle, quality, discovery time, route expiry and recovery time |
| M5 Optional | L2 bridge, easier host setup or modem performance extension | Separate acceptance test for each approved extension; completion is not needed to claim M1–M4 |

For every RF result, record carrier frequency, modulation, symbol/sample rates, packet lengths, gains, attenuation or distance/orientation, oscillator arrangement and build IDs. Report both pre-retry packet errors and application delivery so retries do not hide modem problems. Throughput, range, bandwidth and recovery-time commitments remain unset until #1 establishes feasible targets.

## Shared contracts to freeze early

| Boundary | Required agreement before independent implementation |
|---|---|
| lwIP ↔ radio adapter | Raw IPv4 packets for v1; MTU; scatter/gather or copy rules; RX callback context; TX ownership until completion; link-down behavior; bounded queue depth; checksum responsibility |
| CPU ↔ FPGA | Register addresses and version; reset sequence; endianness; packet length and boundaries; AXI stream `TLAST`/`TKEEP` where used; DMA buffer alignment and memory visibility; interrupts, completion and error reporting |
| Link ↔ modem | Versioned preamble/header/payload/CRC; DATA, HAIL and ACK types; source/destination node IDs; sequence and transaction identity; maximum payload; invalid-length rejection; PHY acquisition and airtime assumptions |
| Beam controller ↔ RF/FPGA | Channel order; coefficient representation; calibration plus steering composition; TX/RX bank selection; angle convention; switch latency; apply only at allowed packet boundaries; applied-beam acknowledgement |
| Discovery ↔ routing | Peer ID; selected local TX and RX beams; quality and its units; last validated time; expiry; neighbor state; route activation/withdrawal event; fixed remote-prefix mapping for the two-node baseline |
| Modules ↔ test harness | Build ID; monotonic timestamps; frame TX/RX/CRC counters; drops and reasons; DMA failures; queue occupancy; heap/pbuf statistics; active beam; neighbor state and route changes |

Proposed buffer strategy: start with bounded copies between lwIP and dedicated DMA buffers. Make ownership explicit before optimizing for zero-copy. RF will often drain more slowly than Ethernet arrives; queue-full and link-down paths must fail predictably instead of allocating indefinitely.

For a raw-IP radio interface, do not forward local Ethernet headers or require Ethernet ARP on that radio path. Recompute or validate the appropriate IP/transport checksums in software unless the actual radio datapath provides equivalent offload. At #4 choose an explicit MTU policy: either constrain every test endpoint to an agreed supported IP MTU, or implement and test the needed fragmentation/reassembly and DF/ICMP behavior. Do not silently truncate a 1,500-byte IP packet to fit a smaller radio payload.

Use one supported lwIP execution model. In bare-metal mainloop mode, service input and timers from the intended context; DMA interrupts should hand off work rather than calling arbitrary lwIP paths. An RTOS design must respect its lwIP core-thread rules. [lwIP mainloop guidance](https://www.nongnu.org/lwip/2_1_x/group__lwip__nosys.html).

## Hardware and modem decisions that can block progress

1. **Prove the number of RF antenna paths.** Four real DAC or ADC channels can correspond to two complex I/Q paths, depending on the architecture. Confirm the actual converter/transceiver topology, Ethernet MAC/PHY availability, clocking, processor memory and required IP licenses before designing around four elements.
2. **Separate local coherence from over-the-air synchronization.** Channels inside one array need deterministic alignment and measured TX/RX phase/amplitude correction. Independent radio nodes still need carrier and timing recovery. A shared bench reference may help debugging, but the final two-node test must meet the intended independent-clock requirement. [ADI synchronization and calibration guide](https://wiki.analog.com/resources/eval/user-guides/quadmxfe/multichipsynchronization).
3. **Begin with a modest single-carrier burst modem.** BPSK or QPSK is a proposed starting choice, subject to the model and hardware rate budget. The receiver needs burst detection, matched filtering, timing/carrier recovery, phase-ambiguity handling, framing and CRC. A working continuous-stream example is not proof that short hails acquire reliably. [Hardware-oriented QPSK example and receiver limitations](https://www.mathworks.com/help/wireless-hdl/ug/qpsk-transmitter-receiver.html).
4. **Budget RF levels before a conducted test.** Record measured transmitter output, path/attenuator loss and receiver limits for the selected equipment. Validate one path before combining all array channels. Confirm mixers/LOs, filters, amplifiers and transmit/receive isolation where the chosen front end requires them.
5. **Design a rendezvous protocol.** Two nodes independently sweeping narrow beams can repeatedly miss each other. Choose deterministic initiator/responder roles, a receive scan policy, bounded dwell/guard timing, and a beam/slot for the ACK return path. Test different startup phases and reacquisition after lost timing.
6. **Retain a fixed-link fallback.** Manual beam selection and known modem settings should still run the M3 demonstration while discovery is developed. Calibration and discovery can be simulated or measured in parallel without blocking the first router.

## First work to start

After #1, #3, #4 and #2 can move in parallel. Once we've agreed on the interfaces, networking/platform work follows #6→#11→#17, modem work starts with #5→#9, hardware work starts with #7 and preparation for #16, and test tooling starts with #8. #10/#14 and the radio mock #20 let us try the interfaces while the modem RTL is still being developed.

We'll aim for demonstrations in the order M1→M2→M3→M4 while development overlaps. A weekly check of how our pieces work together should help us catch interface problems early.

## Stretch scope and technical references

A same-subnet transparent Ethernet bridge changes the radio payload to Ethernet frames and introduces MAC learning and broadcast handling. It is distinct from the routed IPv4 baseline. lwIP has a bridge interface, but it requires Ethernet-style ports; the proposed raw-IP radio adapter would need extension or replacement for that goal. [lwIP bridge interface](https://www.nongnu.org/lwip/2_1_x/group__bridgeif.html).

Automatic host configuration is another separate extension. DHCP can be provided per routed LAN; broadcasts do not automatically cross the L3 radio link. Full duplex, OFDM, adaptive modulation, multi-hop mesh routing and custom replacement boards are not required for the initial plan.

AMD's lwIP echo-server example can seed Ethernet bring-up after checking board/BSP compatibility. Its port-7 application echo behavior alone is not a forwarding test. [AMD example](https://github.com/Xilinx/embeddedsw/blob/master/lib/sw_apps/lwip_echo_server/src/README.txt).

AXI DMA implementation details must follow the selected IP configuration, including frame boundaries and completion lengths. [AMD AXI DMA scatter/gather documentation](https://docs.amd.com/r/en-US/pg021_axi_dma/Scatter/Gather-Mode). Recheck all APIs against the selected, pinned toolchain; these links are design references rather than a claim that a particular version is already installed.

</details>
