`timescale 1ns/1ps
// route_b_sync.sv
//
// Route-B deterministic ACK timing (2026-06-03; see docs/plans/ROUTE_B_SYNC_PLAN.md).
//
// Three building blocks that turn the async, clock-free ED ACK timing (which made
// two EDs' bursts collide) into a sample-accurate, FPGA-fired schedule:
//   1. samp_ctr   — a free-running counter, one tick per delivered RX sample, the
//                   shared "ruler" both beacon-detect and ACK-scheduling reason in.
//   2. beacon_ts  — samp_ctr latched at the beacon detect pulse (the ED's "when did
//                   I hear the beacon"), sticky-valid, cleared when the ARM reads it.
//   3. fpga_tx_fire — a one-cycle pulse when samp_ctr reaches a programmed
//                   tx_deadline while armed; the ARM sets tx_deadline =
//                   beacon_ts + aid*slot, so each ED's ACK fires in its own slot with
//                   sample precision. tx_fired is the sticky status the ARM polls
//                   (then issues the libiio ACK push — Route-B §5.1).
//
// Pure register logic, no external dependencies — unit-tested by tb_route_b_sync.sv
// and instantiated in aircomp_core.sv. AXI-Lite exposure: samp_ctr@0x60, beacon_ts@
// 0x64, beacon_ts_valid@0x68 (clear-on-read), tx_deadline@0x6C, CONTROL[5]=tx_arm,
// STATUS[8]=tx_fired, TX_FIRE_ACK@0x70 (W1C).

`default_nettype none

module route_b_sync (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        rx_adc_tvalid,        // one pulse per delivered RX sample
    input  wire        ts_trigger,           // beacon detect (det_pulse_rx, or _tx for ES)
    input  wire [31:0] ts_value,             // sample instant to latch as beacon_ts at ts_trigger.
                                             // ED autocorr path: peak_ctr (metric ARGMAX, SNR-invariant).
                                             // All other paths: samp_ctr (fire-cycle), preserving v17.
    input  wire        tx_arm,               // CONTROL[5] level: rising edge arms
    input  wire        arm_needs_buffer,     // CONTROL[8]: per-arm OPT-IN to the lever#2 buffer gate.
                                             // 0 (legacy bare-arm) => byte-identical v17 (fire on edge,
                                             // late-fire-on-past-deadline preserved). 1 (coherent gated
                                             // DMA TX) => arm pends on dma_buf_ready + abstains if late.
    input  wire        dma_buf_ready,        // lever#2: MM2S descriptor staged (tx_dma_gate.s_tvalid).
                                             // Consumed ONLY when arm_needs_buffer=1.
    input  wire [31:0] tx_deadline,          // 0x6C: sample index to fire at
    input  wire        beacon_ts_rd_strobe,  // read of 0x68 clears beacon_ts_valid
    input  wire        tx_fire_ack_strobe,   // write of 0x70 clears tx_fired

    output logic [31:0] samp_ctr,
    output logic [31:0] beacon_ts,
    output logic        beacon_ts_valid,
    output logic        fpga_tx_fire,         // 1-cycle pulse at the deadline
    output logic        tx_fired              // sticky STATUS[8]; W1C via tx_fire_ack
);

    // 1.1 free-running sample counter (wraps at 2^32 ~= 37 min @ 1.92 MS/s).
    always_ff @(posedge aclk) begin
        if (!aresetn)           samp_ctr <= 32'd0;
        else if (rx_adc_tvalid) samp_ctr <= samp_ctr + 32'd1;
    end

    // 1.2 beacon-detect timestamp latch (sticky-valid, clear-on-read).
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            beacon_ts <= 32'd0; beacon_ts_valid <= 1'b0;
        end else if (ts_trigger) begin
            beacon_ts <= ts_value; beacon_ts_valid <= 1'b1;
        end else if (beacon_ts_rd_strobe) begin
            beacon_ts_valid <= 1'b0;
        end
    end

    // 1.3 TX-arm comparator. Rising edge of tx_arm arms; fire one cycle when samp_ctr
    // reaches tx_deadline. Signed-wrap-safe compare handles a counter wrap mid-deadline.
    //
    // LEVER#2 (v19): an OPT-IN two-step arm, selected per-arm by arm_needs_buffer (CONTROL[8]).
    //
    // WHY OPT-IN: route_b_sync also serves the LEGACY bare-arm ACK (state_machine.c:839 ->
    // fpga_dsp_arm_tx_at: writes DEADLINE + CONTROL[5] edge ONLY, no MM2S stage). That path has
    // NO staged buffer, so dma_buf_ready stays LOW forever — an unconditional buffer gate would
    // never complete the arm, fpga_tx_fire never pulses, and wait_tx_fire burns its full timeout
    // every legacy ACK. So the buffer gate must apply ONLY to the coherent gated-DMA TX. The ARM
    // raises CONTROL[8] for the gated path (fpga_dsp_arm_tx_at_gated) and leaves it 0 for the
    // bare-arm (fpga_dsp_arm_tx_at clears it). eff_buf_ready folds the opt-in in:
    //   arm_needs_buffer=0 -> eff_buf_ready=1 -> arm_complete == tx_arm_rise -> byte-identical v17.
    //   arm_needs_buffer=1 -> eff_buf_ready=dma_buf_ready -> the real buffer gate (coherent path).
    //
    // COHERENT GATE (arm_needs_buffer=1): gated_tx_fire (firmware/common/gated_tx.c:41-43) asserts
    // CONTROL[5] tx_arm FIRST, then stages the MM2S descriptor — so the buffer is NOT primed at the
    // tx_arm rising edge; dma_buf_ready (= tx_dma_gate.s_tvalid) goes high only later when the
    // descriptor loads. The rising edge only PENDS the arm (arm_pending); the arm completes — and
    // the deadline compare may fire — only once dma_buf_ready is high. arm_pending is sticky (a flop
    // surviving until completion or disarm) precisely BECAUSE buffer-ready arrives strictly AFTER the
    // edge. dma_buf_ready is consumed at LEVEL: axi_dmac holds s_tvalid high while the descriptor is
    // queued, so the level cleanly marks "buffer staged" for the whole hold window.
    //
    // LATE-FIRE ABSTAIN (DEFECT-2, arm_needs_buffer=1 ONLY): if buffer-ready arrives AFTER samp_ctr
    // already crossed tx_deadline, completing the arm would fire one cycle LATE into a PAST deadline
    // and poison the coherent superposition (lever#1 firmware-void keys on fire-FAIL, not late-fire).
    // So when an arm would complete with the deadline already passed, ABSTAIN: do not set tx_armed,
    // do not fire — emit nothing. The ED firmware (lever#1) abstains+voids on a coherent no-fire, so
    // this is the safe path. Gated on arm_needs_buffer ONLY: legacy keeps v17's fire-on-past-deadline.
    // #44 fix (e): !tx_arm is a TRUE disarm. The pre-fix code cleared only arm_pending on
    // !tx_arm, so a COMPLETED-but-unfired arm (tx_armed=1) survived a firmware abandonment
    // (poll timeout -> firmware gives up + destroys the descriptor but leaves tx_armed set)
    // and later fired LATE when the deadline finally crossed — a stale emit into a dead epoch
    // (cascade step 5). Hoisting the whole arm/fire chain under `else` (tx_arm high) makes a
    // gate_arm low the exclusive top branch: it clears BOTH arm_pending AND tx_armed and
    // emits no fire. The firmware clear-then-set re-arm helper (fpga_dsp.c:405-407 / 419-421)
    // still arms cleanly — its momentary CTRL[5] low disarms, its set edge re-arms fresh.
    // The normal fire path is unchanged: a legitimate fire always occurs while tx_arm is
    // still high (firmware holds CTRL[5] until it acks the fire), i.e. inside this `else`.
    logic tx_armed, tx_arm_d, arm_pending;
    wire  tx_arm_rise    = tx_arm & ~tx_arm_d;
    wire  eff_buf_ready  = dma_buf_ready | ~arm_needs_buffer;
    wire  arm_complete   = (arm_pending | tx_arm_rise) & eff_buf_ready;
    wire  deadline_past  = !($signed(samp_ctr - tx_deadline) < 0);
    wire  arm_too_late   = arm_complete & arm_needs_buffer & deadline_past;  // coherent late -> abstain
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            tx_armed <= 1'b0; tx_arm_d <= 1'b0; arm_pending <= 1'b0; fpga_tx_fire <= 1'b0;
        end else begin
            tx_arm_d     <= tx_arm;
            fpga_tx_fire <= 1'b0;
            if (!tx_arm) begin
                arm_pending <= 1'b0;                    // (e) firmware abort: drop a PENDING arm
                tx_armed    <= 1'b0;                    // (e) AND a COMPLETED arm -> no stale late fire
            end else if (arm_too_late) begin
                arm_pending <= 1'b0;                    // coherent + buffer arrived past deadline: abstain
            end else if (arm_complete) begin
                tx_armed    <= 1'b1;
                arm_pending <= 1'b0;
            end else if (tx_armed && deadline_past) begin
                fpga_tx_fire <= 1'b1;
                tx_armed     <= 1'b0;
            end else if (tx_arm_rise && !eff_buf_ready) begin
                arm_pending <= 1'b1;                    // pend until the MM2S buffer is staged
            end
        end
    end

    // STATUS[8] tx_fired: set on fire, cleared by W1C (the ARM polls then acks). #44 fix (e-2):
    // a fresh arm edge (tx_arm_rise) ALSO clears it, so a stale tx_fired left set by a real past
    // fire that the firmware never acked (it polled, timed out before the fire, gave up) cannot
    // phantom-succeed the NEXT epoch's poll (cascade step 5, second clause). A fire and an arm
    // edge never coincide (arm, wait for the deadline, then fire), and fpga_tx_fire keeps priority.
    always_ff @(posedge aclk) begin
        if (!aresetn)                              tx_fired <= 1'b0;
        else if (fpga_tx_fire)                     tx_fired <= 1'b1;
        else if (tx_fire_ack_strobe || tx_arm_rise) tx_fired <= 1'b0;
    end

endmodule

`default_nettype wire
