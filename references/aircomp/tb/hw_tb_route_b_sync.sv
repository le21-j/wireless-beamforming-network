`timescale 1ns/1ps
// tb_route_b_sync.sv — fail-first unit test for the Route-B deterministic-ACK logic
// (hdl/rtl/route_b_sync.sv). Checks the three building blocks:
//   1. samp_ctr increments once per rx_adc_tvalid beat.
//   2. beacon_ts latches samp_ctr at ts_trigger, sticky-valid, clears on read-strobe.
//   3. fpga_tx_fire pulses (and tx_fired latches) when samp_ctr reaches a programmed
//      tx_deadline after tx_arm rises; tx_fired clears on the W1C ack.
// Plus lever#2 (v19): the per-arm opt-in buffer gate (CONTROL[8]=arm_needs_buffer):
//   5. DEFECT-1 legacy bare-arm (needs_buffer=0, buf=0) STILL fires (v17 preserved).
//   6. coherent pend-then-fire (needs_buffer=1, buf rises BEFORE deadline) fires once.
//   7. DEFECT-2 late-abstain (needs_buffer=1, buf rises AFTER deadline) emits nothing.
//   8. compat (needs_buffer=1, buf high at the arm edge) fires like v17.
// Prints "tb_route_b_sync OK" and $finish on success; lists failures otherwise.
// Capstone timing adaptation: drive stimulus on falling edges and check after
// rising-edge nonblocking updates. The original assertions and RTL are unchanged.

module tb_route_b_sync;
    logic        aclk = 0;
    logic        aresetn;
    logic        rx_adc_tvalid;
    logic        ts_trigger;
    logic [31:0] ts_value;
    logic        tx_arm;
    logic        arm_needs_buffer;
    logic        dma_buf_ready;
    logic [31:0] tx_deadline;
    logic        beacon_ts_rd_strobe;
    logic        tx_fire_ack_strobe;
    wire [31:0]  samp_ctr, beacon_ts;
    wire         beacon_ts_valid, fpga_tx_fire, tx_fired;

    int fails = 0;

    route_b_sync dut (
        .aclk(aclk), .aresetn(aresetn),
        .rx_adc_tvalid(rx_adc_tvalid),
        .ts_trigger(ts_trigger),
        .ts_value(ts_value),
        .tx_arm(tx_arm),
        .arm_needs_buffer(arm_needs_buffer),
        .dma_buf_ready(dma_buf_ready),
        .tx_deadline(tx_deadline),
        .beacon_ts_rd_strobe(beacon_ts_rd_strobe),
        .tx_fire_ack_strobe(tx_fire_ack_strobe),
        .samp_ctr(samp_ctr), .beacon_ts(beacon_ts),
        .beacon_ts_valid(beacon_ts_valid),
        .fpga_tx_fire(fpga_tx_fire), .tx_fired(tx_fired)
    );

    always #5 aclk = ~aclk;

    task automatic wait_n(int n);
        repeat (n) @(posedge aclk);
        #1; // Let the DUT and fire monitor finish their nonblocking updates.
    endtask

    task automatic check(bit cond, string msg);
        if (!cond) begin $display("FAIL: %s", msg); fails++; end
    endtask

    logic [31:0] ts_at_trigger, ctr_at_fire;
    int          fire_count;

    // Count fires and remember the counter value when one occurs.
    always @(posedge aclk) if (aresetn && fpga_tx_fire) begin
        fire_count  <= fire_count + 1;
        ctr_at_fire <= samp_ctr;
    end

    initial begin
        aresetn = 0; rx_adc_tvalid = 0; ts_trigger = 0; ts_value = 0; tx_arm = 0;
        arm_needs_buffer = 0;  // checks 1-4 are the LEGACY bare-arm (opt-in OFF) => v17-identical
        dma_buf_ready = 1;     // legacy ignores this; held HIGH so even an accidental read is benign
        tx_deadline = 0; beacon_ts_rd_strobe = 0; tx_fire_ack_strobe = 0;
        fire_count = 0; ts_at_trigger = 0; ctr_at_fire = 0;
        wait_n(4); @(negedge aclk); aresetn = 1; wait_n(2);

        // --- 1. sample counter ---
        check(samp_ctr == 0, "samp_ctr should be 0 before any rx_adc_tvalid");
        @(negedge aclk);
        rx_adc_tvalid = 1;            // one sample per cycle from here
        wait_n(40);
        check(samp_ctr == 40, $sformatf("samp_ctr=%0d expected 40", samp_ctr));

        // --- 2. beacon timestamp latch (latches ts_value at the ts_trigger edge).
        //        ts_value carries the SNR-invariant metric-ARGMAX peak_ctr on the ED
        //        autocorr path (aircomp_core selects peak_ctr_ac); drive it with a
        //        distinct sentinel here to prove beacon_ts == ts_value, NOT samp_ctr. ---
        @(negedge aclk);
        ts_at_trigger = 32'hDEAD_BEEF;   // a back-dated argmax instant, deliberately != samp_ctr
        ts_value   = ts_at_trigger;
        ts_trigger = 1;
        @(negedge aclk);             // Keep the trigger stable across one rising edge.
        ts_trigger = 0;
        wait_n(1);
        check(beacon_ts_valid == 1, "beacon_ts_valid should set after ts_trigger");
        check(beacon_ts == ts_at_trigger,
              $sformatf("beacon_ts=%0h expected %0h (must latch ts_value=argmax, not samp_ctr)",
                        beacon_ts, ts_at_trigger));
        @(negedge aclk); ts_value = 0;

        // clear-on-read
        beacon_ts_rd_strobe = 1; @(negedge aclk); beacon_ts_rd_strobe = 0; wait_n(1);
        check(beacon_ts_valid == 0, "beacon_ts_valid should clear after rd_strobe");

        // --- 3. FPGA-fired deadline (drive stimulus on negedge so the tx_arm rising
        //        edge is clean — setting it in the posedge active region races the DUT). ---
        @(negedge aclk);
        tx_deadline = samp_ctr + 32'd25;   // fire 25 samples from now
        tx_arm = 1;                        // rising edge cleanly seen at next posedge
        wait_n(40);       // run well past the deadline
        @(negedge aclk);
        tx_arm = 0;
        check(fire_count == 1, $sformatf("expected exactly 1 fpga_tx_fire, got %0d", fire_count));
        check(tx_fired == 1, "tx_fired should be set after the fire");
        check(ctr_at_fire >= tx_deadline && ctr_at_fire <= tx_deadline + 2,
              $sformatf("fire at samp_ctr=%0d, deadline=%0d (out of tolerance)",
                        ctr_at_fire, tx_deadline));

        // W1C ack clears tx_fired (drive the strobe on negedge for a clean sample).
        @(negedge aclk); tx_fire_ack_strobe = 1;
        wait_n(1);
        @(negedge aclk); tx_fire_ack_strobe = 0;
        wait_n(1);
        check(tx_fired == 0, "tx_fired should clear after tx_fire_ack");

        // --- 4. no spurious re-fire while disarmed ---
        wait_n(20);
        check(fire_count == 1, $sformatf("spurious re-fire while disarmed (count=%0d)", fire_count));

        // --- 5. DEFECT-1 (legacy bare-arm preserved): arm_needs_buffer=0 + dma_buf_ready=0 must
        //        STILL fire at the deadline. This is the legacy ACK path (no MM2S stage, buffer-ready
        //        never asserts); an unconditional buffer gate would hang it. eff_buf_ready forces it. ---
        @(negedge aclk); tx_fire_ack_strobe = 1; wait_n(1);
        @(negedge aclk); tx_fire_ack_strobe = 0; wait_n(1);
        @(negedge aclk);
        arm_needs_buffer = 0;              // legacy bare-arm
        dma_buf_ready    = 0;              // buffer never staged (legacy has none)
        tx_deadline      = samp_ctr + 32'd25;
        tx_arm           = 1;
        wait_n(40);       // run past the deadline
        @(negedge aclk); tx_arm = 0;
        check(fire_count == 2,
              $sformatf("DEFECT-1: legacy bare-arm (buf=0) must fire (count=%0d, expected 2)", fire_count));

        // --- 6. LEVER#2 pend-then-fire (coherent, buffer arrives BEFORE the deadline): arm pends
        //        while dma_buf_ready LOW, then completes when it rises, then fires once at the
        //        deadline. The legitimate gated-DMA path. ---
        @(negedge aclk); tx_fire_ack_strobe = 1; wait_n(1);
        @(negedge aclk); tx_fire_ack_strobe = 0; wait_n(1);
        @(negedge aclk);
        arm_needs_buffer = 1;              // coherent opt-in
        dma_buf_ready    = 0;              // not staged at the arm edge (scheduler gap)
        tx_deadline      = samp_ctr + 32'd30;
        tx_arm           = 1;
        wait_n(5);        // arm pends; no fire yet (buffer empty, deadline future)
        check(fire_count == 2, $sformatf("lever#2: pended arm must not fire early (count=%0d)", fire_count));
        @(negedge aclk); dma_buf_ready = 1; // descriptor loads BEFORE the deadline
        wait_n(40);       // arm completes, then fires at the deadline
        @(negedge aclk); tx_arm = 0;
        check(fire_count == 3,
              $sformatf("lever#2: pend-then-fire expected exactly 1 fire (count=%0d, expected 3)", fire_count));
        check(ctr_at_fire >= tx_deadline && ctr_at_fire <= tx_deadline + 2,
              $sformatf("lever#2: pend-then-fire landed at %0d, deadline=%0d", ctr_at_fire, tx_deadline));

        // --- 7. DEFECT-2 late-abstain (coherent, buffer arrives AFTER the deadline passed): the arm
        //        completes only after samp_ctr already crossed tx_deadline -> ABSTAIN, emit nothing.
        //        Firing here would land one cycle late into a past deadline and poison the
        //        superposition; lever#1 firmware voids on the no-fire. ---
        @(negedge aclk);
        arm_needs_buffer = 1;              // coherent opt-in
        dma_buf_ready    = 0;              // not staged
        tx_deadline      = samp_ctr + 32'd25; // deadline WILL pass while the buffer is empty
        tx_arm           = 1;
        wait_n(40);       // run WELL past the deadline, buffer still empty -> arm pends
        check(fire_count == 3,
              $sformatf("DEFECT-2: pending arm must not fire while unstaged (count=%0d)", fire_count));
        @(negedge aclk); dma_buf_ready = 1; // buffer loads LATE, deadline already gone
        wait_n(10);       // arm would complete here -> MUST abstain (no fire)
        @(negedge aclk); tx_arm = 0;
        check(fire_count == 3,
              $sformatf("DEFECT-2: late buffer must ABSTAIN, not fire (count=%0d, expected still 3)", fire_count));

        // --- 8. compat: arm_needs_buffer=1 with dma_buf_ready ALREADY high at the edge fires exactly
        //        like v17 (arm completes on the edge cycle, fires at the deadline). ---
        @(negedge aclk);
        arm_needs_buffer = 1;
        dma_buf_ready    = 1;              // staged before the arm edge
        tx_deadline      = samp_ctr + 32'd25;
        tx_arm           = 1;
        wait_n(40);
        @(negedge aclk); tx_arm = 0;
        check(fire_count == 4,
              $sformatf("compat: buf-high-at-edge must fire like v17 (count=%0d, expected 4)", fire_count));

        // --- 9. #44 fix (e): !tx_arm is a TRUE disarm. Arm (legacy), let it COMPLETE
        //        (tx_armed=1) with a FUTURE deadline, then DROP tx_arm BEFORE the deadline.
        //        The pre-fix RTL cleared only arm_pending, so tx_armed survived and fired
        //        LATE when the deadline later crossed (stale emit into an abandoned epoch,
        //        cascade step 5). The fix clears tx_armed on !tx_arm -> NO fire. ---
        @(negedge aclk); tx_fire_ack_strobe = 1; wait_n(1);
        @(negedge aclk); tx_fire_ack_strobe = 0; wait_n(1);
        @(negedge aclk);
        arm_needs_buffer = 0;              // legacy bare-arm completes on the edge
        dma_buf_ready    = 0;
        tx_deadline      = samp_ctr + 32'd40;   // far future
        tx_arm           = 1;              // arm completes now (tx_armed=1), deadline not yet passed
        wait_n(10);       // still BEFORE the deadline
        check(fire_count == 4,
              $sformatf("fix(e): must not fire before the deadline (count=%0d)", fire_count));
        @(negedge aclk); tx_arm = 0;       // ABORT while armed, deadline still future
        wait_n(40);       // advance WELL past the now-abandoned deadline
        check(fire_count == 4,
              $sformatf("fix(e): disarm must clear tx_armed -> NO stale late fire (count=%0d, expected 4)", fire_count));

        // --- 10. #44 fix (e-2): a fresh arm edge clears a stale (unacked) tx_fired so it
        //         cannot phantom-succeed the NEXT poll. Fire once, leave tx_fired SET (do
        //         NOT ack — models a firmware poll that timed out just BEFORE the fire),
        //         then arm again: tx_fired must read 0 at the new arm edge, before any new fire. ---
        @(negedge aclk);
        arm_needs_buffer = 0; dma_buf_ready = 0;
        tx_deadline = samp_ctr + 32'd10;
        tx_arm = 1;
        wait_n(20);       // fire crosses here -> tx_fired=1
        check(tx_fired == 1, "fix(e-2): tx_fired should be set right after the fire");
        @(negedge aclk); tx_arm = 0;       // firmware 'gives up' WITHOUT acking
        wait_n(1);
        check(tx_fired == 1, "fix(e-2): unacked tx_fired stays set through the disarm");
        @(negedge aclk);
        tx_deadline = samp_ctr + 32'd40;   // future: no immediate re-fire to muddy the read
        tx_arm = 1;                        // fresh rising edge -> must clear the stale tx_fired
        wait_n(2);
        check(tx_fired == 0,
              "fix(e-2): a fresh arm edge must clear a stale tx_fired (phantom-success guard)");
        @(negedge aclk); tx_arm = 0;

        if (fails == 0) $display("tb_route_b_sync OK");
        else            $display("tb_route_b_sync FAILED: %0d checks", fails);
        $finish;
    end

    // Safety timeout.
    initial begin #100000; $display("FAIL: tb_route_b_sync timeout"); $finish; end
endmodule
