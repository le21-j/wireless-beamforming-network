# GitHub organization

The two nodes share the private repository [le21-j/wireless-beamforming-network](https://github.com/le21-j/wireless-beamforming-network), so frame definitions, FPGA logic, firmware and tests stay versioned together. The implementation plan, 34 issues and six milestones are published. Add source directories when their implementation tickets begin. Teammate accounts/assignments and licensing remain to be chosen; no project board has been created.

## Proposed source tree

```text
capstone/
  README.md
  .github/
    ISSUE_TEMPLATE/task.yml
    pull_request_template.md
  docs/
    reading-guide.md       # Shared foundation, module readings and exercises
    project-plan.md
    backlog.md
    github-issues.md
    github-setup.md
    interfaces/           # Frame, registers, buffers, beam and route contracts
    decisions/            # Board, toolchain, modem and scope choices
    bringup/              # Build, flash, wire and reproduce each milestone
  firmware/
    platform/             # BSP integration, startup, timers
    drivers/              # DMA, control registers, RF configuration
    net/                  # lwIP adapters and route policy
    link/                 # TDD, ACK/retry and packet queues
    discovery/            # HAIL, neighbor state and recovery
  fpga/
    rtl/transport/
    rtl/modem/
    rtl/beam/
    constraints/
    scripts/              # Recreate FPGA projects and build outputs
  hardware/
    block-diagrams/
    rf-bench/
    calibration/
  sim/                    # Floating-point and fixed-point reference models
  tests/                  # Unit, simulation and integration checks
  tools/                  # PC traffic generation, capture and result analysis
```

This tree is a proposal; only the planning documents and GitHub templates currently exist. Do not commit generated Vivado runs, caches, tool installations or large raw sample recordings by default. Keep the small source inputs and scripts required to reproduce a build. Store release binaries and large evidence separately with version/checksum references; establish any Git LFS policy only after agreeing on artifact sizes and hosting limits.

## Milestones and issue fields

The published milestones are M0 Foundations, M1 Local network, M2 Modem bench, M3 Routed wireless, M4 Direction aware, and M5 Optional extensions. [backlog.md](backlog.md) records the ticket specifications, and [github-issues.md](github-issues.md) maps every stable planning ID to its live issue. Published issue bodies link their prerequisites. IDs such as N02 are preserved in titles and are distinct from GitHub issue numbers.

Configured labels:

- Work area: `area:hardware-rf`, `area:fpga-verilog`, `area:embedded-software`, `area:host-software`, `area:integration-testing`. Each issue has at least one, and shared work can have several.
- Module: `module:hardware`, `module:platform`, `module:network`, `module:modem`, `module:link`, `module:discovery`, `module:integration`.
- Readiness: `status:ready` for work whose prerequisites are complete; `status:blocked` for unmet prerequisites. S01 is the initial Ready issue; update these labels as work advances.
- Priority: `priority:P0` for the first three demonstrations and foundations, `priority:P1` for direction-aware integration, `priority:P2` for optional extensions.

These priorities indicate execution order; M4 is still part of the requested direction-aware project. Give every issue one primary owner, a reviewer, a milestone, explicit prerequisite links, and observable acceptance criteria. Assign firmware/RTL boundary tickets such as F02 and F03 one accountable owner and a reviewer from the other side.

If a project board is added, use statuses **Backlog → Ready → In progress → Review → Done**, with **Blocked** for an explicit unmet prerequisite. Put an issue in Ready only when it can be implemented against stable contracts or clearly scoped mocks. Limit each teammate to one main implementation issue at a time; record useful independent work when blocked.

## Work area labels

Area labels identify the technical work involved. Module labels identify the subsystem that owns the ticket. Keep both: a modem task can involve host modeling, FPGA logic or RF measurements even though all three belong to `module:modem`.

| Area label and issue filter | Color | Use for |
|---|---|---|
| [area:hardware-rf](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Ahardware-rf%22) | Orange | Boards, physical RF paths, converters, clocks, antennas, calibration and RF bench work |
| [area:fpga-verilog](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Afpga-verilog%22) | Purple | RTL/Verilog, FPGA interfaces, fixed-point hardware design and FPGA verification |
| [area:embedded-software](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Aembedded-software%22) | Blue | Processor firmware, BSPs, drivers, lwIP, routing and on-device control logic |
| [area:host-software](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Ahost-software%22) | Green | PC tools, simulation/reference models, scripts, automation and host provisioning |
| [area:integration-testing](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Aintegration-testing%22) | Gray | Shared planning/contracts, cross-module bring-up, integration and system validation |

Apply more than one area when the ticket includes meaningful work or validation in each. For example, F02 includes an AXI register block and its processor driver, so it has both FPGA/Verilog and embedded-software labels. D01 builds a PC reference model, so it has host-software. Dependencies alone do not require every upstream area label, and ordinary unit tests do not automatically make a ticket an integration task.

All 34 initial issues are classified. For future issues, apply the matching area labels in GitHub alongside module, priority and readiness. Revisit labels when a ticket is split or its implementation scope changes; F04 and X02 currently span alternatives whose final partition remains a design decision.

## Initial parallel assignments

| Workstream | First decisions or preparation | First implementation sequence |
|---|---|---|
| Team/integration | S01, S02, S03 | S04, then recurring integration evidence |
| Hardware/RF | H01, H03 | H02, later H04/H05 |
| Network/platform | Toolchain, memory and Ethernet choices with S01 | F01, N01, N02 |
| FPGA/transport | Agree registers, DMA and buffer ownership in S03 | F02, F03 |
| Modem | Agree sample rates and framing in S03 | D01, D02, then D03/D04 |

Combine workstreams to match the actual team. Avoid splitting a single DMA or packet format contract between independent owners without a reviewer. If a ticket needs more than roughly three focused working days, split it into child issues with separate testable outputs, keeping its original ID as the parent. D04 receiver synchronization and F03 DMA integration are likely candidates.

## Definition of done

An issue is complete when its acceptance checks pass, evidence is attached, another teammate can reproduce the result, and any changed contract or bring-up procedure is updated. A compiling bitstream alone is not evidence of radio packets; an endpoint ping alone is not evidence of forwarding.

Each pull request should link its issue, describe the concrete behavior, identify relevant tests and their conditions, and state any unverified hardware assumptions. Use the supplied PR template. The test owner records board revisions, build/commit IDs, configuration and measurement units with each result.

## Publication status

The repository contains the reviewed planning documents and issue/PR templates. All 34 tickets are live, with linked prerequisites, acceptance checkboxes, work-area/module/priority/readiness labels and one of the six milestones. Individual assignees and due dates remain unset. No teammate invitations have been sent, and a GitHub project board has not been created. The older direction-finding HTML proposal is retained only in the local workspace and excluded from this repository.
