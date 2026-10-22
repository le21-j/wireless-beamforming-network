# Wireless beamforming network

Two FPGA radio nodes connect two companion PCs over a wireless link. Each node combines an embedded processor running lwIP, an FPGA modem, and a directional RF front end. The project first proves ordinary network connectivity and a fixed wireless path, then adds beam discovery and recovery.

The M1 Linux/USB networking test passed on both PlutoSDRs. Each board runs a temporary lwIP application with its own IPv4 address. Windows reached it through ordinary ARP, ping and UDP, including recovery after an interface outage and a board reboot. The original bare-metal or RTOS BSP work remains open.

Start with the [M1 team guide](docs/bringup/sw_m1_team_review.md) and the [endpoint setup instructions](firmware/net/lwip_ethernet/README.md). This change includes the production Ethernet application, reusable test tools and setup documents. Local lab scripts, intermediate probes, saved results and generated build records stay outside the published source.

Project files use team prefixes: `sw_` for software, `hw_` for Verilog and SystemVerilog, and `rf_` for RF work. See the [naming rules](docs/sw_file_naming.md) and [M1 changes](docs/sw_m1_pr_preview.md).

The [SW resources](docs/bringup/sw_resources.md) page lists the sources used for the software, grouped by topic.

- [Useful links to get started](docs/reading-guide.md)
- [Our project plan](docs/project-plan.md)
- [34 live GitHub issues](https://github.com/le21-j/wireless-beamforming-network/issues)
- [Project work order, issues and prerequisites](docs/github-issues.md)
- [Ticket specifications and acceptance criteria](docs/backlog.md)
- [GitHub organization and proposed source tree](docs/github-setup.md)
- [Reusable task issue template](.github/ISSUE_TEMPLATE/task.yml)

The delivery order is **local PC-to-node ping → framed wireless modem → routed PC-to-PC traffic → automatic directional discovery**. Same-subnet Ethernet bridging is a later stretch goal.

The repository is public and owned by [le21-j](https://github.com/le21-j). Work is organized into [six milestones](https://github.com/le21-j/wireless-beamforming-network/milestones), with work-area, module, priority and readiness labels on each issue. Refer to tasks by their GitHub issue number and title, such as #17, Prove local PC ICMP and UDP on both boards.

Find issues by work area: [Hardware/RF](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Ahardware-rf%22), [FPGA/Verilog](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Afpga-verilog%22), [Embedded software](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Aembedded-software%22), [Host software](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Ahost-software%22), or [Integration/testing](https://github.com/le21-j/wireless-beamforming-network/issues?q=is%3Aissue%20label%3A%22area%3Aintegration-testing%22). Shared tasks carry multiple area labels; see the [label guide](docs/github-setup.md#work-area-labels) for their meaning.

Start with [#1: hardware, scope and demonstration targets](https://github.com/le21-j/wireless-beamforming-network/issues/1), then advance the dependent workstreams. Teammate assignments are still open.
