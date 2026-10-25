`timescale 1ns/1ps
// tb_tx_window_sched.sv — fail-first unit test for hdl/rtl/tx_window_sched.sv (WP-F3).
//
// samp_ctr is an INPUT to the DUT (it is route_b_sync's shared ruler, not a counter this
// module owns), so the TB can JAM it to any value. That is what makes it possible to
// exercise the REAL SSOT magnitudes — a 15,168,000-tick T4 offset and a 2^32 wrap — in a
// handful of clock edges instead of 15 million.
//
// SSOT constants used here, MEASURED 2026-07-28 by compiling firmware/common/config.h with
// gcc -DPCP_COHERENT -DSYNC_MAC. TWO flavours ship and they disagree (defect #90):
//   bare -DN_RANGING_EDS={1,2,4}:        T4 7,900 ms = 15,168,000 ticks, epoch 21,120,000
//   + -DTRIG_AIR_CEILING_MS_OVERRIDE=8900 (DEPLOYED): T4 10,000 ms = 19,200,000 ticks,
//                                                     epoch 25,152,000
//   both: SAMPLE_RATE_HZ 1,920,000 · BEACON_ONESHOT_SAMPLES 9,600 · N-invariant.
// The fixtures below run at the BARE T4; check 13 re-runs the accept/substitute path at
// the DEPLOYED T4 so the shipping magnitude is exercised too.
//
// Checks:
//   1  OFF-STATE IDENTITY — CONTROL[15]=0: eff_tx_arm === sw_tx_arm and
//      eff_deadline === sw_deadline on EVERY cycle, even with a schedule loaded.
//      Sampled at THREE phases per cycle (posedge, +2 ns, +7 ns) — see the monitors.
//   1b NON-VACUITY of check 1, deadline half — with CONTROL[15]=1 the deadline DIVERGES.
//   1c NON-VACUITY of check 1, ARM half — with CONTROL[15]=1 eff_tx_arm differs from
//      sw_tx_arm at least once (else check 1's arm equality proves nothing).
//   2  Load accepted while disarmed; deadline substitution is exact at T4 scale.
//   3  Window opens AT t_open, not one tick early (delayed-arm mode).
//   4  eff_tx_arm == sw_tx_arm & win_open inside the window.
//   5  Window closes at t_fire + WIN_TAIL_TICKS -> fabric disarm.
//   6  SAFETY THEOREM — no rising edge of eff_tx_arm is ever manufactured by the mux
//      (continuous monitor, armed for the whole run).
//   7  Refusal: deadline already past.
//   8  Refusal: beyond MAX_HORIZON_TICKS.
//   9  Refusal: ARM_OFF > FIRE_OFF (window could never open before the fire).
//   10 Refusal: load attempted while CONTROL[5] is high (previous schedule untouched).
//   11 Release requires sw_tx_arm low (no release, hence no mux move, while armed).
//   12 2^32 wrap: origin chosen so t_fire wraps; open/close still correct.
//   13 the DEPLOYED T4 magnitude (19,200,000 ticks) loads and substitutes exactly.
//   14 OFF-STATE IDENTITY *AFTER* AN ON PHASE — the property round 1's alternate-epoch
//      A/B actually rests on. Check 1 only ever proves identity on a module that has
//      never been enabled; 14 drops CONTROL[15] back to 0 with a schedule LOADED and
//      re-proves identity under the same traffic. Without this, "default OFF ⇒
//      byte-identical" is proven for epoch 0 only.
//   15 THE DEPLOYED T4, FULL LIFECYCLE + THE WIDTH ARGUMENT. 15a delayed-arm window at
//      19,200,000 ticks; 15b a 2^32 wrap at the deployed magnitude (12 only wrapped at
//      the bare one); 15c the signed-compare headroom, computed in-sim and asserted
//      rather than narrated; 15d the sign-inversion falsifier — a program-ahead of 2^31
//      is REFUSED, never silently mis-scheduled, which is what makes the 32-bit signed
//      compare sound.
//   16 FINDING probe — the FAIL-SAFE claim in the RTL header (section "FAIL-SAFE
//      DIRECTION", tx_window_sched.sv:123-150 at the time of writing; cite the SECTION,
//      not the line, this is the #105 drift class) that "past t_close, eff_tx_arm stays
//      LOW: TX goes QUIET". It FIRED on the pre-fix RTL, where it held for ONE 2^32 lap
//      of samp_ctr only. Counted in `findings`, NOT in `fails`: the module contract was
//      intact, a claim the frm manifest carried was not. CLEARED by the expiry latch
//      (audit finding F3-2, CONFORM_F3_2026-07-30.md §7) — kept in place as the probe
//      that scores the PROSE, with check 18 below scoring the mechanism.
//   17 An ACCEPTED load CLEARS the sticky reject. Check 2 asserts reject==0 after an
//      accept but no refusal precedes it there, so check 2 is vacuous for this. The
//      firmware verdict {loaded=1,reject=0} (fpga_dsp_sched_program) rests on it.
//   18 THE REGRESSION GUARD for the expiry latch (`expired_q`, the F3-2 fix). Hard
//      `check()`s, NOT findings: 16 scores a PROSE claim, 18 scores the MECHANISM, so a
//      future edit that deletes expired_q reds this TB instead of quietly restoring a
//      37-minute-periodic unscheduled T4 burst. 18a the lap boundary; 18b the second
//      lap's t_fire/t_close instants — the exact instants route_b_sync would fire;
//      18c NON-VACUITY: the latch must CLEAR on the next accepted load, else the "fix"
//      bricks the scheduler and 18a/18b would pass for the wrong reason; 18d the
//      PRIORITY case — a fresh load landing on the same edge a stale window expires must
//      be accepted and NOT born expired (load_ok ahead of win_done in the latch).
//      [MEASURED on the UNFIXED RTL (expired_q absent), banked at
//       hdl/tb/logs/tb_tx_window_sched.unfixed_guard.log: 18a x2 and 18b x2 fire,
//       TXWIN_CONTRACT_FAILS=4, TXWIN_CHECKS_RUN=126. 18c PASSES there — it is the
//       non-vacuity twin, not the detector. A check never seen to fail is not a check.]
//
// Prints "tb_tx_window_sched OK" and $finish only when BOTH counters are zero; a FINDING
// alone withholds the OK string, so a grep gate cannot go green on a false manifest claim.

module tb_tx_window_sched;

    localparam int unsigned WIN_TAIL    = 19200;
    localparam int unsigned MAX_HORIZON = 50304000;   // 2 x DEPLOYED EPOCH_PERIOD_SAMPLES
    localparam int unsigned T4_TICKS    = 15168000;   // 7,900 ms x 1,920,000 Hz (bare)
    localparam int unsigned T4_DEPLOYED = 19200000;   // 10,000 ms x 1,920,000 Hz (shipped)
    localparam int unsigned ARM_LEAD    = 1920000;    // 1.000 s of delayed-arm lead (check 15a)
    // Origin for the 2^32-lap probe (check 16). Any value works; a round one keeps the log
    // readable. It must sit far enough below 2^32 that ORIGIN + T4_DEPLOYED does NOT wrap,
    // so the lap under test is the RULER's, not the schedule's (12/15b cover the latter).
    localparam logic [31:0] LAP_BASE    = 32'h0100_0000;
    // The usable span of a $signed(a-b) compare is 2^31, NOT 2^32 — every instant test in
    // the DUT is signed (tx_window_sched.sv, the five $signed() sites: d_fire_at_load /
    // d_open_to_fire / load_near / d_open / d_close), so this is the divisor for headroom.
    localparam longint      SIGNED_SPAN = 64'd2147483648;

    logic        aclk = 0;
    logic        aresetn;
    logic [31:0] samp_ctr;
    logic        sw_tx_arm;
    logic [31:0] sw_deadline;
    logic        sched_enable;
    logic [31:0] origin, arm_off, fire_off;
    logic        load_strobe;

    wire         eff_tx_arm;
    wire [31:0]  eff_deadline;
    wire         sched_loaded, sched_win_open, sched_reject;

    int fails      = 0; // module CONTRACT violations. Must be 0.
    int findings   = 0; // properties the RTL header / frm manifest CLAIM but the DUT lacks.
    // A green must name its COUNT (the standing repo rule: an unchanged rule count beside a
    // new rule was the only tell that three rules never ran). If a future edit strands a
    // block of checks behind an early $finish or a mis-set fixture, `fails` stays 0 and only
    // this number moves.
    int checks_run = 0;

    tx_window_sched #(
        .WIN_TAIL_TICKS(WIN_TAIL),
        .MAX_HORIZON_TICKS(MAX_HORIZON)
    ) dut (
        .aclk(aclk), .aresetn(aresetn),
        .samp_ctr(samp_ctr),
        .sw_tx_arm(sw_tx_arm),
        .sw_deadline(sw_deadline),
        .sched_enable(sched_enable),
        .origin(origin), .arm_off(arm_off), .fire_off(fire_off),
        .load_strobe(load_strobe),
        .eff_tx_arm(eff_tx_arm), .eff_deadline(eff_deadline),
        .sched_loaded(sched_loaded), .sched_win_open(sched_win_open),
        .sched_reject(sched_reject)
    );

    always #5 aclk = ~aclk;

    task automatic check(bit cond, string msg);
        checks_run++;
        if (!cond) begin $display("FAIL: %s", msg); fails++; end
    endtask

    // A FINDING is a claim made in prose (RTL header / FRM manifest) that the DUT does not
    // satisfy. It is kept OUT of `fails` so the two verdicts stay separable: the module can
    // be contract-correct while a safety argument written about it is false. Both must be
    // zero for the OK string.
    task automatic finding(bit cond, string msg);
        if (!cond) begin $display("FINDING: %s", msg); findings++; end
    endtask

    // One AXI-write-shaped load: program the three words then pulse the 0x7C strobe.
    task automatic do_load(input [31:0] o, input [31:0] a, input [31:0] f);
        @(negedge aclk);
        origin = o; arm_off = a; fire_off = f; load_strobe = 1'b1;
        @(posedge aclk);
        @(negedge aclk);
        load_strobe = 1'b0;
        @(posedge aclk);
    endtask

    task automatic set_ctr(input [31:0] v);
        @(negedge aclk); samp_ctr = v; @(posedge aclk);
    endtask

    // ---- check 6: the safety theorem, monitored for the WHOLE run ----------------
    // Any rise of eff_tx_arm must be explained by a rise of sw_tx_arm or of win_open.
    // A rise produced by sched_sel moving would be a MANUFACTURED arm edge: route_b_sync
    // arms on the rising edge (route_b_sync.sv:109), so a manufactured one with a stale
    // past 0x6C deadline emits an unscheduled burst on air.
    logic prev_arm, prev_sw, prev_win;
    int   manufactured_edges = 0;
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            prev_arm <= 1'b0; prev_sw <= 1'b0; prev_win <= 1'b0;
        end else begin
            if (eff_tx_arm && !prev_arm
                && !((sw_tx_arm && !prev_sw) || (sched_win_open && !prev_win))) begin
                manufactured_edges++;
                $display("FAIL: manufactured eff_tx_arm rise at t=%0t (sw=%0b win=%0b sel_loaded=%0b)",
                         $time, sw_tx_arm, sched_win_open, sched_loaded);
            end
            prev_arm <= eff_tx_arm;
            prev_sw  <= sw_tx_arm;
            prev_win <= sched_win_open;
        end
    end

    // ---- check 1: OFF-state identity, sampled every cycle while armed for it -----
    bit  identity_armed = 0;
    int  identity_samples = 0;
    int  identity_breaks  = 0;
    always_ff @(posedge aclk) begin
        if (aresetn && identity_armed) begin
            identity_samples++;
            if (eff_tx_arm !== sw_tx_arm || eff_deadline !== sw_deadline) begin
                identity_breaks++;
            end
        end
    end

    // ---- check 1, second witness: OFF-state identity sampled OFF the clock edges ---
    // The monitor above samples only at posedge. That is blind to two things a frm claim
    // must not be blind to: (i) a passthrough that is combinational but WRONG for part of
    // the cycle, and (ii) an implementation that re-times the arm and happens to agree at
    // every posedge. These two phases are chosen to miss every stimulus edge in the TB —
    // the DUT is clocked at posedge (t) and all stimulus moves at negedge (t+5), so t+2 is
    // mid-high and t+7 is 2 ns AFTER the stimulus moves, which is exactly where a
    // "follows only on the next clock" passthrough would show up as a mismatch.
    int cont_samples = 0;
    int cont_breaks  = 0;
    always @(posedge aclk) begin
        #2;
        if (aresetn && identity_armed) begin
            cont_samples++;
            if (eff_tx_arm !== sw_tx_arm || eff_deadline !== sw_deadline) begin
                cont_breaks++;
                $display("FAIL: OFF-state identity broken mid-cycle at t=%0t (arm %0b/%0b dl %0h/%0h)",
                         $time, eff_tx_arm, sw_tx_arm, eff_deadline, sw_deadline);
            end
        end
        #5;
        if (aresetn && identity_armed) begin
            cont_samples++;
            if (eff_tx_arm !== sw_tx_arm || eff_deadline !== sw_deadline) begin
                cont_breaks++;
                $display("FAIL: OFF-state identity broken post-stimulus at t=%0t (arm %0b/%0b dl %0h/%0h)",
                         $time, eff_tx_arm, sw_tx_arm, eff_deadline, sw_deadline);
            end
        end
    end

    // ---- check 1b: divergence counter, proves check 1 is not vacuous -------------
    bit divergence_armed = 0;
    int divergence_hits  = 0;
    always_ff @(posedge aclk) begin
        if (aresetn && divergence_armed) begin
            if (eff_deadline !== sw_deadline) divergence_hits++;
        end
    end

    logic [31:0] t_open_x, t_fire_x, t_close_x, base;

    // check 15c scratch (64-bit: 2^31 * 100 overflows 32 bits)
    longint hr_bare, hr_deployed, hr_horizon;
    // check 14 marks — the identity counters are cumulative, so the post-ON window is
    // scored as a DELTA. Without the marks a clean check 1 would mask a broken check 14.
    int id_mark_s, id_mark_b, id_mark_c, id_mark_d;

    initial begin
        aresetn = 0; samp_ctr = 32'd0; sw_tx_arm = 0; sw_deadline = 32'hA5A5_0000;
        sched_enable = 0; origin = 0; arm_off = 0; fire_off = 0; load_strobe = 0;
        repeat (4) @(posedge aclk);
        aresetn = 1; repeat (2) @(posedge aclk);

        // =====================================================================
        // 1. OFF-STATE IDENTITY. CONTROL[15]=0. Load a perfectly VALID schedule and
        //    drive arm/deadline traffic: nothing may reach the outputs.
        // =====================================================================
        set_ctr(32'd1_000_000);
        identity_armed = 1;
        do_load(32'd500_000, 32'd0, T4_TICKS);           // valid, and accepted (loaded_q=1)
        check(sched_loaded == 1'b1, "1: a valid load is accepted even with CONTROL[15]=0");
        // Drive the full traffic shape a real epoch produces: arm toggles, 0x6C rewrites,
        // ruler jumps across t_open / t_fire / t_close, and idle cycles in between.
        for (int k = 0; k < 3; k++) begin
            @(negedge aclk); sw_tx_arm = 1;  @(posedge aclk);
            set_ctr(32'd2_000_000);
            repeat (2) @(posedge aclk);
            @(negedge aclk); sw_deadline = 32'd15_668_000; @(posedge aclk);
            set_ctr(32'd15_668_000);                       // == the fabric t_fire
            repeat (2) @(posedge aclk);
            set_ctr(32'd15_668_000 + WIN_TAIL);            // == the fabric t_close
            repeat (2) @(posedge aclk);
            @(negedge aclk); sw_tx_arm = 0;  @(posedge aclk);
            @(negedge aclk); sw_deadline = 32'hA5A5_0000; @(posedge aclk);
            set_ctr(32'd1_000_000);
            repeat (2) @(posedge aclk);
        end
        repeat (4) @(posedge aclk);
        identity_armed = 0;
        check(identity_samples > 40,
              $sformatf("1: identity window must actually sample (n=%0d)", identity_samples));
        check(identity_breaks == 0,
              $sformatf("1: OFF-state must be byte-identical to legacy (%0d/%0d cycles differed)",
                        identity_breaks, identity_samples));
        check(cont_samples >= 2 * identity_samples - 4,
              $sformatf("1: the off-edge witness must sample both phases (%0d vs %0d posedges)",
                        cont_samples, identity_samples));
        check(cont_breaks == 0,
              $sformatf("1: OFF-state identity must hold OFF the clock edges too (%0d/%0d)",
                        cont_breaks, cont_samples));

        // =====================================================================
        // 1b. NON-VACUITY. Same shape of stimulus with CONTROL[15]=1 MUST diverge.
        // =====================================================================
        @(negedge aclk); sw_tx_arm = 0; sched_enable = 1; @(posedge aclk);
        set_ctr(32'd1_000_000);
        do_load(32'd500_000, 32'd0, T4_TICKS);
        divergence_armed = 1;
        repeat (6) @(posedge aclk);
        divergence_armed = 0;
        check(divergence_hits > 0,
              "1b: with CONTROL[15]=1 the deadline MUST diverge from 0x6C (else check 1 is vacuous)");

        // =====================================================================
        // 2. Load accepted while disarmed; deadline substitution exact at T4 scale.
        // =====================================================================
        base     = 32'd1_000_000;
        t_open_x = 32'd500_000 + 32'd0;
        t_fire_x = 32'd500_000 + T4_TICKS;
        t_close_x= t_fire_x + WIN_TAIL;
        check(sched_loaded == 1'b1, "2: schedule loaded");
        check(sched_reject == 1'b0, "2: reject clear after an accepted load");
        check(eff_deadline == t_fire_x,
              $sformatf("2: eff_deadline=%0d expected ORIGIN+FIRE_OFF=%0d", eff_deadline, t_fire_x));
        check(sched_win_open == 1'b1, "2: ARM_OFF=0 with a past ORIGIN opens the window at load");

        // 4. eff_tx_arm follows sw & win.
        check(eff_tx_arm == 1'b0, "4: arm low while CONTROL[5] low");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b1, "4: arm high with CONTROL[5] high inside the window");

        // 5. Window closes at t_fire + WIN_TAIL, not before.
        set_ctr(t_fire_x);
        check(sched_win_open == 1'b1, "5: window still open AT the fire deadline");
        check(eff_tx_arm == 1'b1, "5: arm still high AT the fire deadline");
        set_ctr(t_close_x - 32'd1);
        check(sched_win_open == 1'b1, "5: window open one tick before close");
        set_ctr(t_close_x);
        check(sched_win_open == 1'b0, "5: window closed at t_fire + WIN_TAIL_TICKS");
        check(eff_tx_arm == 1'b0, "5: fabric disarm at window close (CONTROL[5] still high)");
        // 1c. The ARM half of check 1's non-vacuity, asserted at the one instant where the
        // two must differ: CONTROL[5] high, window shut, CONTROL[15]=1. Without this line
        // a mutant that hard-wires eff_tx_arm = sw_tx_arm passes check 1 AND check 1b
        // (1b only watches the deadline), and the OFF-state arm claim would be untested.
        check(sw_tx_arm == 1'b1, "1c: fixture - CONTROL[5] must be high here");
        check(eff_tx_arm !== sw_tx_arm,
              "1c: with CONTROL[15]=1 the ARM must be able to differ from CONTROL[5]");

        // 11. Release requires CONTROL[5] low.
        repeat (4) @(posedge aclk);
        check(sched_loaded == 1'b1, "11: no release while CONTROL[5] is still high");
        check(eff_deadline == t_fire_x, "11: still on the fabric deadline while armed");
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "11: released once CONTROL[5] drops");
        check(eff_deadline == sw_deadline, "11: legacy deadline restored after release");

        // =====================================================================
        // 3. Delayed-arm mode: the window opens AT t_open, not one tick early.
        // =====================================================================
        set_ctr(32'd20_000_000);
        do_load(32'd20_000_000, 32'd1_000_000, T4_TICKS);
        t_open_x  = 32'd20_000_000 + 32'd1_000_000;
        t_fire_x  = 32'd20_000_000 + T4_TICKS;
        t_close_x = t_fire_x + WIN_TAIL;
        check(sched_loaded == 1'b1, "3: delayed-arm schedule loaded");
        check(sched_win_open == 1'b0, "3: window shut before t_open");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b0, "3: CONTROL[5] alone does not arm before t_open");
        set_ctr(t_open_x - 32'd1);
        check(sched_win_open == 1'b0, "3: still shut one tick before t_open");
        check(eff_tx_arm == 1'b0, "3: still disarmed one tick before t_open");
        set_ctr(t_open_x);
        check(sched_win_open == 1'b1, "3: window opens exactly at t_open");
        check(eff_tx_arm == 1'b1, "3: fabric raises the arm at t_open");
        check(eff_deadline == t_fire_x, "3: fabric deadline held across the window");
        set_ctr(t_close_x);
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "3: released after close + disarm");

        // =====================================================================
        // 7. Refusal: deadline already past (t_fire == samp_ctr is NOT future).
        // =====================================================================
        set_ctr(32'd50_000_000);
        do_load(32'd50_000_000 - T4_TICKS, 32'd0, T4_TICKS);   // t_fire == samp_ctr
        check(sched_loaded == 1'b0, "7: a non-future deadline is REFUSED");
        check(sched_reject == 1'b1, "7: refusal is flagged");
        check(eff_deadline == sw_deadline, "7: refused load leaves the legacy deadline in place");

        // =====================================================================
        // 8. Refusal: beyond MAX_HORIZON_TICKS.
        // =====================================================================
        do_load(32'd50_000_000, 32'd0, MAX_HORIZON + 32'd1);
        check(sched_loaded == 1'b0, "8: a program-ahead past MAX_HORIZON_TICKS is REFUSED");
        check(sched_reject == 1'b1, "8: horizon refusal is flagged");
        // ... and exactly AT the horizon is accepted (the boundary is not off by one).
        do_load(32'd50_000_000, 32'd0, MAX_HORIZON);
        check(sched_loaded == 1'b1, "8: a program-ahead exactly AT MAX_HORIZON_TICKS is accepted");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        set_ctr(32'd50_000_000 + MAX_HORIZON + WIN_TAIL);
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "8: horizon-boundary schedule released after its window");

        // =====================================================================
        // 9. Refusal: ARM_OFF > FIRE_OFF.
        // =====================================================================
        set_ctr(32'd60_000_000);
        do_load(32'd60_000_000, T4_TICKS + 32'd1, T4_TICKS);
        check(sched_loaded == 1'b0, "9: ARM_OFF > FIRE_OFF is REFUSED (window could never open)");
        check(sched_reject == 1'b1, "9: geometry refusal is flagged");

        // =====================================================================
        // 10. Refusal: load attempted while CONTROL[5] is high. The PREVIOUS schedule
        //     must survive untouched — clearing it here would move the mux while armed.
        // =====================================================================
        set_ctr(32'd70_000_000);
        do_load(32'd70_000_000, 32'd0, T4_TICKS);              // good schedule, disarmed
        t_fire_x = 32'd70_000_000 + T4_TICKS;
        check(sched_loaded == 1'b1, "10: setup schedule accepted");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        do_load(32'd70_000_000, 32'd0, T4_TICKS / 2);          // illegal: written while armed
        check(sched_loaded == 1'b1, "10: a load while armed does not clear the live schedule");
        check(eff_deadline == t_fire_x,
              $sformatf("10: live deadline unchanged by an armed-time load (got %0d expected %0d)",
                        eff_deadline, t_fire_x));
        check(sched_reject == 1'b1, "10: armed-time load is flagged as refused");
        set_ctr(t_fire_x + WIN_TAIL);
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "10: released after close + disarm");

        // =====================================================================
        // 12. 2^32 WRAP. ORIGIN chosen so ORIGIN + T4 wraps the ruler.
        // =====================================================================
        base = 32'hFFFF_F000;
        set_ctr(base);
        do_load(32'hFFFF_E000, 32'd0, T4_TICKS);
        t_fire_x  = 32'hFFFF_E000 + T4_TICKS;     // wraps by construction
        t_close_x = t_fire_x + WIN_TAIL;
        check(t_fire_x < base, "12: the fixture must actually wrap (t_fire < samp_ctr numerically)");
        check(sched_loaded == 1'b1, "12: a wrapped-but-future deadline is accepted");
        check(eff_deadline == t_fire_x, "12: wrapped deadline value is exact");
        check(sched_win_open == 1'b1, "12: window open (ORIGIN is in the past across the wrap)");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b1, "12: armed across the wrap");
        set_ctr(32'd0);                            // ruler has wrapped past zero
        check(sched_win_open == 1'b1, "12: still open after the ruler wraps through 0");
        set_ctr(t_close_x - 32'd1);
        check(sched_win_open == 1'b1, "12: open one tick before the wrapped close");
        set_ctr(t_close_x);
        check(sched_win_open == 1'b0, "12: closes correctly on the far side of the wrap");
        check(eff_tx_arm == 1'b0, "12: fabric disarm on the far side of the wrap");
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);

        // =====================================================================
        // 13. THE DEPLOYED T4 MAGNITUDE. Every fixture above runs at the bare-flavour
        //     15,168,000; what actually ships is 19,200,000 (defect #90). Prove the
        //     shipping magnitude loads, substitutes exactly, and closes on schedule —
        //     and that it is still comfortably inside MAX_HORIZON.
        // =====================================================================
        set_ctr(32'd80_000_000);
        do_load(32'd80_000_000, 32'd0, T4_DEPLOYED);
        t_fire_x  = 32'd80_000_000 + T4_DEPLOYED;
        t_close_x = t_fire_x + WIN_TAIL;
        check(sched_loaded == 1'b1, "13: the DEPLOYED T4 (19,200,000 ticks) is accepted");
        check(eff_deadline == t_fire_x, "13: deployed-T4 deadline substitution is exact");
        check(T4_DEPLOYED <= MAX_HORIZON, "13: the deployed T4 is inside MAX_HORIZON_TICKS");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b1, "13: armed inside the deployed-T4 window");
        set_ctr(t_close_x);
        check(sched_win_open == 1'b0, "13: deployed-T4 window closes at t_fire + WIN_TAIL");
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "13: released after close + disarm");

        // =====================================================================
        // 14. OFF-STATE IDENTITY *AFTER* AN ON PHASE — the round-1 A/B property.
        //     Check 1 proves identity on a module whose sched_en_q has never been 1 and
        //     which has never driven a window. But the frm's whole attribution argument is
        //     ALTERNATE-EPOCH A/B (FRM_REGISTER_MAP §6.2 / plan decision 5): OFF epochs
        //     interleaved with ON epochs on the same powered-up part. So the OFF state
        //     that matters is the one reached by coming BACK from ON, with state bits and
        //     latched targets carrying whatever the ON epoch left behind. That is this
        //     check, and nothing else in the TB covered it.
        // =====================================================================
        id_mark_s = identity_samples; id_mark_b = identity_breaks;
        id_mark_c = cont_samples;     id_mark_d = cont_breaks;

        @(negedge aclk); sched_enable = 1'b0; @(posedge aclk);   // CONTROL[15] -> 0, disarmed
        repeat (2) @(posedge aclk);                              // sched_en_q clears
        set_ctr(32'd90_000_000);
        do_load(32'd90_000_000, 32'd0, T4_DEPLOYED);             // a schedule IS loaded...
        check(sched_loaded == 1'b1, "14: a load is still ACCEPTED with CONTROL[15]=0");
        t_fire_x  = 32'd90_000_000 + T4_DEPLOYED;
        t_close_x = t_fire_x + WIN_TAIL;

        identity_armed = 1;
        // Same traffic shape as check 1, but walked across THIS schedule's landmarks, so
        // every instant at which the ON path would have diverged is visited while OFF.
        for (int k = 0; k < 3; k++) begin
            @(negedge aclk); sw_tx_arm = 1;  @(posedge aclk);
            @(negedge aclk); sw_deadline = 32'd5_555_5555; @(posedge aclk);
            set_ctr(32'd90_000_000);                 // fabric t_open (ARM_OFF = 0)
            repeat (2) @(posedge aclk);
            set_ctr(t_fire_x);                       // fabric t_fire
            repeat (2) @(posedge aclk);
            set_ctr(t_close_x);                      // fabric t_close
            repeat (2) @(posedge aclk);
            @(negedge aclk); sw_tx_arm = 0;  @(posedge aclk);
            @(negedge aclk); sw_deadline = 32'hA5A5_0000; @(posedge aclk);
            repeat (2) @(posedge aclk);
        end
        repeat (4) @(posedge aclk);
        identity_armed = 0;
        check((identity_samples - id_mark_s) > 40,
              $sformatf("14: the post-ON identity window must actually sample (n=%0d)",
                        identity_samples - id_mark_s));
        check((identity_breaks - id_mark_b) == 0,
              $sformatf("14: OFF-after-ON must be byte-identical too (%0d/%0d cycles differed)",
                        identity_breaks - id_mark_b, identity_samples - id_mark_s));
        check((cont_breaks - id_mark_d) == 0,
              $sformatf("14: OFF-after-ON identity must hold off-edge too (%0d/%0d)",
                        cont_breaks - id_mark_d, cont_samples - id_mark_c));

        // =====================================================================
        // 15. THE DEPLOYED T4, FULL LIFECYCLE, AND THE 32-BIT WIDTH ARGUMENT.
        //     Check 13 only proved that the deployed magnitude LOADS and substitutes.
        //     Every window-geometry fixture (3, 5, 12) ran at the BARE 15,168,000, i.e. at
        //     a magnitude the shipped firmware does not use. 15a/15b re-run the delayed-arm
        //     and the wrap at 19,200,000; 15c states the headroom as computed arithmetic;
        //     15d proves the horizon guard is what keeps the signed compare unambiguous.
        // =====================================================================
        @(negedge aclk); sched_enable = 1'b1; @(posedge aclk);
        repeat (2) @(posedge aclk);

        // --- 15a: delayed-arm window at the DEPLOYED T4 -------------------------------
        set_ctr(32'd100_000_000);
        do_load(32'd100_000_000, ARM_LEAD, T4_DEPLOYED);
        t_open_x  = 32'd100_000_000 + ARM_LEAD;
        t_fire_x  = 32'd100_000_000 + T4_DEPLOYED;
        t_close_x = t_fire_x + WIN_TAIL;
        check(sched_loaded == 1'b1, "15a: deployed-T4 delayed-arm schedule loaded");
        check(sched_win_open == 1'b0, "15a: shut before t_open at the deployed magnitude");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b0, "15a: CONTROL[5] alone does not arm before t_open");
        set_ctr(t_open_x - 32'd1);
        check(sched_win_open == 1'b0, "15a: still shut one tick before t_open");
        set_ctr(t_open_x);
        check(sched_win_open == 1'b1, "15a: opens exactly at t_open (deployed magnitude)");
        check(eff_tx_arm == 1'b1, "15a: fabric raises the arm at t_open");
        check(eff_deadline == t_fire_x, "15a: deadline exact across a 19,200,000-tick span");
        set_ctr(t_close_x - 32'd1);
        check(sched_win_open == 1'b1, "15a: open one tick before the deployed close");
        set_ctr(t_close_x);
        check(sched_win_open == 1'b0, "15a: closes at t_fire + WIN_TAIL, deployed magnitude");
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "15a: released after close + disarm");

        // --- 15b: 2^32 wrap AT the deployed magnitude (check 12 wrapped only the bare) --
        base = 32'hFFF0_0000;
        set_ctr(base);
        do_load(32'hFFE0_0000, 32'd0, T4_DEPLOYED);
        t_fire_x  = 32'hFFE0_0000 + T4_DEPLOYED;      // wraps by construction
        t_close_x = t_fire_x + WIN_TAIL;
        check(t_fire_x < base, "15b: the deployed-magnitude fixture must actually wrap");
        check(sched_loaded == 1'b1, "15b: wrapped deployed-T4 deadline accepted");
        check(eff_deadline == t_fire_x, "15b: wrapped deployed-T4 deadline value exact");
        check(sched_win_open == 1'b1, "15b: open (ORIGIN in the past across the wrap)");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b1, "15b: armed across the wrap at the deployed magnitude");
        set_ctr(32'd0);
        check(sched_win_open == 1'b1, "15b: still open after the ruler wraps through 0");
        set_ctr(t_close_x - 32'd1);
        check(sched_win_open == 1'b1, "15b: open one tick before the wrapped close");
        set_ctr(t_close_x);
        check(sched_win_open == 1'b0, "15b: closes on the far side of the wrap");
        check(eff_tx_arm == 1'b0, "15b: fabric disarm on the far side of the wrap");
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);

        // --- 15c: the headroom, COMPUTED, not narrated --------------------------------
        // Every instant compare in the DUT is $signed(a - b), so the usable range is 2^31,
        // not 2^32. These are the same ratios tx_window_sched.sv:51-53 and
        // test_fabric_sched_contract.c state in prose; printing them from the same integers
        // the fixtures use is what stops a stale comment (#105's defect class).
        hr_bare     = (SIGNED_SPAN * 100) / longint'(T4_TICKS);
        hr_deployed = (SIGNED_SPAN * 100) / longint'(T4_DEPLOYED);
        hr_horizon  = (SIGNED_SPAN * 100) / longint'(MAX_HORIZON);
        $display("TXWIN_HEADROOM_BARE_T4_X100=%0d", hr_bare);
        $display("TXWIN_HEADROOM_DEPLOYED_T4_X100=%0d", hr_deployed);
        $display("TXWIN_HEADROOM_MAX_HORIZON_X100=%0d", hr_horizon);
        check(hr_bare     >= 14000, "15c: bare-T4 signed headroom must be >= 140x");
        check(hr_deployed >= 11000, "15c: DEPLOYED-T4 signed headroom must be >= 110x");
        check(hr_horizon  >=  4000, "15c: worst-case (MAX_HORIZON) headroom must be >= 40x");
        check(T4_DEPLOYED > T4_TICKS,
              "15c: fixture - the deployed T4 must be the LARGER of the two flavours");
        check(hr_deployed < hr_bare,
              "15c: the BINDING headroom is the deployed one, not the bare 141.6x");

        // --- 15d: the sign-inversion falsifier ----------------------------------------
        // A program-ahead of exactly 2^31 makes $signed(t_fire - samp_ctr) NEGATIVE. The
        // module must REFUSE it (load_future goes false), never accept it as "past" and
        // never schedule it. This is the property that makes 32 bits sufficient: not that
        // the numbers fit, but that everything outside the unambiguous half-range is
        // rejected at the door.
        set_ctr(32'd120_000_000);
        check(sched_loaded == 1'b0, "15d: fixture - no schedule loaded before the falsifier");
        do_load(32'd120_000_000, 32'd0, 32'h8000_0000);
        check(sched_loaded == 1'b0, "15d: a 2^31 program-ahead is REFUSED, not mis-scheduled");
        check(sched_reject == 1'b1, "15d: the sign-inverted request is flagged");
        do_load(32'd120_000_000, 32'd0, 32'hFFFF_0000);
        check(sched_loaded == 1'b0, "15d: a near-2^32 program-ahead is REFUSED too");
        check(sched_reject == 1'b1, "15d: the near-wrap request is flagged");
        // MEASURED by mutation, and the reason this third case exists: with ARM_OFF = 0 the
        // two cases above are refused by load_sane (d_open_to_fire goes negative), NOT by
        // load_future -- a mutant that de-signs the future test survives them both. Setting
        // ARM_OFF == FIRE_OFF makes d_open_to_fire exactly 0, so load_sane CANNOT refuse and
        // the signed-future guard is the only thing left standing between a 2^31 request and
        // a schedule that would read as already-past.
        do_load(32'd120_000_000, 32'h8000_0000, 32'h8000_0000);
        check(sched_loaded == 1'b0,
              "15d: 2^31 ahead is refused by the SIGNED-future guard even when ARM_OFF==FIRE_OFF");
        check(sched_reject == 1'b1, "15d: the isolated sign-inversion request is flagged");
        // The primary guard is the horizon, not the sign: one tick below 2^31 is a legal
        // signed distance and must still be refused, by load_near.
        do_load(32'd120_000_000, 32'h7FFF_FFFF, 32'h7FFF_FFFF);
        check(sched_loaded == 1'b0, "15d: (2^31 - 1) ahead is refused by MAX_HORIZON_TICKS");
        check(sched_reject == 1'b1, "15d: the horizon-guard request is flagged");

        // =====================================================================
        // 17. AN ACCEPTED LOAD CLEARS THE STICKY REJECT.
        //     Check 2 asserts reject==0 after an accept, but no refusal precedes it there,
        //     so it cannot fail. Here reject_q is KNOWN 1 (15d just set it), which makes
        //     the assertion real. fpga_dsp_sched_program()'s verdict is exactly
        //     {STATUS[16]=1, STATUS[18]=0}, so a reject that never cleared would report
        //     every accepted load as -ERANGE.
        // =====================================================================
        do_load(32'd120_000_000, 32'd0, T4_DEPLOYED);
        check(sched_loaded == 1'b1, "17: the recovery load is accepted");
        check(sched_reject == 1'b0, "17: an ACCEPTED load clears the sticky reject");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        set_ctr(32'd120_000_000 + T4_DEPLOYED + WIN_TAIL);
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "17: released after close + disarm");

        // =====================================================================
        // 16. 🔴 THE FAIL-SAFE PROBE. EXPECTED TO FIRE — read the header note.
        //
        // The RTL header's "FAIL-SAFE DIRECTION" section claimed, and
        // FRM_REGISTER_MAP_2026-07-28 §6.2 repeats as a safety argument: "If firmware
        // never lowers CONTROL[5] ... loaded_q is never released and, past t_close,
        // eff_tx_arm stays LOW: TX goes QUIET."  [It was FALSE as written — this probe is
        // what caught it. The expiry latch now makes it TRUE; the frm manifest text must
        // be re-checked against this section, not against the old wording.]
        //
        // The premise is real. MEASURED in firmware: there is NO standalone disarm anywhere
        // — CTRL_TX_ARM is cleared only inside the clear-then-set of the NEXT arm
        // (fpga_dsp_arm_tx_at, fpga_dsp.c:705-707; fpga_dsp_arm_tx_at_gated, :719-721), and
        // gated_tx.c:246 records "a timed-out arm leaves tx_dma_gate ARMED (no RTL disarm)".
        // So a node that stops arming — end of round, lost beacon, aborted epoch — sits with
        // CONTROL[5] HIGH and loaded_q SET indefinitely.
        //
        // But the conclusion holds for exactly ONE lap of the ruler. samp_ctr is 32-bit and
        // free-running ("wraps at 2^32 ~= 37 min @ 1.92 MS/s", route_b_sync.sv:51), and
        // at_open/at_close are SIGNED-WRAP compares against LATCHED targets, so 2^32 ticks
        // after t_open the DUT re-evaluates the SAME schedule as freshly-open.
        //
        // Jamming samp_ctr is a faithful model of that lap and not a shortcut: the only
        // state that could have changed in the intervening 2237 s is loaded_q, whose sole
        // release term is (win_done & ~sw_tx_arm) — and sw_tx_arm is held HIGH throughout
        // by the hypothesis under test. The landmarks below walk the whole lap so the flip
        // point is visible, not asserted.
        // =====================================================================
        @(negedge aclk); sched_enable = 1'b1; @(posedge aclk);
        set_ctr(LAP_BASE);
        do_load(LAP_BASE, 32'd0, T4_DEPLOYED);
        t_open_x  = LAP_BASE;
        t_fire_x  = LAP_BASE + T4_DEPLOYED;
        t_close_x = t_fire_x + WIN_TAIL;
        check(sched_loaded == 1'b1, "16: fixture - lap-probe schedule loaded");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);   // ...and NEVER lowered below
        check(eff_tx_arm == 1'b1, "16: fixture - armed inside the window");

        set_ctr(t_close_x);                                  // the claimed QUIET state
        check(sched_win_open == 1'b0, "16: window shut at t_close");
        check(eff_tx_arm == 1'b0, "16: TX quiet at t_close with CONTROL[5] still high");
        check(sched_loaded == 1'b1, "16: NOT released - CONTROL[5] never fell (the premise)");

        set_ctr(t_open_x + 32'h8000_0000);                   // +2^31: at_open inverts
        check(sched_win_open == 1'b0, "16: still shut half a lap after t_open");
        check(eff_tx_arm == 1'b0, "16: still quiet half a lap after t_open");

        set_ctr(t_close_x + 32'h8000_0000);                  // at_close inverts too
        check(sched_win_open == 1'b0,
              "16: still shut once ~at_close flips (only at_open holds the window down)");

        set_ctr(LAP_BASE - 32'd1);                           // one tick short of a full lap
        check(sched_win_open == 1'b0, "16: still shut one tick before the ruler completes a lap");
        check(eff_tx_arm == 1'b0, "16: still quiet one tick before the lap completes");

        set_ctr(LAP_BASE);                                   // FULL 2^32 LAP — same value again
        $display("16: at the lap boundary - win_open=%0b eff_tx_arm=%0b eff_deadline=%0d (t_fire=%0d)",
                 sched_win_open, eff_tx_arm, eff_deadline, t_fire_x);
        finding(sched_win_open == 1'b0,
                "16: the window RE-OPENS 2^32 ticks (2237 s) after t_open on the same stale schedule");
        finding(eff_tx_arm == 1'b0,
                "16: FAIL-SAFE CLAIM FALSE (tx_window_sched.sv FAIL-SAFE DIRECTION) - eff_tx_arm rises again one ruler lap later; route_b_sync arms on that rise (route_b_sync.sv:109) against t_fire_q, which reads FUTURE again, so TX is not quiet, it is 37-minute-periodic");

        // =====================================================================
        // 18. THE REGRESSION GUARD for the expiry latch (`expired_q`).
        //
        //     Check 16 is a FINDING — it scores a claim the RTL header and the frm
        //     manifest make. Findings are deliberately kept out of `fails`, which means a
        //     future edit that DELETED the fix would restore the defect while the contract
        //     verdict stayed green. These are hard `check()`s so that cannot happen
        //     silently: they score the MECHANISM, at the two instants that actually put RF
        //     on air (the window re-open, and the second-lap t_fire that route_b_sync
        //     compares against).
        //
        //     Continuation of check 16's fixture and its hypothesis: sw_tx_arm has been
        //     HIGH since the load and is still high here (there is no standalone disarm in
        //     firmware — fpga_dsp.c:717-718, :731-732), samp_ctr has just completed a full
        //     2^32 lap back to LAP_BASE, and loaded_q is still SET.
        // =====================================================================
        check(sched_win_open == 1'b0,
              "18a: EXPIRY LATCH - the window must stay SHUT across a full 2^32 ruler lap on a stale schedule");
        check(eff_tx_arm == 1'b0,
              "18a: EXPIRY LATCH - eff_tx_arm must stay LOW across the lap (a rise here is an UNSCHEDULED T4 BURST ON AIR)");
        check(sched_loaded == 1'b1,
              "18a: fixture - loaded_q is still SET (CONTROL[5] never fell); the expiry is the WINDOW, not the load");

        // 18b: walk the second lap to the two instants that fire RF. t_fire_x is where
        // route_b_sync's comparator crosses tx_deadline; t_close_x is a full window later.
        set_ctr(t_fire_x);
        check(sched_win_open == 1'b0, "18b: still shut at the SECOND-lap t_fire instant");
        check(eff_tx_arm   == 1'b0,   "18b: still quiet at the SECOND-lap t_fire instant");
        set_ctr(t_close_x);
        check(sched_win_open == 1'b0, "18b: still shut at the second-lap t_close");
        check(eff_tx_arm   == 1'b0,   "18b: still quiet at the second-lap t_close");

        // 18c: NON-VACUITY. An expiry that could NEVER clear would satisfy 18a/18b
        // trivially and brick the scheduler for the rest of the power-up. The latch must
        // release on the next ACCEPTED load — and only on that.
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "18c: released once CONTROL[5] finally drops at a closed window");
        set_ctr(32'd130_000_000);
        do_load(32'd130_000_000, 32'd0, T4_DEPLOYED);
        check(sched_loaded == 1'b1, "18c: a fresh load AFTER an expiry is accepted");
        check(sched_win_open == 1'b1,
              "18c: the expiry latch CLEARS on an accepted load (else the fix bricks the scheduler)");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b1, "18c: the fabric arms again on the fresh schedule");
        check(eff_deadline == 32'd130_000_000 + T4_DEPLOYED,
              "18c: and substitutes the fresh deadline exactly");
        set_ctr(32'd130_000_000 + T4_DEPLOYED + WIN_TAIL);
        check(sched_win_open == 1'b0, "18c: the fresh window closes normally at t_fire + WIN_TAIL");
        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        check(sched_loaded == 1'b0, "18c: released after close + disarm");

        // 18d: THE PRIORITY CASE the expiry latch introduces, and the only way this fix
        // could brick a live round. A fresh load can land on the SAME clock edge a stale
        // window expires (win_done uses the OLD loaded_q and the OLD targets). If
        // `else if (win_done)` were ordered ahead of `else if (load_ok)` in the expired_q
        // block, the new schedule would be accepted and born EXPIRED — loaded=1,
        // reject=0, and a window that never opens. Firmware would read the accept verdict
        // {STATUS[16]=1, STATUS[18]=0} and wait forever for a burst that cannot fire.
        // This does NOT fire on the pre-fix RTL (there is no latch to mis-order); it
        // guards the FIX, which is why it is separate from 18a/18b.
        @(negedge aclk); sched_enable = 1'b1; @(posedge aclk); @(posedge aclk);
        set_ctr(32'd140_000_000);
        do_load(32'd140_000_000, 32'd0, T4_DEPLOYED);
        check(sched_loaded == 1'b1, "18d: fixture - stale schedule loaded");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);          // armed: blocks the release
        set_ctr(32'd140_000_000 + T4_DEPLOYED + WIN_TAIL);        // win_done, but no release
        check(sched_loaded   == 1'b1, "18d: fixture - stale schedule still loaded at its close (armed)");
        check(sched_win_open == 1'b0, "18d: fixture - the stale window is shut/expired");
        // One negedge presents BOTH the disarm and the new load, so the posedge that
        // follows evaluates win_done=1 and load_ok=1 simultaneously.
        @(negedge aclk);
        sw_tx_arm   = 1'b0;
        origin      = 32'd150_000_000; arm_off = 32'd0; fire_off = T4_DEPLOYED;
        load_strobe = 1'b1;
        @(posedge aclk);
        @(negedge aclk); load_strobe = 1'b0; @(posedge aclk);
        check(sched_loaded == 1'b1, "18d: the coincident load is ACCEPTED");
        check(sched_reject == 1'b0, "18d: ...and is not flagged as refused");
        check(sched_win_open == 1'b1,
              "18d: ...and is NOT born expired - load_ok must beat win_done in the expiry latch");
        check(eff_deadline == 32'd150_000_000 + T4_DEPLOYED,
              "18d: the coincident load's deadline substitutes exactly");
        @(negedge aclk); sw_tx_arm = 1; @(posedge aclk);
        check(eff_tx_arm == 1'b1, "18d: the coincident schedule arms on air");
        set_ctr(32'd150_000_000 + T4_DEPLOYED + WIN_TAIL);
        check(sched_win_open == 1'b0, "18d: coincident-load window closes on schedule");

        @(negedge aclk); sw_tx_arm = 0; @(posedge aclk); @(posedge aclk);
        @(negedge aclk); sched_enable = 1'b0; @(posedge aclk);

        // ---- check 6 verdict ----
        check(manufactured_edges == 0,
              $sformatf("6: SAFETY THEOREM violated - %0d manufactured arm edges", manufactured_edges));

        $display("TXWIN_OFF_IDENTITY=%0d/%0d posedge, %0d/%0d off-edge (breaks/samples)",
                 identity_breaks, identity_samples, cont_breaks, cont_samples);
        $display("TXWIN_CHECKS_RUN=%0d", checks_run);
        if (fails == 0 && findings == 0) $display("tb_tx_window_sched OK");
        else begin
            if (fails    != 0) $display("tb_tx_window_sched FAILED: %0d checks", fails);
            if (findings != 0) $display("tb_tx_window_sched FINDINGS: %0d (contract fails=%0d)",
                                        findings, fails);
        end
        $finish;
    end

    initial begin #200000; $display("FAIL: tb_tx_window_sched timeout"); $finish; end
endmodule
