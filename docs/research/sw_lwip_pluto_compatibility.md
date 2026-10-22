# lwIP on Pluto's Linux USB interface

The production M1 endpoint runs lwIP in a Linux userspace process. Linux supplies the USB Ethernet driver; lwIP owns a separate IPv4 address and handles ARP, ICMP and UDP echo. See the [endpoint README](../../firmware/net/lwip_ethernet/README.md) for build and run instructions, and [SW resources](../bringup/sw_resources.md) for the API references.

## Why use the Linux USB driver

Pluto exposes USB networking through RNDIS. Its standard firmware includes Linux and a Buildroot root filesystem, so the existing management address belongs to Linux. A ping to that address checks Linux reachability, not whether the lwIP endpoint is running. [ADI USB interface](https://wiki.analog.com/university/tools/pluto/users/intro), [ADI firmware](https://github.com/analogdevicesinc/plutosdr-fw).

Linux `AF_PACKET` sockets let a userspace process receive and send link-layer packets. `SOCK_RAW` includes the Ethernet header, and binding the socket selects the interface. Creating the socket requires `CAP_NET_RAW`. This lets the endpoint reuse the Linux USB driver while supplying its own protocol stack. [Linux packet socket contract](https://man7.org/linux/man-pages/man7/packet.7.html).

## How the endpoint uses lwIP

[sw_main.c](../../firmware/net/lwip_ethernet/sw_main.c) binds an `AF_PACKET` socket to the selected Ethernet interface. It filters frames for the endpoint, copies accepted input into lwIP pbufs, and calls `ethernet_input`. Outbound IPv4 traffic passes through `etharp_output`; the link-output callback sends the resulting Ethernet frame through the Linux socket.

The lwIP netif uses the interface MAC and an unused host address in the same /24 as the host. Startup rejects an address already assigned to a Linux interface. The process does not assign its address to Linux or change the management address, interface flags or routes. ARP and echo traffic for the additional address are handled by lwIP.

The [configuration](../../firmware/net/lwip_ethernet/sw_lwipopts.h) selects `NO_SYS=1` and the callback-based raw API. Linux still runs the process; lwIP has no separate TCP/IP thread, socket API or netconn API. One event loop owns the lwIP calls and services `sys_check_timeouts`, including while the link is down. This follows the single-context and timer requirements in the pinned [lwIP options](https://github.com/lwip-tcpip/lwip/blob/STABLE-2_1_3_RELEASE/src/include/lwip/opt.h) and [main-loop documentation](https://github.com/lwip-tcpip/lwip/blob/STABLE-2_1_3_RELEASE/doc/doxygen/main_page.h).

## Build and portability boundaries

The [build script](../../firmware/net/lwip_ethernet/sw_build.sh) compiles unmodified upstream lwIP 2.1.3 with the project's options and platform header. It generates lwIP's required header names beside the output and records source, generated-header and executable hashes. Building for Pluto requires a compatible ARM Linux toolchain and runtime. ADI documents cross-compiling Linux applications and running temporary copies from `/tmp`. [ADI embedded applications guide](https://wiki.analog.com/university/tools/pluto/devs/embedded_code).

A bare-metal or RTOS implementation needs its own startup, network driver and timer integration. RTOS mode also needs lwIP's OS abstraction and correct thread synchronization. AMD's standalone port documents adapters for GEM, AXI Ethernet and Ethernetlite; those adapters do not establish a Pluto USB RNDIS port. A different execution environment therefore requires a separate driver and BSP assessment. [AMD standalone lwIP library](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842366/Standalone%2BLWIP%2Blibrary), [lwIP porting requirements](https://github.com/lwip-tcpip/lwip/blob/STABLE-2_1_3_RELEASE/doc/doxygen/main_page.h).

The current endpoint requires a Linux Ethernet interface with an MTU of at least 1,500 bytes. It enables ARP, IPv4, ICMP and UDP; TCP, IPv6, DHCP and IP fragmentation are disabled, and the frame filter does not accept VLAN-tagged traffic. These are the implementation's present limits. The host tests check the reusable tools. Each new ARM build still needs checks on the target firmware and network interface.
