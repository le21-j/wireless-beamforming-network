`timescale 1ns/1ps
// tx_window_sched.sv — WP-F3 (PRODUCER_PLAN_2026-07-28 §DR decisions 7c/8).
//
// ============================================================================
// STATUS: NOT FLASHED. New RTL, staged for the ONE WP-F5 synth. RUNTIME-SELECTABLE
// and DEFAULT OFF: with CONTROL[15]=0 this module's two outputs carry, on every cycle,
// exactly the values of the nets that feed route_b_sync today, so the OFF datapath is
// FUNCTIONALLY the deployed v21/B' datapath. It is NOT byte-identical SILICON — the
// logic cone is still placed and routed; read OFF-STATE IDENTITY (a)/(b) below before
// quoting this in the frm manifest. Never trust this header over the flash/synth
// ledger (tx_dma_gate.sv:16 is the standing warning).
// ============================================================================
//
// WHAT IT IS. A fabric arm/fire WINDOW scheduler for the coherent T4 emit. Today the
// ARM (Linux, on-node) does all of: read beacon_ts (0x64) -> compute t4 = n0 + offset
// in software -> write REG_TX_DEADLINE (0x6C) -> pulse CONTROL[5] -> stage MM2S ->
// poll STATUS. This module moves the DEADLINE ARITHMETIC and the ARM INSTANT into the
// fabric: the ARM programs {ORIGIN, ARM_OFF, FIRE_OFF} once, and the fabric derives
// t_fire = ORIGIN + FIRE_OFF and raises the comparator arm at t_open = ORIGIN + ARM_OFF.
//
//   It moves WHO COUNTS, not WHAT IS COUNTED (plan §DR row 7c). ORIGIN is the SAME
//   beacon-derived n0 the software uses; FIRE_OFF is the SAME offset the software
//   would have added. t1..t4 stay deterministic-from-beacon (non-negotiable N3); the
//   arithmetic is byte-for-byte the software's, executed one level down.
//
// WHAT IT IS NOT. Not a second time base: it OWNS NO COUNTER. Every instant is a
// signed-wrap compare against route_b_sync's existing free-running samp_ctr ruler
// (route_b_sync.sv:52-55, +1 per delivered RX sample = one AIR tick). A private
// countdown would be a second, drift-capable clock and would break the
// continuous-counter invariant the whole coherent design rests on. This is the one
// deliberate deviation from the Sahin baseline shape (his chained 4 x 16-bit
// countdowns exist because he has no shared ruler; we do). It is also NOT the fabric
// matched filter — RED-list R8 is untouched here; timers and comparators carry zero
// CFO exposure (plan §0.2).
//
// COUNTER WIDTH — why 32 bits, and why NOT 16 (finding S2-11).
//   [MEASURED this pass, gcc -DPCP_COHERENT -DSYNC_MAC over firmware/common/config.h,
//    2026-07-28.] TWO flavours ship, and they DISAGREE — this is defect #90 (the
//    test/ship split-brain), so both are recorded and the sizing below takes the LARGER:
//     SAMPLE_RATE_HZ         = 1,920,000      (config.h:152), both flavours
//     BEACON_ONESHOT_SAMPLES = 9,600          (config.h:1212), both flavours
//                                             (the longest single fired transfer)
//     -- bare -DN_RANGING_EDS={1,2,4} (the host-test flavour):
//        PCP_T4_OFFSET_MS    = 7,900   -> T4  = 15,168,000 AIR ticks (24 bits)
//        EPOCH_PERIOD_SAMPLES= 21,120,000     (11,000 ms, 25 bits)
//     -- + -DTRIG_AIR_CEILING_MS_OVERRIDE=8900 (the DEPLOYED flavour,
//        lab_build_pluto_glibc225.sh:174; the T4 value config.h:2388 pins):
//        PCP_T4_OFFSET_MS    = 10,000  -> T4  = 19,200,000 AIR ticks (25 bits)
//        EPOCH_PERIOD_SAMPLES= 25,152,000     (13,100 ms, 25 bits)
//     Both are N-INVARIANT across N = 1/2/4.
//   [DERIVED] 2^31 / 19,200,000 = 111.8x headroom on the signed compare at the DEPLOYED
//   T4 (141.6x at the bare-flavour T4). A 16-bit countdown reaches only 65,535 ticks =
//   34.13 ms at our rate, so expressing the DEPLOYED T4 would need 293 chained 16-bit
//   stages (232 at the bare flavour). That is finding S2-11, and it is why his
//   4-stage / 5 MS/s 52.4 ms figure is chased as a CONCEPT (deterministic fabric
//   sequencing) at OUR grid, never adopted as his geometry (R7 forbids the 5 MS/s move).
//   NOTHING HERE ENCODES 7,900, 10,000 OR ANY T4 VALUE. Both offsets are 32-bit register
//   inputs, so the WP-H3 ledger retune (predicted ~4.6-5.1 s) needs no RTL change. The
//   two PARAMETERS below are the only place a config.h magnitude leaks in, and
//   firmware/tests/test_fabric_sched_contract.c re-checks each against the live
//   constants at every built flavour so neither can go stale in a comment (#105's
//   defect class: an assumption that lives in prose instead of in a checked relation).
//
// OFF-STATE IDENTITY (the WP-F5 four-changes-in-one-frm requirement). State it precisely;
// the two halves are NOT the same claim and conflating them is how a comment becomes a lie.
//
//   (a) FUNCTIONAL identity — PROVEN (tb check 1, and its non-vacuity twin check 1b).
//       sched_sel = sched_en_q & loaded_q; sched_en_q resets to 0 and only ever tracks
//       CONTROL[15]. With CONTROL[15]=0, on EVERY cycle:
//           eff_tx_arm   === sw_tx_arm    (= ctrl[5],       today's route_b_sync .tx_arm)
//           eff_deadline === sw_deadline  (= 0x6C register, today's .tx_deadline)
//       The fired waveform, the arm edge instant and the comparator behaviour are the
//       deployed ones, bit for bit. TWO independent conditions must BOTH hold before the
//       datapath can move: CONTROL[15] must be set AND loaded_q must have set, which
//       requires an AXI write to the NEW 0x7C register that no shipped firmware performs
//       — the same belt-and-braces the CTRL_TX_NEED_BUF opt-in uses (fpga_dsp.c:144).
//
//   (b) SILICON identity — FALSE, and deliberately not claimed. sched_enable is
//       ctrl[15], a live register bit, NOT a synthesis-time constant, so nothing here
//       constant-propagates away: the whole cone is placed and routed, and the two muxes
//       add roughly two LUT levels on ctrl[5] -> route_b_sync.tx_arm and on
//       tx_deadline -> route_b_sync.tx_deadline. Both are static, slow signals (register
//       outputs sampled at a 40 MHz aclk against a free-running counter), so the expected
//       STA impact is negligible — but "expected" is not "measured": the timing check is
//       WP-F5's, on the co-fit DAC-lane report, exactly like the A3 rotator's deferred
//       timing caveat (tx_dma_gate.sv:78-84). Cost is 100 flops (3 x 32-bit target
//       registers + sched_en_q/loaded_q/reject_q/expired_q) plus the compare/adder LUTs.
//       [DERIVED: 3 x 32 + 4 = 100. Was 99 before the F3-2 expiry latch added one FF.]
//       On any pre-WP-F5 frm the module is ABSENT and CONTROL[15] undecoded, so the
//       OFF state there is not merely equivalent to the deployed silicon, it IS it.
//
// THE SAFETY THEOREM (proved in tb_tx_window_sched.sv, check 6).
//   "sched_sel changes ONLY while sw_tx_arm is LOW."
//   Both state bits that form sched_sel are gated on ~sw_tx_arm: sched_en_q samples
//   CONTROL[15] only while disarmed; loaded_q sets only on a load accepted while
//   disarmed, and releases only at window-close while disarmed. Therefore at every
//   sched_sel transition eff_tx_arm is 0 on BOTH sides (0 & win_open = 0 on the ON
//   side, sw_tx_arm = 0 on the OFF side) and the mux can never MANUFACTURE a rising
//   edge on the arm. That matters because route_b_sync arms on the RISING edge of
//   tx_arm (route_b_sync.sv:109) and tx_dma_gate on arm_pulse (tx_dma_gate.sv:190): a
//   manufactured edge while a STALE 0x6C deadline sat in the past would fire an
//   unscheduled burst on air (legacy fire-on-past-deadline, route_b_sync.sv:128).
//   expired_q (see FAIL-SAFE DIRECTION) does NOT appear in sched_sel, so it leaves this
//   proof exactly as it stands: it is a ~AND term on win_open only, able to lower
//   eff_tx_arm and never to raise it, and its own clear is gated on ~sw_tx_arm through
//   load_ok. MEASURED after the fix: TXWIN_MANUFACTURED_ARM_EDGES=0, unchanged.
//
// THE ARM/PUSH ORDERING TRAP — why tx_dma_gate keeps the SOFTWARE arm.
//   tx_dma_gate's IDLE state is TRANSPARENT by design (gated_tx.c:4-8: "a pushed lane
//   radiates at push time unless the gate is ALREADY ARMED"). So the GATE must be
//   armed from the software CONTROL[5] edge, before the MM2S push, or the T4 burst
//   leaks on air at push time. The integration therefore SPLITS the two consumers of
//   CONTROL[5] that are one net today:
//       tx_dma_gate.gate_arm  <- ctrl[5]        UNCHANGED (holds the lane at push)
//       route_b_sync.tx_arm   <- eff_tx_arm     (this module: the fabric arm instant)
//   Splitting them is not merely safe, it is the win: with the lane already held and
//   the descriptor already staged, dma_buf_ready (= tx_dma_gate.s_tvalid) is HIGH
//   before the comparator arms, so route_b_sync's lever#2 pend + LATE-FIRE ABSTAIN
//   race (route_b_sync.sv:92-97, DEFECT-2) cannot trigger. [UNTESTED on air; today's
//   arms are MEASURED 126-190 ms early and armable is 85/85 at the deployed build, so
//   this is insurance against a known epoch-killer, NOT a fix for an observed miss.]
//
// FAIL-SAFE DIRECTION — and the EXPIRY LATCH that makes it true.
//   The hazard, stated first because this header once got it wrong. There is NO
//   standalone disarm in firmware: CTRL_TX_ARM is cleared only inside the clear-then-set
//   of the NEXT arm (fpga_dsp.c:717-718, :731-732), and gated_tx.c:246 records that a
//   timed-out arm leaves tx_dma_gate ARMED. So a node that simply STOPS arming — end of
//   round, lost beacon, aborted epoch — sits with CONTROL[5] HIGH and loaded_q SET
//   indefinitely. loaded_q's only release term is (win_done & ~sw_tx_arm), so it never
//   releases; and at_open/at_close are SIGNED-WRAP compares against LATCHED targets, so
//   one 2^32 lap of the 32-bit ruler later (2237 s = 37.3 min at 1.92 MS/s,
//   route_b_sync.sv:51) the SAME stale schedule reads freshly-open again.
//
//   [MEASURED, not reasoned: tb_tx_window_sched check 16 fired on the pre-fix RTL —
//    "at the lap boundary win_open=1 eff_tx_arm=1", FINDINGS: 2. This paragraph
//    previously claimed the opposite and its own TB contradicted it: audit finding F3-2,
//    CONFORM_F3_2026-07-30.md §7. That is #105's defect class — an assumption living in
//    prose. The banked pre-fix log is hdl/tb/logs/tb_tx_window_sched.unfixed_guard.log.]
//
//   THE MECHANISM (do not re-derive it from this text — read the RTL and check 18):
//   expired_q is a sticky one-shot, SET at win_done and CLEARED only by an ACCEPTED load,
//   ANDed into win_open. A window that has once closed cannot re-open on the same
//   schedule, at any lap. With CONTROL[5] stuck high, loaded_q still never releases —
//   that is deliberate, releasing it while armed would drop sched_sel and MANUFACTURE an
//   arm edge into a stale past 0x6C deadline (the hazard the safety theorem forbids, and
//   the tempting wrong fix) — but win_open is now permanently 0, so eff_tx_arm stays LOW
//   and TX is genuinely QUIET. Quiet is the correct failure direction.
//   CONTROL[15]=0 remains a clean escape (it takes effect at the next disarmed cycle, by
//   the safety theorem), and CONTROL[15] is unwired on every pre-WP-F5 frm.
//
// REGISTER CONTRACT (the integrator owns axi_lite_regs.sv / fpga_dsp.c; this is the ask):
//   0x74 REG_SCHED_ORIGIN   RW  reset 0  epoch anchor n0, samp_ctr AIR ticks
//   0x78 REG_SCHED_ARM_OFF  RW  reset 0  AIR ticks past ORIGIN -> window opens
//   0x7C REG_SCHED_FIRE_OFF RW  reset 0  AIR ticks past ORIGIN -> fire deadline.
//                                        WRITING 0x7C IS THE LOAD STROBE (the 0xA4
//                                        TRIG_WIN_START "write START re-arms" precedent,
//                                        axi_lite_regs.sv:285-288).
//   CONTROL[15] = CTRL_SCHED_ENABLE      global enable, unwired-safe (pre-WP-F5 frm:
//                                        bit undecoded -> module absent -> legacy).
//   Optional RO telemetry (levels, immune to the STATUS clear-on-read strobe):
//   STATUS[16]=sched_loaded  STATUS[17]=sched_win_open  STATUS[18]=sched_reject.
//   0x74/0x78/0x7C are the only three AXI words the 64-word map never decoded
//   (axi_lite_regs.sv write 6'h1C -> 6'h20, read 6'h1B -> 6'h20); 0x94..0xA0 look free
//   in the RTL but are STILL claimed by live firmware (fpga_dsp_arm_arrival /
//   fpga_dsp_read_arrival, fpga_dsp.c:84-87) and must NOT be reused.
//
// FIRMWARE CONTRACT (three rules; violating any one is REFUSED, never mis-scheduled):
//   1. Program 0x74/0x78/0x7C while CONTROL[5] is LOW, then pulse CONTROL[5] — exactly
//      the clear-then-set fpga_dsp_arm_tx_at already does for 0x6C (fpga_dsp.c:579-581).
//   2. FIRE_OFF must put t_fire strictly in the FUTURE and within MAX_HORIZON_TICKS.
//   3. ARM_OFF <= FIRE_OFF. ARM_OFF = 0 (with ORIGIN = beacon_ts, always in the past)
//      opens the window AT the load = today's timing exactly; that is the round-1
//      shipping value. A future ARM_OFF is the epoch-ahead mode and is UNTESTED on air.
//   Any ROTATOR_TX_LATENCY_SAMPLES lead folds into FIRE_OFF exactly as gated_tx.c:99-101
//   folds it into `deadline` today — this module never adjusts the caller's instant.
//
// ROUND-1 A/B, stated precisely so nobody over-claims the result. At the shipping
// ARM_OFF = 0 the window is already open when CONTROL[5] rises, so eff_tx_arm reduces to
// sw_tx_arm and the ONLY thing the ON arm changes is WHO COMPUTED t_fire: the fabric
// (ORIGIN + FIRE_OFF) instead of the ARM (0x6C). That is the whole point of the first
// A/B — it isolates the deadline arithmetic with the arm instant held fixed, and a
// disagreement shows up directly as an eff_deadline vs 0x6C readback mismatch. Moving
// the ARM INSTANT is the ARM_OFF > 0 mode, and that stays UNTESTED until an A/B at
// ARM_OFF = 0 has passed.

`default_nettype none

module tx_window_sched #(
    // Ticks the window stays open PAST the fire deadline. [DERIVED] 19,200 AIR ticks
    // = 10.000 ms at SAMPLE_RATE_HZ 1,920,000 = 2 x BEACON_ONESHOT_SAMPLES (9,600, the
    // longest single fired transfer — the same quantity tx_dma_gate.sv:119-125 sized
    // MAX_BEATS to). It only has to outlast the fire instant plus the burst; the fall
    // is harmless mid-FLOW (tx_dma_gate ignores arm_fall outside GATE_ARMED,
    // tx_dma_gate.sv:257-259) but a whole-burst tail keeps the trace clean. It is
    // 0.076 % of the DEPLOYED EPOCH_PERIOD_SAMPLES (25,152,000 MEASURED; 0.091 % of the
    // bare flavour's 21,120,000), so a window can never bleed into the next epoch.
    // CHECKED, not asserted in prose: test_fabric_sched_contract.c check C3.
    parameter int unsigned WIN_TAIL_TICKS    = 19200,
    // Largest legal program-ahead distance (t_fire - samp_ctr at the load). [DERIVED]
    // 2 x EPOCH_PERIOD_SAMPLES at the DEPLOYED geometry = 2 x 25,152,000 = 50,304,000
    // ticks = 26.2 s. That also clears 2 x the bare flavour's 21,120,000 = 42,240,000,
    // so the "two whole epochs of program-ahead" rule holds at EVERY shippable flavour —
    // the earlier 42,240,000 default did NOT (it sized to the bare flavour only, and
    // test_fabric_sched_contract.c check C4 caught it: defect #90's test/ship split-brain
    // reaching into the RTL). It covers the DEPLOYED T4 (19,200,000) by 2.62x and today's
    // measured 126-190 ms arm lead by ~130x, while staying 42.7x below 2^31 so every
    // signed-wrap compare in here is unambiguous. A larger request means the caller's grid
    // arithmetic is wrong — refuse it rather than schedule it. Same reasoning as the
    // GATED_TX_MAX_WAIT_MS near-wrap backstop (gated_tx.c:76-81, the 2026-07-13 HANG).
    parameter int unsigned MAX_HORIZON_TICKS = 50304000
) (
    input  wire        aclk,
    input  wire        aresetn,

    // The SHARED ruler. Same net route_b_sync drives and exports at 0x60; one AIR tick
    // per delivered RX sample. This module never increments it and never forks it.
    input  wire [31:0] samp_ctr,

    // Legacy sources, passed through verbatim when the scheduler is not selected.
    input  wire        sw_tx_arm,       // CONTROL[5] level
    input  wire [31:0] sw_deadline,     // 0x6C REG_TX_DEADLINE

    input  wire        sched_enable,    // CONTROL[15] CTRL_SCHED_ENABLE
    input  wire [31:0] origin,          // 0x74 REG_SCHED_ORIGIN
    input  wire [31:0] arm_off,         // 0x78 REG_SCHED_ARM_OFF
    input  wire [31:0] fire_off,        // 0x7C REG_SCHED_FIRE_OFF
    input  wire        load_strobe,     // 1-cycle pulse on the 0x7C write

    // To route_b_sync (.tx_arm / .tx_deadline). tx_dma_gate.gate_arm stays on ctrl[5].
    output wire        eff_tx_arm,
    output wire [31:0] eff_deadline,

    // RO telemetry (levels). sched_reject is sticky until the next ACCEPTED load.
    output wire        sched_loaded,
    output wire        sched_win_open,
    output wire        sched_reject
);

    // ------------------------------------------------------------------
    // Load acceptance. Every clause is a REFUSAL, never a silent correction: a refused
    // load leaves the datapath on the legacy sources, which is the behaviour the node
    // has today. (§4.3 rule 2: each clause gets its own negative control in the TB.)
    // ------------------------------------------------------------------
    wire [31:0] t_open_n  = origin + arm_off;
    wire [31:0] t_fire_n  = origin + fire_off;
    wire [31:0] t_close_n = t_fire_n + 32'(WIN_TAIL_TICKS);

    // Signed-wrap distances (the route_b_sync.sv:112 idiom). Valid because every
    // quantity here is bounded by MAX_HORIZON_TICKS << 2^31.
    wire signed [31:0] d_fire_at_load = $signed(t_fire_n - samp_ctr);
    wire signed [31:0] d_open_to_fire = $signed(t_fire_n - t_open_n);

    wire load_future = (d_fire_at_load > 0);                                 // strictly ahead
    wire load_near   = (d_fire_at_load <= $signed(32'(MAX_HORIZON_TICKS)));  // inside the horizon
    wire load_sane   = (d_open_to_fire >= 0);                                // window opens by the fire
    // ~sw_tx_arm is a LOAD PRECONDITION, not just a convention: it is what makes the
    // safety theorem structural (see header). A load attempted while armed is refused.
    wire load_ok     = load_strobe & ~sw_tx_arm & load_future & load_near & load_sane;
    wire load_bad    = load_strobe & ~load_ok;

    // ------------------------------------------------------------------
    // Mode + schedule state. BOTH bits only ever move while sw_tx_arm is LOW.
    // ------------------------------------------------------------------
    logic        sched_en_q;
    logic        loaded_q;
    logic        reject_q;
    logic        expired_q;
    logic [31:0] t_open_q, t_fire_q, t_close_q;

    wire signed [31:0] d_open  = $signed(samp_ctr - t_open_q);
    wire signed [31:0] d_close = $signed(samp_ctr - t_close_q);
    wire at_open  = (d_open  >= 0);
    wire at_close = (d_close >= 0);

    // ~expired_q is THE ONE-SHOT TERM. Without it at_open/at_close are signed-wrap
    // compares against LATCHED targets, so one 2^32 ruler lap (2237 s = 37.3 min at
    // 1.92 MS/s) after t_open they read open-again on the SAME stale schedule and fire an
    // unscheduled T4 burst. See EXPIRY LATCH in the header; tb check 18 is the guard.
    wire win_open = loaded_q & at_open & ~at_close & ~expired_q;
    wire win_done = loaded_q & at_close;

    always_ff @(posedge aclk) begin
        if (!aresetn)        sched_en_q <= 1'b0;
        else if (!sw_tx_arm) sched_en_q <= sched_enable;   // mode moves only while disarmed
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            loaded_q <= 1'b0;
            reject_q <= 1'b0;
            t_open_q <= 32'd0; t_fire_q <= 32'd0; t_close_q <= 32'd0;
        end else if (load_ok) begin
            loaded_q <= 1'b1;
            reject_q <= 1'b0;
            t_open_q <= t_open_n; t_fire_q <= t_fire_n; t_close_q <= t_close_n;
        end else if (load_bad) begin
            // Refused: flag it and leave loaded_q + the latched targets ALONE. Clearing
            // loaded_q here could drop sched_sel while sw_tx_arm is high and manufacture
            // an arm edge — the exact hazard the safety theorem forbids.
            reject_q <= 1'b1;
        end else if (win_done & ~sw_tx_arm) begin
            loaded_q <= 1'b0;                              // release -> legacy resumes
        end
    end

    // ------------------------------------------------------------------
    // EXPIRY LATCH (1 FF). A window that has once CLOSED may never re-open on the same
    // schedule. This is what makes the FAIL-SAFE direction true rather than
    // one-ruler-lap-true (see the header). Priority mirrors the loaded_q block: an
    // ACCEPTED load wins over a simultaneous close, so a fresh schedule programmed on the
    // same cycle a stale one expires is armed, not stillborn.
    //
    // IT CANNOT MANUFACTURE AN ARM EDGE, which is why the safety theorem survives it:
    //   - expired_q does NOT feed sched_sel (= sched_en_q & loaded_q), so the MUX SELECT
    //     is bit-for-bit what it was; the theorem's proof is untouched.
    //   - it enters only as a ~AND term on win_open, so its SET can only drive
    //     eff_tx_arm = sw_tx_arm & win_open DOWN, never up.
    //   - its CLEAR (load_ok) carries ~sw_tx_arm as a load precondition (:load_ok), so on
    //     the one cycle win_open may rise from a clear, eff_tx_arm = 0 & win_open = 0 on
    //     both sides of the edge.
    // Verified, not assumed: tb check 6 (whole-run manufactured-edge monitor) and the
    // DUT's own `sched_sel moved while sw_tx_arm was high` assertion below both stay
    // silent — TXWIN_MANUFACTURED_ARM_EDGES=0.
    // ------------------------------------------------------------------
    always_ff @(posedge aclk) begin
        if (!aresetn)      expired_q <= 1'b0;
        else if (load_ok)  expired_q <= 1'b0;   // a fresh ACCEPTED load re-arms the window
        else if (win_done) expired_q <= 1'b1;   // one close is permanent until the next load
    end

    // ------------------------------------------------------------------
    // Output selection. Two 2:1 muxes; select is constant 0 when CONTROL[15] is 0.
    // ------------------------------------------------------------------
    wire sched_sel = sched_en_q & loaded_q;

    assign eff_tx_arm   = sched_sel ? (sw_tx_arm & win_open) : sw_tx_arm;
    assign eff_deadline = sched_sel ? t_fire_q               : sw_deadline;

    assign sched_loaded   = loaded_q;
    assign sched_win_open = win_open;
    assign sched_reject   = reject_q;

`ifndef SYNTHESIS
    // Restatement of the safety theorem as a runtime check. It is a CHECK, not the
    // mechanism — the mechanism is the ~sw_tx_arm gating on both state bits above.
    // Fires if sched_sel ever moves on a cycle whose incoming sw_tx_arm was high.
    logic sel_d, sw_arm_d;
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            sel_d <= 1'b0; sw_arm_d <= 1'b0;
        end else begin
            if ((sched_sel != sel_d) && sw_arm_d)
                $error("tx_window_sched: sched_sel moved while sw_tx_arm was high");
            sel_d    <= sched_sel;
            sw_arm_d <= sw_tx_arm;
        end
    end
`endif

endmodule

`default_nettype wire
