# Wireless beamforming network

Two FPGA radio nodes connect two companion PCs over a wireless link. Each node combines an embedded processor running lwIP, an FPGA modem, and a directional RF front end. The project first proves ordinary network connectivity and a fixed wireless path, then adds beam discovery and recovery.

This repository currently contains a **proposed implementation plan**, not working FPGA or firmware code. Board models, team assignments, tool versions, and performance targets still need confirmation.

- [Project graph, milestones, modules, and interface contracts](docs/project-plan.md)
- [34 live GitHub issues](https://github.com/le21-j/wireless-beamforming-network/issues)
- [Ticket index with direct issue and dependency links](docs/github-issues.md)
- [Ticket specifications and acceptance criteria](docs/backlog.md)
- [GitHub organization and proposed source tree](docs/github-setup.md)
- [Reusable task issue template](.github/ISSUE_TEMPLATE/task.yml)

The delivery order is **local PC-to-node ping → framed wireless modem → routed PC-to-PC traffic → automatic directional discovery**. Same-subnet Ethernet bridging is a later stretch goal.

The repository is private and owned by [le21-j](https://github.com/le21-j). Work is organized into [six milestones](https://github.com/le21-j/wireless-beamforming-network/milestones), with module, priority and readiness labels on each issue. Stable planning IDs such as N02 are distinct from GitHub issue numbers.

Start with [S01: hardware, scope and demonstration targets](https://github.com/le21-j/wireless-beamforming-network/issues/1), then advance the dependent workstreams. Teammate assignments are still open.
