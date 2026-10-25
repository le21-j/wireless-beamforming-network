`timescale 1ns/1ps
// tx_player.sv
//
// FPGA-resident TX sample player for coherent AirComp (Route-B S0, the substrate
// the COHERENT_AIRCOMP_PLAN §0 reframe shows is MANDATORY — libiio emission is not
// on the FPGA sample ruler, so the only sample-accurate emit path is FPGA-driven).
//
// route_b_sync emits a 1-cycle `fpga_tx_fire` when samp_ctr crosses tx_deadline.
// That pulse STARTS this player, which walks a precoded symbol out of a small
// buffer to the DAC, one sample per accepted DAC beat. Because both EDs latch the
// SAME physical ES beacon into their own samp_ctr (beacon_ts) and both fire off
// beacon_ts in silicon (no ARM/USB/nanosleep in the emit path), their symbols
// leave the DAC aligned to within (detection-latency spread + DAC FIFO spin-up)
// — the <CP (<32-sample) alignment a coherent sum needs.
//
// BUFFER: a FLAT packed [31:0] memory ({im[15:0], re[15:0]} = one cq15_t/sample),
// NOT a cq15_t struct array — the project's struct arrays do NOT infer RAM
// (Synth 8-7186 on samp_buf). ASYNC (distributed-RAM) read so tdata is valid the
// same cycle as tvalid -> a trivially-correct backpressured handshake and a fixed
// 1-cycle start latency off fpga_tx_fire (the calibratable constant the ARM folds
// into tx_deadline). The symbol is small (<=512 samples) so LUTRAM is cheap.
//
// LOAD: the ARM writes the precoded symbol once per epoch over AXI-Lite
// (load_en/load_addr/load_data), then arms tx_deadline + fires. Do NOT stream
// per-sample at runtime (that reintroduces the ARM/USB jitter the player removes).

`default_nettype none

module tx_player #(
    parameter int DEPTH_AW = 9            // 2^9 = 512 samples (>= 1-2 OFDM symbols)
) (
    input  wire                 aclk,
    input  wire                 aresetn,

    // AXI-Lite-driven symbol load (one 32-bit {im,re} word per sample).
    input  wire                 load_en,
    input  wire [DEPTH_AW-1:0]  load_addr,
    input  wire [31:0]          load_data,
    input  wire [DEPTH_AW:0]    symbol_len,   // samples to emit (1 .. 2^DEPTH_AW)

    // Start pulse from route_b_sync (samp_ctr == tx_deadline), 1 cycle.
    input  wire                 fpga_tx_fire,

    // DAC pacing. dac_sample_tick is the AD9361 DAC interpolation sample-request
    // strobe (axi_ad9361/dac_valid_i0): a FREE-RUNNING beat from the chip's rate
    // counter (axi_ad9361_tx.v: dac_rate_cnt), INDEPENDENT of dac_dma. The player
    // walks one sample per tick. tx_dac_tready (= util_upack2.s_axis_ready) is NOT
    // usable as the beat: the ADI upack gates s_axis_ready on pack_shell.ready, which
    // is held in reset whenever the upack channel-enables (dac_enable_i0/q0) are 0 —
    // i.e. whenever dac_dma is idle, which is exactly the player-only TX case. Pacing
    // on it stalls rd_addr at 0 and the DAC repeats mem[0] (the DC/spur no-emit bug,
    // reproduced by tb_tx_player_upack). The free-running tick has no such dependency.
    input  wire                 dac_sample_tick,
    output wire                 player_tvalid,
    output wire [31:0]          player_tdata, // {im[15:0], re[15:0]}
    output wire                 player_active // high while emitting -> wrap TX mux select
);

    // Symbol store. Distributed RAM, async read (mem[rd_addr] is combinational).
    (* ram_style = "distributed" *) logic [31:0] mem [0:(1<<DEPTH_AW)-1];

    always_ff @(posedge aclk) begin
        if (load_en) mem[load_addr] <= load_data;
    end

    // Read-out FSM. Start on fpga_tx_fire; advance one sample per accepted beat;
    // stop after symbol_len samples. rd_addr HOLDS when tx_dac_tready is low
    // (backpressure), so the same sample is re-presented until accepted.
    logic                active;
    logic [DEPTH_AW-1:0] rd_addr;
    logic [DEPTH_AW:0]   remaining;
    wire                 beat = active & dac_sample_tick;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            active <= 1'b0; rd_addr <= '0; remaining <= '0;
        end else if (!active) begin
            if (fpga_tx_fire && (symbol_len != 0)) begin
                active    <= 1'b1;
                rd_addr   <= '0;
                remaining <= symbol_len;
            end
        end else if (beat) begin
            rd_addr   <= rd_addr + 1'b1;
            remaining <= remaining - 1'b1;
            if (remaining == 1) active <= 1'b0;   // last sample accepted this beat
        end
    end

    assign player_tdata  = mem[rd_addr];   // async read; valid same cycle as tvalid
    assign player_tvalid = active;
    assign player_active  = active;

endmodule

`default_nettype wire
