#ifndef CAPSTONE_LWIPOPTS_H
#define CAPSTONE_LWIPOPTS_H

/* -------------------------------------------------------------------------
 * Single-threaded raw API: the event loop owns all lwIP calls
 * ------------------------------------------------------------------------- */
#define NO_SYS 1
#define SYS_LIGHTWEIGHT_PROT 0
#define LWIP_SOCKET 0
#define LWIP_NETCONN 0
#define LWIP_COMPAT_SOCKETS 0

/* -------------------------------------------------------------------------
 * Enabled protocols and bounded ARP queues
 * ------------------------------------------------------------------------- */
#define LWIP_IPV4 1
#define LWIP_IPV6 0
#define LWIP_ICMP 1
#define LWIP_UDP 1
#define LWIP_UDPLITE 0
#define LWIP_TCP 0
#define LWIP_RAW 0
#define LWIP_DHCP 0
#define LWIP_AUTOIP 0
#define LWIP_DNS 0
#define LWIP_IGMP 0
#define LWIP_ARP 1
#define LWIP_ETHERNET 1
#define ARP_TABLE_SIZE 8
#define ARP_QUEUEING 1
#define ARP_QUEUE_LEN 2
#define MEMP_NUM_ARP_QUEUE 16
#define IP_FORWARD 0
#define IP_FRAG 0
#define IP_REASSEMBLY 0
#define LWIP_NETIF_LOOPBACK 0
#define LWIP_HAVE_LOOPIF 0

/* -------------------------------------------------------------------------
 * Timers and fixed memory budgets
 * ------------------------------------------------------------------------- */
/* NO_SYS timers run from main. PBUF_RAM allocations share the lwIP heap. */
#define LWIP_TIMERS 1
#define LWIP_TIMERS_CUSTOM 0
#define MEMP_NUM_SYS_TIMEOUT 8
#define MEM_ALIGNMENT 8
#define MEM_SIZE (64 * 1024)
#define MEMP_NUM_UDP_PCB 2
#define PBUF_POOL_SIZE 16
#define PBUF_POOL_BUFSIZE 1536

/* -------------------------------------------------------------------------
 * Software checksums and validation counters
 * ------------------------------------------------------------------------- */
#define CHECKSUM_CHECK_IP 1
#define CHECKSUM_CHECK_ICMP 1
#define CHECKSUM_CHECK_UDP 1
#define CHECKSUM_GEN_IP 1
#define CHECKSUM_GEN_ICMP 1
#define CHECKSUM_GEN_UDP 1
#define LWIP_STATS 1
#define LWIP_STATS_LARGE 1
#define IP_STATS 1
#define ICMP_STATS 1
#define UDP_STATS 1
#define ETHARP_STATS 1
#define MEM_STATS 1
#define MEMP_STATS 1

#endif
