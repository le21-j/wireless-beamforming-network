# M1 team review

M1 lets a PC talk to each Pluto through its USB network connection. The application runs lwIP at a separate IPv4 address, answers ping and echoes UDP data on port 7. Linux supplies the USB Ethernet driver.

Start with the [application README](../../firmware/net/lwip_ethernet/README.md) for the pinned source download, cross-compilation, manual copy and run steps, and host checks. The host UDP tool uses Python 3.10 or newer with no additional packages.

The [M1 overview](../sw_m1_pr_preview.md) describes the three Pluto source files and their flow diagrams. The [compatibility research](../research/sw_lwip_pluto_compatibility.md) explains the Linux USB approach, and [SW resources](sw_resources.md) links the relevant upstream documentation.

This code covers the Linux USB endpoint. A bare-metal or RTOS BSP, a test with two PCs and the RF link remain separate work.
