# lwIP Ethernet endpoint on Pluto

This application runs on Pluto's Linux CPU and gives lwIP its own IPv4 address on the existing USB network interface. Linux supplies the USB Ethernet driver; lwIP handles ARP, ping and UDP echo on port 7. The host talks to that address with ordinary network tools.

The application uses one event loop and bounded memory. It does not configure RF or the FPGA. This is a Linux USB implementation; a bare-metal or RTOS BSP remains separate work.

## Build on Linux or WSL

Run these commands from the repository root in Bash. You need `curl`, `tar`, the standard GNU command-line utilities used by the build script, and a Pluto-compatible ARM Linux cross-compiler with static C libraries. Choose a compiler that matches the target Pluto's CPU, ABI and firmware. The [ADI embedded applications guide](https://wiki.analog.com/university/tools/pluto/devs/embedded_code) describes the Pluto toolchain and deployment setup.

Download the pinned upstream lwIP 2.1.3 release and verify the archive before extracting it:

```bash
mkdir -p build/deps
curl -L --fail https://github.com/lwip-tcpip/lwip/archive/refs/tags/STABLE-2_1_3_RELEASE.tar.gz \
  -o build/deps/lwip-2.1.3.tar.gz
echo '6add930f7c0c7a8adbe3fef393ecf47ce32ed8dadd00d23042ff61db05b194ef  build/deps/lwip-2.1.3.tar.gz' | sha256sum -c - && \
  tar -xzf build/deps/lwip-2.1.3.tar.gz -C build/deps
```

Set `CC` to your installed compiler. Replace the example path before running:

```bash
export CC=/path/to/pluto-toolchain/bin/arm-buildroot-linux-gnueabihf-gcc
"$CC" --version
bash firmware/net/lwip_ethernet/sw_build.sh build/lwip_ethernet/lwip_ethernet
```

If `CC` is unset, the script uses `arm-linux-gnueabihf-gcc` from `PATH`; that compiler must still be compatible with your Pluto. `LWIP_SRC` defaults to `build/deps/lwip-STABLE-2_1_3_RELEASE/src`. To use an existing copy of the same release, set `LWIP_SRC` to its `src` directory.

The script statically links the application and lwIP. It generates configuration headers and build metadata beside the executable. Keep the generated `lwip_ethernet.lwip-notice.txt` with any copied executable; it contains the upstream license and source notices.

## Choose the board and endpoint addresses

First confirm that the host can reach Pluto's existing Linux management address. The lwIP address must be unused, different from the host and Linux addresses, and in the same `/24` subnet as the host USB adapter. Do not assign the lwIP address to Linux. The application rejects an address already assigned to a local Linux interface.

For example, a board managed at `192.168.7.7` can use `192.168.7.2` for lwIP if that address is free and the host USB adapter is on `192.168.7.0/24`. A second board on `192.168.8.0/24` needs its own unused address. Use the actual addresses configured on your boards.

In a host Bash terminal, set the first board's addresses and inspect its interface:

```bash
PLUTO=192.168.7.7
LWIP_IP=192.168.7.2
ssh "root@$PLUTO" 'ifconfig usb0'
```

`usb0` must be an Ethernet interface with MTU 1500 or greater. The process needs `CAP_NET_RAW`; the root login supplies it. Confirm that the chosen lwIP address does not answer ping before starting the application.

## Copy and run manually

Use an SSH client and SCP from a host environment that can reach the board. Authenticate with that board's configured credentials. These commands create a temporary directory and copy only the executable and its notices:

```bash
REMOTE_DIR=$(ssh "root@$PLUTO" 'mktemp -d /tmp/lwip-ethernet.XXXXXX') || exit 1
[[ "$REMOTE_DIR" == /tmp/lwip-ethernet.* ]] || exit 1
printf 'Temporary board directory: %s\n' "$REMOTE_DIR"
scp -O build/lwip_ethernet/lwip_ethernet \
  build/lwip_ethernet/lwip_ethernet.lwip-notice.txt \
  "root@$PLUTO:$REMOTE_DIR/"
ssh -t "root@$PLUTO" \
  "chmod 700 '$REMOTE_DIR/lwip_ethernet' && '$REMOTE_DIR/lwip_ethernet' usb0 '$LWIP_IP' 1800"
```

`scp -O` selects the legacy SCP protocol for firmware without an SFTP server. Leave the SSH terminal open while checking the endpoint from a second host terminal. Wait for `READY` and confirm the reported interface, lwIP address and `link=1`.

The required duration is in seconds, from 1 through 3600. This example runs for 30 minutes. Ctrl+C, SIGINT or SIGTERM requests cleanup and exit. The application leaves the Linux interface addresses and routes unchanged.

## Check ping and UDP from the host

Run traffic from the host operating system that owns the Pluto USB network adapter. On Windows, use a Windows terminal and Python installation. On Linux, use a terminal with a route to that USB subnet. The Python tool requires Python 3.10 or newer and only the standard library.

Warm up ARP, then count 1,000 ping replies. Replace the example address with your lwIP address.

Windows:

```powershell
ping -n 3 192.168.7.2
ping -n 1000 192.168.7.2
```

Linux:

```bash
ping -c 3 192.168.7.2
ping -c 1000 192.168.7.2
```

Check for 1,000 replies and zero loss in the second command. At the default ping interval this takes about 17 minutes. Run the UDP check while the application is still active:

```text
python tools/sw_network_probe.py udp --host 192.168.7.2 --port 7 --count 1000 --sizes 32 64 512 1400 1472 --rate 100
```

Use `python3` if that is your Python command. The tool cycles through those UDP payload sizes, including its 32-byte sequence header. Port 7 must be explicit because the generic tool's default is port 5001. The largest size, 1472 bytes, fits this application's 1500-byte IPv4 MTU without fragmentation.

The UDP command prints JSON and returns zero only when its checks pass. Expect `passed: true`, `delivered_unique: 1000`, zero loss, and no corrupt, duplicate, out-of-order or unexpected replies. Use `python tools/sw_network_probe.py udp --help` for the available options. This tool checks delivery to the selected endpoint; the separate unused IP and running application identify this as the lwIP endpoint rather than Pluto's Linux management stack.

## Stop and remove the temporary copy

Stop the application with Ctrl+C in its SSH terminal, or let its duration expire. Confirm that the lwIP address stops replying while Pluto's Linux management address remains reachable. In the original Bash terminal, remove the two files from the temporary directory printed earlier:

```bash
ssh "root@$PLUTO" \
  "rm -- '$REMOTE_DIR/lwip_ethernet' '$REMOTE_DIR/lwip_ethernet.lwip-notice.txt' && rmdir -- '$REMOTE_DIR'"
```

Repeat the deployment and host checks on each board using that board's management and lwIP addresses.

## Application boundaries

The adapter receives Ethernet frames through `AF_PACKET`, checks their destination and IPv4 bounds, copies accepted frames into lwIP buffers, and passes them to `ethernet_input`. Replies return through the adapter's Ethernet output callback. lwIP validates IPv4, ICMP and nonzero UDP checksums. This configuration does not accept IP fragments or VLAN-tagged frames.

The event loop services lwIP timers between packets and polls link state every 100 ms. On link loss it clears queued ARP state and keeps servicing timers until the link returns. It releases the UDP buffers, socket and netif during cleanup. `SUMMARY` counters describe the process; a successful send submission alone does not establish that the host received the reply.
