# Useful links to get started

I put together a few links to help us get familiar with the project. Feel free to jump to whatever you're working on, and we can add useful links as we go.

## The big picture

We're building toward **PC-to-SDR ping → a working wireless modem → PC-to-PC communication → automatic beam discovery**.

- [Our project overview](project-plan.md) — the system diagram, modules and how the pieces fit together.
- [PySDR: IQ Sampling](https://pysdr.org/content/sampling) — a good introduction to how we represent radio signals digitally. Helpful background for the modem and beamforming work.

## Networking and embedded software

For getting Ethernet, lwIP and packet forwarding working on the processor:

- [IP networking basics](https://github.com/SystemsApproach/book/blob/master/internetworking/basic-ip.rst) — IP addresses, ARP, ping and how packets move between networks.
- [AMD's lwIP guide](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842366/Standalone%2BLWIP%2Blibrary) — getting lwIP running and trying the Ethernet examples. A useful starting point for our PC-to-SDR connection.

## FPGA and Verilog

For the logic we'll build and how it connects to the processor:

- [HDLBits](https://hdlbits.01xz.net/wiki/Problem_sets) — quick Verilog practice if you want a refresher on registers, counters, state machines or testbenches.
- [AMD's AXI guide](https://docs.amd.com/v/u/en-US/ug1037-vivado-axi-reference-guide) — how control registers and data move between FPGA blocks. The introduction is a good place to start; the rest is handy to look things up.

## Wireless modem

For turning packet bits into a signal and recovering them at the other end:

- [PySDR: Digital Modulation](https://pysdr.org/content/digital_modulation) — symbols, constellations and BPSK/QPSK.
- [PySDR: Pulse Shaping](https://pysdr.org/content/pulse_shaping) — the filtering around the transmitter and receiver.
- [PySDR: Synchronization](https://pysdr.org/content/sync) — how the receiver lines up with the incoming signal and finds the start of a packet.

## Hardware and beamforming

For the RF setup, antenna array and steering:

- [PySDR: Link Budgets](https://pysdr.org/content/link_budgets) — making sense of transmit power, signal loss and what reaches the receiver.
- [PySDR: Beamforming](https://pysdr.org/content/doa) — how combining antenna signals with different weights lets us steer a beam. The overview and conventional beamforming sections are the most relevant to our starting design.

## Useful tools

- [Wireshark basics](https://www.wireshark.org/docs/wsug_html_chunked/ChapterIntroduction.html) — seeing the packets on our Ethernet connections when we're debugging ping and routing.
- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow) — a quick reference for branches, pull requests and reviewing each other's changes.

For the AMD examples, we'll use versions that match our board and Vivado/Vitis setup. The [issue list](github-issues.md) has the actual implementation tasks; these links are here whenever we need some background.
