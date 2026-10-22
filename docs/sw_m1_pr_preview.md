# M1 Progress and General Cleanup of Repo

Adds an lwIP endpoint on each Pluto's USB Ethernet connection. It has its own IPv4 address, resolves addresses with ARP, answers ping and echoes UDP data on port 7.

Linux supplies the USB driver. The application runs lwIP in one event loop, with fixed memory limits, checksum checks and link recovery.

Project files now use team prefixes. The filename check runs on pushes and pull requests. The issue guide lists tasks in project work order.

## Files included

- The production Ethernet application and its build script.
- The reusable network tester, filename checker and their tests.
- Setup instructions, source references and project planning documents.
- Git settings and the filename-check workflow.

One-off lab scripts, the earlier compatibility probe, saved logs and results, build manifests, evidence-folder settings and review-generation files stay local.

## Issue status

The Linux USB checks passed on both Plutos using one PC with two adapters. The issues are listed in work order and remain open because their full requirements are not yet met.

| Issue | Finished work | Still open |
|---|---|---|
| [#3 Reproducible builds](https://github.com/le21-j/wireless-beamforming-network/issues/3) | Pinned M1 lwIP release and compatible-compiler build instructions. | Complete FPGA and board-support tool versions, plus a teammate's build from a clean checkout. |
| [#6 Startup and timers](https://github.com/le21-j/wireless-beamforming-network/issues/6) | Linux boot and build identifiers, plus timer checks. | Board support, a bare-metal runtime or real-time operating system, and interrupt checks. |
| [#8 Host checks and reports](https://github.com/le21-j/wireless-beamforming-network/issues/8) | Traffic generation, payload checks and pass/fail reports. | Firewall records and routes to the remote network, including cleanup. |
| [#11 Ethernet and lwIP](https://github.com/le21-j/wireless-beamforming-network/issues/11) | Linux USB endpoint, fixed addresses, timers, checksums and memory and error counters. | Vendor `eth0` driver and board support, physical-link speed and cable reconnect. |
| [#17 PC-to-Pluto checks](https://github.com/le21-j/wireless-beamforming-network/issues/17) | Ping and unchanged UDP payloads on both Plutos, repeated after reboot and application restart. | Two-PC setup, original board support and serial-log requirements, or agreed replacements. |

## Pluto software

| File | Purpose |
|---|---|
| `firmware/net/lwip_ethernet/sw_main.c` | Receives Ethernet frames, passes them to lwIP and sends replies. Handles link changes and keeps timers running. |
| `firmware/net/lwip_ethernet/sw_lwipopts.h` | Sets the protocols, memory limits, checksums and counters for the Pluto endpoint. |
| `firmware/net/lwip_ethernet/arch/sw_cc.h` | Connects lwIP messages, failed assertions, errno and byte-order functions to Linux. |

## File flows

### `firmware/net/lwip_ethernet/sw_main.c`

```mermaid
flowchart TD
  A["Check interface and IP; open raw socket; start lwIP and UDP port 7"] --> B["Event loop: receive frames, check link and run timers"]
  B --> C{"Valid frame for this endpoint?"}
  C -->|No: count filtered or rejected frame| B
  C -->|Yes| D["Optionally capture received frame; allocate lwIP buffer (pbuf) and copy frame"]
  D --> E["ethernet_input: ARP, IPv4, ICMP and UDP echo"]
  E -->|Responses, if any| F["linkoutput: copy, pad and send frame; optionally capture sent frame"]
  E --> B
  F --> B
  B -->|Link down| G["Clear ARP state; pause packet input; keep timers running until link returns"]
  G --> B
  B -->|Signal, deadline or fatal error| H["Remove endpoint, close resources, print final counters"]
```

### `firmware/net/lwip_ethernet/sw_lwipopts.h`

```mermaid
flowchart LR
  A["sw_lwipopts.h"] --> B["Enable Ethernet, ARP, IPv4, ICMP and UDP"]
  A --> C["Set memory limits, timers, checksums and statistics"]
  B --> D["lwIP compiled for the Pluto endpoint"]
  C --> D
```

### `firmware/net/lwip_ethernet/arch/sw_cc.h`

```mermaid
flowchart LR
  A["arch/sw_cc.h"] --> B["Print messages with printf"]
  A --> C["Failed assertions print a message and abort"]
  A --> D["Use Linux errno and byte-order functions"]
  B --> E["Linux platform definitions compiled into lwIP"]
  C --> E
  D --> E
```

## M1 integration

```mermaid
flowchart LR
  PC["PC"] <-->|USB Ethernet| DRIVER["Pluto Linux USB driver: usb0"]
  subgraph ENDPOINT["On-Pluto lwIP endpoint"]
    RX["sw_main.c: receive, filter and copy frame to an lwIP buffer"] --> STACK["lwIP: Ethernet, ARP, IPv4, ICMP and UDP"]
    STACK -->|UDP payload| ECHO["sw_main.c: UDP port 7 echo callback"]
    ECHO -->|udp_sendto| STACK
    STACK -->|Outgoing frames| TX["sw_main.c: pad and send Ethernet frame"]
  end
  DRIVER -->|Received frames| RX
  TX -->|Response frames| DRIVER
  OPT["sw_lwipopts.h: protocol and memory settings"] -.->|Compile time| STACK
  CC["arch/sw_cc.h: Linux platform definitions"] -.->|Compile time| STACK
```

## Bring-up and sources

- [Project work order](github-issues.md)
- [Build, run and test](../firmware/net/lwip_ethernet/README.md)
- [Team review](bringup/sw_m1_team_review.md)
- [Research](research/sw_lwip_pluto_compatibility.md)
- [SW resources](bringup/sw_resources.md)
