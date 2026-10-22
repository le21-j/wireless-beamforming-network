# SW resources

## lwIP endpoint and settings

### [lwIP 2.1.3 source](https://github.com/lwip-tcpip/lwip/tree/STABLE-2_1_3_RELEASE)

The pinned network stack compiled into the Pluto application. Provides ARP, IPv4, ICMP, UDP, buffers and timers used by `sw_main.c`.

### [lwIP NO_SYS main loop](https://www.nongnu.org/lwip/2_1_x/group__lwip__nosys.html)

Describes the single event loop and regular timer calls used in `sw_main.c`.

### [lwIP network-interface API](https://www.nongnu.org/lwip/2_1_x/group__netif.html)

Describes the input, output and link-state callbacks that connect `sw_main.c` to lwIP.

### [lwIP configuration options](https://www.nongnu.org/lwip/2_1_x/opt_8h.html)

Reference for the protocol, memory, checksum and statistics settings in `sw_lwipopts.h`.

### [lwIP packet buffers](https://www.nongnu.org/lwip/2_1_x/group__pbuf.html)

Explains the buffer allocation, copying and release used by packet input and UDP replies in `sw_main.c`.

### [lwIP platform definitions](https://github.com/lwip-tcpip/lwip/blob/STABLE-2_1_3_RELEASE/src/include/lwip/arch.h)

Explains the platform macros supplied by `arch/sw_cc.h`, including diagnostics and failed assertions.

## Linux Ethernet in sw_main.c

### [Linux packet sockets](https://man7.org/linux/man-pages/man7/packet.7.html)

Describes the `AF_PACKET` socket used to receive and send Ethernet frames through `usb0`.

### [Linux network-device interface](https://man7.org/linux/man-pages/man7/netdevice.7.html)

Explains the interface index, MAC, MTU and link flags read during startup and link monitoring.

### [Linux clocks](https://man7.org/linux/man-pages/man3/clock_gettime.3.html)

Explains the monotonic clock used for timers and application lifetime, and the realtime clock used for packet timestamps.

### [PCAP file format](https://www.tcpdump.org/manpages/pcap-savefile.5.html)

Explains the file and packet headers written by the optional capture code in `sw_main.c`.

## Pluto setup and application builds

### [ADI Pluto introduction](https://wiki.analog.com/university/tools/pluto/users/intro)

Describes the USB network connection used between the PC and Pluto.

### [ADI embedded applications guide](https://wiki.analog.com/university/tools/pluto/devs/embedded_code)

Describes compiling Linux applications for Pluto and copying temporary executables to `/tmp` to run them.

### [ADI Pluto firmware](https://github.com/analogdevicesinc/plutosdr-fw)

Documents the Linux and Buildroot firmware that supplies USB networking beneath the lwIP application.

## BSP research

### [AMD standalone lwIP library](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842366/Standalone%2BLWIP%2Blibrary)

Used to compare the vendor Ethernet and BSP adapters with the Linux USB approach recorded in the research file.

### [AMD echo-server example](https://github.com/Xilinx/embeddedsw/blob/master/lib/sw_apps/lwip_echo_server/src/main.c)

Provides the vendor event-loop example discussed in the research file, including regular network-input and timer service.
