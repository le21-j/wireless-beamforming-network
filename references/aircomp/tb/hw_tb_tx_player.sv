`timescale 1ns/1ps
// tb_tx_player.sv — fail-first gate for the Route-B S0 FPGA TX sample player.
// Proves: (1) nothing emits before fpga_tx_fire; (2) backpressure (tready low)
// HOLDS sample 0; (3) exactly symbol_len samples emit IN ORDER off one fire;
// (4) player_active/tvalid drop after the last sample.
//
// A posedge MONITOR records each accepted beat (tvalid && tready) — the same edge
// the DUT advances rd_addr — so there is no producer/consumer half-cycle skew.
`default_nettype none

module tb_tx_player;
    localparam int AW = 9;
    localparam int N  = 160;

    logic              aclk = 0, aresetn = 0;
    logic              load_en = 0;
    logic [AW-1:0]     load_addr = '0;
    logic [31:0]       load_data = '0;
    logic [AW:0]       symbol_len = '0;
    logic              fpga_tx_fire = 0;
    logic              dac_sample_tick = 0;   // was tx_dac_tready; player now paces off
                                              // the free-running DAC tick (dac_valid_i0)
    wire               player_tvalid, player_active;
    wire [31:0]        player_tdata;

    tx_player #(.DEPTH_AW(AW)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .load_en(load_en), .load_addr(load_addr), .load_data(load_data),
        .symbol_len(symbol_len),
        .fpga_tx_fire(fpga_tx_fire),
        .dac_sample_tick(dac_sample_tick),
        .player_tvalid(player_tvalid), .player_tdata(player_tdata),
        .player_active(player_active)
    );

    always #5 aclk = ~aclk;   // 100 MHz

    int          errors = 0;
    int          rcv    = 0;
    logic [31:0] expected [0:N-1];
    logic [31:0] received [0:N-1];

    // MONITOR: record each accepted beat (same edge the DUT consumes it).
    always @(posedge aclk) begin
        if (aresetn && player_tvalid && dac_sample_tick && rcv < N) begin
            received[rcv] <= player_tdata;
            rcv           <= rcv + 1;
        end
    end

    // watchdog
    initial begin #2_000_000; $display("FAIL: timeout (DUT never finished, rcv=%0d)", rcv); $finish; end

    initial begin
        repeat (4) @(posedge aclk);
        aresetn <= 1'b1;
        @(posedge aclk);

        // (1) no emission before any fire
        if (player_tvalid !== 1'b0) begin $display("FAIL: tvalid asserted before fire"); errors++; end

        // load a {im,re} ramp symbol
        for (int i = 0; i < N; i++) begin
            @(posedge aclk);
            load_en   <= 1'b1;
            load_addr <= i[AW-1:0];
            load_data <= {16'(i + 1000), 16'(i + 1)};
            expected[i] = {16'(i + 1000), 16'(i + 1)};
        end
        @(posedge aclk); load_en <= 1'b0;
        symbol_len <= N[AW:0];

        // fire with the DAC tick LOW (no beat yet -> nothing consumed)
        dac_sample_tick <= 1'b0;
        @(posedge aclk);
        fpga_tx_fire <= 1'b1; @(posedge aclk); fpga_tx_fire <= 1'b0;

        // (2) backpressure: with tready low, sample 0 must PERSIST and none recorded
        repeat (3) @(negedge aclk);
        if (player_tvalid !== 1'b1 || player_tdata !== expected[0]) begin
            $display("FAIL: head backpressure (tvalid=%b tdata=%h exp %h)",
                     player_tvalid, player_tdata, expected[0]); errors++;
        end
        if (rcv !== 0) begin $display("FAIL: %0d samples recorded under backpressure", rcv); errors++; end

        // (3) stream — DAC tick high every cycle; monitor records all N
        dac_sample_tick <= 1'b1;
        wait (rcv == N);

        // (4) drains: active/tvalid drop
        @(posedge aclk);
        if (player_active !== 1'b0) begin $display("FAIL: player_active high after stream"); errors++; end
        if (player_tvalid !== 1'b0) begin $display("FAIL: tvalid high after stream"); errors++; end

        // order + content
        for (int k = 0; k < N; k++) begin
            if (received[k] !== expected[k]) begin
                $display("FAIL: sample %0d got %h exp %h", k, received[k], expected[k]);
                errors++;
            end
        end

        if (errors == 0) $display("tb_tx_player OK");
        else             $display("tb_tx_player FAILED: %0d errors", errors);
        $finish;
    end
endmodule

`default_nettype wire
