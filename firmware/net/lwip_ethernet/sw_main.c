/* A real lwIP Ethernet endpoint using Linux only as the USB Ethernet driver. */
#define _DEFAULT_SOURCE 1
#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <inttypes.h>
#include <linux/if_packet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

#include "lwip/etharp.h"
#include "lwip/init.h"
#include "lwip/ip.h"
#include "lwip/memp.h"
#include "lwip/netif.h"
#include "lwip/pbuf.h"
#include "lwip/stats.h"
#include "lwip/timeouts.h"
#include "lwip/udp.h"
#include "netif/ethernet.h"

#ifndef CAPSTONE_BUILD_TAG
#define CAPSTONE_BUILD_TAG "unrecorded"
#endif

/* -------------------------------------------------------------------------
 * Endpoint state and process lifetime
 * ------------------------------------------------------------------------- */
enum { ENDPOINT_MTU = 1500, FRAME_MAX = ENDPOINT_MTU + ETH_HLEN };

/* main owns this state until callbacks are removed. Only the event loop uses
 * the socket, capture stream and counters; the signal handler sets stopped. */
struct endpoint {
    int fd;
    int ifindex;
    char interface[IFNAMSIZ];
    unsigned char mac[ETH_ALEN];
    struct in_addr address;
    FILE *capture;
    uint64_t received, outgoing_ignored, filtered, rejected, rx_frames;
    uint64_t rx_arp, rx_ipv4, tx_frames, tx_arp, tx_ipv4, tx_errors;
    uint64_t allocation_errors, udp_echoes, udp_errors, input_errors;
    uint64_t capture_frames, capture_errors, timer_calls, link_changes;
    uint64_t link_poll_errors, network_down_events, max_service_gap_us;
};

static volatile sig_atomic_t stopped;

static void stop_endpoint(int signal_number)
{
    (void)signal_number;
    stopped = 1;
}

/* -------------------------------------------------------------------------
 * Clock and wire-format helpers
 * ------------------------------------------------------------------------- */
static uint64_t monotonic_us(void)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
        perror("clock_gettime");
        exit(EXIT_FAILURE);
    }
    return (uint64_t)now.tv_sec * 1000000 + (uint64_t)now.tv_nsec / 1000;
}

u32_t sys_now(void)
{
    return (u32_t)(monotonic_us() / 1000);
}

static unsigned read_be16(const unsigned char *bytes)
{
    return ((unsigned)bytes[0] << 8) | bytes[1];
}

static void write_le32(unsigned char *bytes, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i) bytes[i] = (unsigned char)(value >> (8 * i));
}

/* -------------------------------------------------------------------------
 * Optional packet capture
 * ------------------------------------------------------------------------- */
/* Exclusive creation preserves existing evidence. Once fdopen succeeds, main
 * owns the stream and closes it on normal exit or any later setup failure. */
static int open_capture(struct endpoint *endpoint, const char *path)
{
    static const unsigned char header[24] = {
        0xd4, 0xc3, 0xb2, 0xa1, 2, 0, 4, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0xff, 0xff, 0, 0, 1, 0, 0, 0
    };
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0) return -1;
    endpoint->capture = fdopen(fd, "wb");
    if (endpoint->capture == NULL) {
        close(fd);
        return -1;
    }
    if (fwrite(header, sizeof(header), 1, endpoint->capture) != 1) return -1;
    return 0;
}

static void capture_frame(struct endpoint *endpoint, const void *frame, size_t size)
{
    if (endpoint->capture == NULL || endpoint->capture_errors) return;
    struct timespec now;
    unsigned char header[16];
    if (clock_gettime(CLOCK_REALTIME, &now) != 0) {
        endpoint->capture_errors++;
        stopped = 1;
        return;
    }
    write_le32(header, (uint32_t)now.tv_sec);
    write_le32(header + 4, (uint32_t)(now.tv_nsec / 1000));
    write_le32(header + 8, (uint32_t)size);
    write_le32(header + 12, (uint32_t)size);
    if (fwrite(header, sizeof(header), 1, endpoint->capture) != 1 ||
        fwrite(frame, size, 1, endpoint->capture) != 1) {
        endpoint->capture_errors++;
        stopped = 1;
        return;
    }
    endpoint->capture_frames++;
}

/* -------------------------------------------------------------------------
 * Linux interface state and lwIP link recovery
 * ------------------------------------------------------------------------- */
static int interface_request(struct endpoint *endpoint, unsigned long operation,
                             struct ifreq *request)
{
    memset(request, 0, sizeof(*request));
    memcpy(request->ifr_name, endpoint->interface, strlen(endpoint->interface) + 1);
    return ioctl(endpoint->fd, operation, request);
}

static void update_link(struct endpoint *endpoint, struct netif *netif, int up)
{
    if (up == !!netif_is_link_up(netif)) return;
    if (up) {
        netif_set_link_up(netif);
    } else {
        netif_set_link_down(netif);
        /* Release queued packets and cached peers before the link recovers. */
        etharp_cleanup_netif(netif);
    }
    endpoint->link_changes++;
    printf("LINK up=%d monotonic_ms=%" PRIu64 "\n", up, monotonic_us() / 1000);
}

static void poll_link(struct endpoint *endpoint, struct netif *netif)
{
    struct ifreq request;
    int up = 0;
    if (interface_request(endpoint, SIOCGIFFLAGS, &request) != 0) {
        endpoint->link_poll_errors++;
    } else {
        up = (request.ifr_flags & IFF_UP) && (request.ifr_flags & IFF_RUNNING);
        char path[80];
        snprintf(path, sizeof(path), "/sys/class/net/%s/carrier", endpoint->interface);
        int carrier_fd = open(path, O_RDONLY);
        if (carrier_fd >= 0) {
            char carrier = '0';
            ssize_t size = read(carrier_fd, &carrier, 1);
            close(carrier_fd);
            up = up && size == 1 && carrier == '1';
        } else if (errno != ENOENT) {
            up = 0;
            endpoint->link_poll_errors++;
        }
    }
    update_link(endpoint, netif, up);
}

/* -------------------------------------------------------------------------
 * lwIP output callbacks
 * ------------------------------------------------------------------------- */
/* packet is borrowed. sendto copies the stack buffer before returning; lwIP
 * retains responsibility for releasing the original pbuf. */
static err_t raw_linkoutput(struct netif *netif, struct pbuf *packet)
{
    struct endpoint *endpoint = netif->state;
    unsigned char frame[FRAME_MAX] = {0};
    if (!netif_is_link_up(netif) || packet->tot_len < ETH_HLEN ||
        packet->tot_len > sizeof(frame) ||
        pbuf_copy_partial(packet, frame, packet->tot_len, 0) != packet->tot_len) {
        endpoint->tx_errors++;
        return ERR_IF;
    }
    struct sockaddr_ll destination = {0};
    destination.sll_family = AF_PACKET;
    destination.sll_ifindex = endpoint->ifindex;
    destination.sll_halen = ETH_ALEN;
    memcpy(destination.sll_addr, frame, ETH_ALEN);
    memcpy(&destination.sll_protocol, frame + 12, 2);
    /* The zeroed buffer supplies Ethernet padding without exposing stack data. */
    size_t size = packet->tot_len < ETH_ZLEN ? ETH_ZLEN : packet->tot_len;
    if (sendto(endpoint->fd, frame, size, MSG_DONTWAIT,
               (struct sockaddr *)&destination, sizeof(destination)) != (ssize_t)size) {
        endpoint->tx_errors++;
        return ERR_IF;
    }
    endpoint->tx_frames++;
    if (read_be16(frame + 12) == ETH_P_ARP) endpoint->tx_arp++;
    if (read_be16(frame + 12) == ETH_P_IP) endpoint->tx_ipv4++;
    capture_frame(endpoint, frame, size);
    return ERR_OK;
}

static err_t ethernet_init(struct netif *netif)
{
    struct endpoint *endpoint = netif->state;
    netif->name[0] = 'u';
    netif->name[1] = 's';
    netif->mtu = ENDPOINT_MTU;
    netif->hwaddr_len = ETH_ALEN;
    memcpy(netif->hwaddr, endpoint->mac, ETH_ALEN);
    netif->flags = NETIF_FLAG_BROADCAST | NETIF_FLAG_ETHARP | NETIF_FLAG_ETHERNET;
    netif->output = etharp_output;
    netif->linkoutput = raw_linkoutput;
    return ERR_OK;
}

/* The receive callback owns packet. A separate reply provides transport
 * headroom; both references are released here after the send attempt. */
static void udp_echo(void *argument, struct udp_pcb *pcb, struct pbuf *packet,
                     const ip_addr_t *source, u16_t source_port)
{
    struct endpoint *endpoint = argument;
    struct pbuf *reply = pbuf_alloc(PBUF_TRANSPORT, packet->tot_len, PBUF_RAM);
    if (reply == NULL) {
        endpoint->allocation_errors++;
    } else {
        if (pbuf_copy(reply, packet) == ERR_OK &&
            udp_sendto(pcb, reply, source, source_port) == ERR_OK) {
            endpoint->udp_echoes++;
        } else {
            endpoint->udp_errors++;
        }
        pbuf_free(reply);
    }
    pbuf_free(packet);
}

/* -------------------------------------------------------------------------
 * Frame selection and input ownership
 * ------------------------------------------------------------------------- */
/* Return 1 for this endpoint, 0 for unrelated traffic, -1 for malformed input.
 * These checks bound the envelope; lwIP remains responsible for checksums. */
static int select_frame(const struct endpoint *endpoint,
                        const unsigned char *frame, size_t size)
{
    static const unsigned char broadcast[ETH_ALEN] = {255, 255, 255, 255, 255, 255};
    if (size < ETH_HLEN || size > FRAME_MAX) return -1;
    if (memcmp(frame, endpoint->mac, ETH_ALEN) != 0 &&
        memcmp(frame, broadcast, ETH_ALEN) != 0) return 0;
    unsigned type = read_be16(frame + 12);
    if (type == ETH_P_ARP) {
        if (size < 42 || read_be16(frame + 14) != ARPHRD_ETHER ||
            read_be16(frame + 16) != ETH_P_IP || frame[18] != 6 || frame[19] != 4)
            return -1;
        unsigned operation = read_be16(frame + 20);
        if (operation != ARPOP_REQUEST && operation != ARPOP_REPLY) return 0;
        if (memcmp(frame + 38, &endpoint->address.s_addr, 4) != 0) return 0;
        return memcmp(frame + 6, frame + 22, ETH_ALEN) == 0 ? 1 : -1;
    }
    if (type == ETH_P_IP) {
        if (size < ETH_HLEN + 20) return -1;
        if (memcmp(frame + ETH_HLEN + 16, &endpoint->address.s_addr, 4) != 0) return 0;
        const unsigned char *ip = frame + ETH_HLEN;
        size_t header_size = (ip[0] & 15u) * 4u;
        size_t declared_size = read_be16(ip + 2);
        if (ip[0] >> 4 != 4 || header_size < 20 || header_size > declared_size ||
            declared_size > ENDPOINT_MTU || ETH_HLEN + declared_size > size ||
            (read_be16(ip + 6) & 0x3fffu)) return -1;
        return 1;
    }
    return 0;
}

static int receive_frame(struct endpoint *endpoint, struct netif *netif)
{
    unsigned char frame[FRAME_MAX];
    struct sockaddr_ll source;
    socklen_t source_size = sizeof(source);
    /* MSG_TRUNC returns the full frame length, so oversized input is rejected
     * rather than mistaken for a complete frame that fits this buffer. */
    ssize_t count = recvfrom(endpoint->fd, frame, sizeof(frame), MSG_TRUNC,
                             (struct sockaddr *)&source, &source_size);
    if (count < 0) {
        if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) return 0;
        if (errno == ENETDOWN) {
            endpoint->network_down_events++;
            update_link(endpoint, netif, 0);
            return 0;
        }
        perror("recvfrom");
        return -1;
    }
    endpoint->received++;
    if (source.sll_pkttype == PACKET_OUTGOING) {
        endpoint->outgoing_ignored++;
        return 0;
    }
    int selected = select_frame(endpoint, frame, (size_t)count);
    if (selected < 0) {
        endpoint->rejected++;
        return 0;
    }
    if (!selected || !netif_is_link_up(netif)) {
        endpoint->filtered++;
        return 0;
    }
    capture_frame(endpoint, frame, (size_t)count);
    struct pbuf *packet = pbuf_alloc(PBUF_RAW, (u16_t)count, PBUF_RAM);
    if (packet == NULL) {
        endpoint->allocation_errors++;
        return 0;
    }
    /* Copy before entering lwIP: frame is local to this call. */
    if (pbuf_take(packet, frame, (u16_t)count) != ERR_OK) {
        endpoint->allocation_errors++;
        pbuf_free(packet);
        return 0;
    }
    endpoint->rx_frames++;
    if (read_be16(frame + 12) == ETH_P_ARP) endpoint->rx_arp++;
    if (read_be16(frame + 12) == ETH_P_IP) endpoint->rx_ipv4++;
    /* ERR_OK transfers ownership to lwIP; an input error leaves it with us. */
    if (netif->input(packet, netif) != ERR_OK) {
        endpoint->input_errors++;
        pbuf_free(packet);
    }
    return 0;
}

/* -------------------------------------------------------------------------
 * Address validation and endpoint setup
 * ------------------------------------------------------------------------- */
static int kernel_owns_address(struct in_addr address)
{
    struct ifaddrs *interfaces;
    if (getifaddrs(&interfaces) != 0) return -1;
    int found = 0;
    for (struct ifaddrs *item = interfaces; item; item = item->ifa_next) {
        if (item->ifa_addr && item->ifa_addr->sa_family == AF_INET &&
            ((struct sockaddr_in *)item->ifa_addr)->sin_addr.s_addr == address.s_addr)
            found = 1;
    }
    freeifaddrs(interfaces);
    return found;
}

int main(int argc, char **argv)
{
    if (argc < 4 || argc > 5 || strlen(argv[1]) >= IFNAMSIZ) {
        fprintf(stderr, "Usage: %s INTERFACE LWIP_IPV4 SECONDS [NEW_PCAP_FILE]\n", argv[0]);
        return EXIT_FAILURE;
    }
    char *end;
    errno = 0;
    long duration = strtol(argv[3], &end, 10);
    if (errno || *end || end == argv[3] || duration < 1 || duration > 3600) {
        fprintf(stderr, "Seconds must be an integer from 1 through 3600.\n");
        return EXIT_FAILURE;
    }
    struct endpoint endpoint = {.fd = -1};
    memcpy(endpoint.interface, argv[1], strlen(argv[1]) + 1);
    if (inet_pton(AF_INET, argv[2], &endpoint.address) != 1) {
        fprintf(stderr, "Invalid lwIP IPv4 address\n");
        return EXIT_FAILURE;
    }
    uint32_t host_address = ntohl(endpoint.address.s_addr);
    if ((host_address >> 24) == 0 || (host_address >> 24) == 127 ||
        (host_address >> 24) >= 224 || (host_address & 255) == 0 ||
        (host_address & 255) == 255 || kernel_owns_address(endpoint.address) != 0) {
        fprintf(stderr, "Use an unused unicast /24 host address, absent from Linux interfaces.\n");
        return EXIT_FAILURE;
    }
    endpoint.fd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (endpoint.fd < 0) {
        perror("AF_PACKET socket requires CAP_NET_RAW");
        return EXIT_FAILURE;
    }
    struct ifreq request;
    if (interface_request(&endpoint, SIOCGIFINDEX, &request) != 0) goto setup_error;
    endpoint.ifindex = request.ifr_ifindex;
    if (interface_request(&endpoint, SIOCGIFHWADDR, &request) != 0) goto setup_error;
    if (request.ifr_hwaddr.sa_family != ARPHRD_ETHER) {
        fprintf(stderr, "Interface must expose Ethernet frames.\n");
        close(endpoint.fd);
        return EXIT_FAILURE;
    }
    memcpy(endpoint.mac, request.ifr_hwaddr.sa_data, ETH_ALEN);
    if (interface_request(&endpoint, SIOCGIFMTU, &request) != 0) goto setup_error;
    if (request.ifr_mtu < ENDPOINT_MTU) {
        fprintf(stderr, "Interface MTU must be at least %d.\n", ENDPOINT_MTU);
        close(endpoint.fd);
        return EXIT_FAILURE;
    }
    struct sockaddr_ll binding = {0};
    binding.sll_family = AF_PACKET;
    binding.sll_protocol = htons(ETH_P_ALL);
    binding.sll_ifindex = endpoint.ifindex;
    if (bind(endpoint.fd, (struct sockaddr *)&binding, sizeof(binding)) != 0 ||
        fcntl(endpoint.fd, F_SETFL, O_NONBLOCK) != 0) goto setup_error;
    if (argc == 5 && open_capture(&endpoint, argv[4]) != 0) goto setup_error;
    struct sigaction action = {0};
    action.sa_handler = stop_endpoint;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGINT, &action, NULL) != 0 ||
        sigaction(SIGTERM, &action, NULL) != 0) goto setup_error;
    setvbuf(stdout, NULL, _IOLBF, 0);

    lwip_init();
    struct netif netif = {0};
    ip4_addr_t address, netmask, gateway;
    address.addr = endpoint.address.s_addr;
    IP4_ADDR(&netmask, 255, 255, 255, 0);
    IP4_ADDR(&gateway, 0, 0, 0, 0);
    if (netif_add(&netif, &address, &netmask, &gateway, &endpoint,
                  ethernet_init, ethernet_input) == NULL) {
        fprintf(stderr, "netif_add failed\n");
        goto setup_error;
    }
    netif_set_default(&netif);
    netif_set_up(&netif);
    poll_link(&endpoint, &netif);
    struct udp_pcb *echo = udp_new();
    if (echo == NULL || udp_bind(echo, IP_ADDR_ANY, 7) != ERR_OK) {
        fprintf(stderr, "lwIP UDP setup failed\n");
        if (echo) udp_remove(echo);
        netif_remove(&netif);
        goto setup_error;
    }
    udp_recv(echo, udp_echo, &endpoint);
    struct utsname kernel;
    if (uname(&kernel) != 0) snprintf(kernel.release, sizeof(kernel.release), "unknown");
    printf("READY lwip=%s source_tag=%s kernel=%s interface=%s ifindex=%d "
           "ip=%s/24 mac=%02x:%02x:%02x:%02x:%02x:%02x mtu=%d link=%d "
           "arp=1 icmp=1 udp_echo=7 seconds=%ld pid=%ld capture=%d\n",
           LWIP_VERSION_STRING, CAPSTONE_BUILD_TAG, kernel.release,
           endpoint.interface, endpoint.ifindex, argv[2],
           endpoint.mac[0], endpoint.mac[1], endpoint.mac[2],
           endpoint.mac[3], endpoint.mac[4], endpoint.mac[5], ENDPOINT_MTU,
           !!netif_is_link_up(&netif), duration, (long)getpid(), endpoint.capture != NULL);

    /* ---------------------------------------------------------------------
     * Single-threaded service loop
     * --------------------------------------------------------------------- */
    /* NO_SYS requires this loop to service lwIP timers even without traffic. */
    uint64_t started = monotonic_us();
    uint64_t deadline = started + (uint64_t)duration * 1000000;
    uint64_t previous_service = started, next_link_poll = started + 100000;
    int status = EXIT_SUCCESS;
    while (!stopped && monotonic_us() < deadline) {
        fd_set readable;
        FD_ZERO(&readable);
        int watching_socket = !!netif_is_link_up(&netif);
        if (watching_socket) FD_SET(endpoint.fd, &readable);
        struct timeval timeout = {.tv_sec = 0, .tv_usec = 10000};
        /* A down packet socket can stay readable with ENETDOWN. Wait only on
         * the timer until interface polling observes carrier again. */
        int ready = select(watching_socket ? endpoint.fd + 1 : 0,
                           watching_socket ? &readable : NULL, NULL, NULL, &timeout);
        if (ready < 0 && errno != EINTR) {
            perror("select");
            status = EXIT_FAILURE;
            break;
        }
        uint64_t now = monotonic_us();
        uint64_t gap = now - previous_service;
        if (gap > endpoint.max_service_gap_us) endpoint.max_service_gap_us = gap;
        previous_service = now;
        if (now >= next_link_poll) {
            poll_link(&endpoint, &netif);
            next_link_poll = now + 100000;
        }
        if (ready > 0 && receive_frame(&endpoint, &netif) != 0) {
            status = EXIT_FAILURE;
            break;
        }
        sys_check_timeouts();
        endpoint.timer_calls++;
    }
    /* ---------------------------------------------------------------------
     * Cleanup and final counters
     * --------------------------------------------------------------------- */
    /* Remove callbacks and queued netif state before closing their resources.
     * Global lwIP timers may still account for memp entries in the summary. */
    struct tpacket_stats socket_stats = {0};
    socklen_t stats_size = sizeof(socket_stats);
    int socket_stats_valid = getsockopt(endpoint.fd, SOL_PACKET, PACKET_STATISTICS,
                                        &socket_stats, &stats_size) == 0;
    udp_remove(echo);
    netif_remove(&netif);
    if (endpoint.capture && fclose(endpoint.capture) != 0) endpoint.capture_errors++;
    close(endpoint.fd);
    uint64_t memp_used = 0, memp_errors = 0;
    for (unsigned i = 0; i < MEMP_MAX; ++i) {
        if (lwip_stats.memp[i]) {
            memp_used += lwip_stats.memp[i]->used;
            memp_errors += lwip_stats.memp[i]->err;
        }
    }
    printf("SUMMARY received=%" PRIu64 " outgoing_ignored=%" PRIu64
           " filtered=%" PRIu64 " rejected=%" PRIu64 " rx_frames=%" PRIu64
           " rx_arp=%" PRIu64 " rx_ipv4=%" PRIu64 " tx_frames=%" PRIu64
           " tx_arp=%" PRIu64 " tx_ipv4=%" PRIu64 " tx_errors=%" PRIu64
           " udp_echoes=%" PRIu64 " udp_errors=%" PRIu64
           " allocation_errors=%" PRIu64 " input_errors=%" PRIu64
           " ip_checksum_errors=%lu icmp_checksum_errors=%lu udp_checksum_errors=%lu"
           " ip_drops=%lu icmp_drops=%lu udp_drops=%lu arp_drops=%lu"
           " mem_used=%lu mem_max=%lu mem_errors=%lu memp_used=%" PRIu64
           " memp_errors=%" PRIu64 " timer_calls=%" PRIu64
           " max_service_gap_us=%" PRIu64 " link_changes=%" PRIu64
           " link_poll_errors=%" PRIu64 " network_down_events=%" PRIu64
           " capture_frames=%" PRIu64
           " capture_errors=%" PRIu64 " socket_stats_valid=%d socket_packets=%u"
           " socket_drops=%u duration_ms=%" PRIu64 "\n",
           endpoint.received, endpoint.outgoing_ignored, endpoint.filtered, endpoint.rejected,
           endpoint.rx_frames, endpoint.rx_arp, endpoint.rx_ipv4, endpoint.tx_frames,
           endpoint.tx_arp, endpoint.tx_ipv4, endpoint.tx_errors, endpoint.udp_echoes,
           endpoint.udp_errors, endpoint.allocation_errors, endpoint.input_errors,
           (unsigned long)lwip_stats.ip.chkerr, (unsigned long)lwip_stats.icmp.chkerr,
           (unsigned long)lwip_stats.udp.chkerr, (unsigned long)lwip_stats.ip.drop,
           (unsigned long)lwip_stats.icmp.drop, (unsigned long)lwip_stats.udp.drop,
           (unsigned long)lwip_stats.etharp.drop, (unsigned long)lwip_stats.mem.used,
           (unsigned long)lwip_stats.mem.max, (unsigned long)lwip_stats.mem.err,
           memp_used, memp_errors, endpoint.timer_calls, endpoint.max_service_gap_us,
           endpoint.link_changes, endpoint.link_poll_errors, endpoint.network_down_events,
           endpoint.capture_frames,
           endpoint.capture_errors, socket_stats_valid, socket_stats.tp_packets,
           socket_stats.tp_drops, (monotonic_us() - started) / 1000);
    return endpoint.capture_errors ? EXIT_FAILURE : status;

setup_error:
    perror("endpoint setup");
    if (endpoint.capture) fclose(endpoint.capture);
    close(endpoint.fd);
    return EXIT_FAILURE;
}
