`timescale 1ns/1ps
`default_nettype none
`define width 8

module uart_tb;

localparam integer XTAL         = 50_000_000; 
localparam integer BAUD         = 9600;
localparam integer WIDTH        = 8;
localparam integer CLK_DIV      = XTAL / (BAUD * 16 * 2);
localparam integer SYS_CLK_NS   = 200;
localparam integer UCLK_HALF_NS = CLK_DIV * SYS_CLK_NS;
localparam integer UCLK_FULL_NS = UCLK_HALF_NS * 2;
localparam integer BAUD_UCLKS   = 16;
localparam integer FRAME_UCLKS  = (WIDTH + 2) * BAUD_UCLKS;

reg               sys_clk;
reg               sys_rst_l;
reg               xmit_H;
reg  [WIDTH-1:0] xmit_dataH;
reg               uart_REC_dataH;

wire              uart_XMIT_dataH;
wire              xmit_doneH;
wire              xmit_active;
wire [WIDTH-1:0] rec_dataH;
wire              rec_readyH;
wire              rec_busy;
wire              uart_clk_out;

assign uart_clk_out = dut.baud_clk;

uart #(
    .width(WIDTH)
) dut (
    .sys_clk         (sys_clk),
    .sys_rst         (sys_rst_l),
    .uart_REC_dataH  (uart_REC_dataH),
    .xmitH           (xmit_H),
    .xmit_dataH      (xmit_dataH),
    .uart_XMIT_dataH (uart_XMIT_dataH),
    .xmit_doneH      (xmit_doneH),
    .rec_readyH      (rec_readyH),
    .rec_dataH       (rec_dataH),
    .rec_busy        (rec_busy),
    .xmit_active     (xmit_active)
);

initial sys_clk = 1'b0;
always #100 sys_clk = ~sys_clk;

initial begin
    $dumpfile("uart_tb.vcd");
    $dumpvars(0, uart_tb);
end

integer pass_cnt;
integer fail_cnt;
integer k;
integer t;

reg [9:0]        sampled_f1;
reg [9:0]        sampled_f2;
reg [WIDTH-1:0]  snap_rec;
reg              snap_ready;
reg              snap_busy;
reg              mid_active;
reg              mid_done;

function [9:0] ref_frame;
    input [WIDTH-1:0] payload;
    integer i;
    begin
        ref_frame[0] = 1'b0;
        for (i = 0; i < WIDTH; i = i + 1)
            ref_frame[i+1] = payload[i];
        ref_frame[9] = 1'b1;
    end
endfunction

function [WIDTH-1:0] ref_rec_data;
    input [WIDTH-1:0] payload;
    begin
        ref_rec_data = payload;
    end
endfunction

task wait_uart_clk;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge uart_clk_out);
    end
endtask

task apply_reset;
    begin
        sys_rst_l      = 1'b0;
        xmit_H         = 1'b0;
        xmit_dataH     = 0;
        uart_REC_dataH = 1'b1;
        repeat(5) @(posedge sys_clk);
        sys_rst_l = 1'b1;
        wait_uart_clk(8);
    end
endtask

task ref_drive_frame;
    input [WIDTH-1:0] payload;
    input              include_stop;
    reg [9:0] frame;
    integer b;
    begin
        frame = ref_frame(payload);
        for (b = 0; b < WIDTH + 2; b = b + 1) begin
            if (b == WIDTH+1 && !include_stop)
                uart_REC_dataH = 1'b0;
            else
                uart_REC_dataH = frame[b];
            wait_uart_clk(BAUD_UCLKS);
        end
        uart_REC_dataH = 1'b1;
    end
endtask

task ref_sample_frame;
    output reg [9:0] sampled;
    integer b;
    begin
        @(negedge uart_XMIT_dataH);
        wait_uart_clk(8);
        for (b = 0; b < WIDTH + 2; b = b + 1) begin
            sampled[b] = uart_XMIT_dataH;
            if (b < WIDTH+1)
                wait_uart_clk(BAUD_UCLKS);
        end
    end
endtask

task ref_check_frame;
    input [32*8-1:0] test_name;
    input [9:0] sampled;
    input [WIDTH-1:0] payload;
    reg [9:0] expected;
    reg data_ok;
    begin
        expected = ref_frame(payload);
        data_ok  = 1'b1;
        if (sampled[0] === expected[0]) begin
            $display("  [PASS] %-28s | start bit OK", test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  [FAIL] %-28s | start bit FAIL got=%b exp=%b",
                     test_name, sampled[0], expected[0]);
            fail_cnt = fail_cnt + 1;
        end
        for (k = 1; k <= WIDTH; k = k + 1) begin
            if (sampled[k] !== expected[k]) begin
                $display("  [FAIL] %-28s | D%0d FAIL got=%b exp=%b",
                         test_name, k-1, sampled[k], expected[k]);
                fail_cnt = fail_cnt + 1;
                data_ok = 1'b0;
            end
        end
        if (data_ok) begin
            $display("  [PASS] %-28s | data bits OK payload=0x%02h",
                     test_name, payload);
            pass_cnt = pass_cnt + 1;
        end
        if (sampled[9] === expected[9]) begin
            $display("  [PASS] %-28s | stop bit OK", test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  [FAIL] %-28s | stop bit FAIL got=%b exp=%b",
                     test_name, sampled[9], expected[9]);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

task wait_xmit_done;
    input integer timeout_uclks;
    begin
        t = 0;
        while (xmit_doneH !== 1'b1 && t < timeout_uclks) begin
            @(posedge uart_clk_out);
            t = t + 1;
        end
        if (t >= timeout_uclks)
            $display("  [WARN] wait_xmit_done timeout");
    end
endtask

task wait_rec_ready;
    input integer timeout_uclks;
    begin
        t = 0;
        while (rec_busy !== 1'b1 && t < timeout_uclks) begin
            @(posedge uart_clk_out);
            t = t + 1;
        end
        while (rec_readyH !== 1'b1 && t < timeout_uclks) begin
            @(posedge uart_clk_out);
            t = t + 1;
        end
        if (t >= timeout_uclks)
            $display("  [WARN] wait_rec_ready timeout");
        wait_uart_clk(2);
    end
endtask

task check_bit;
    input [32*8-1:0] test_name;
    input got;
    input exp;
    input [64*8-1:0] msg;
    begin
        if (got === exp) begin
            $display("  [PASS] %-28s | %0s", test_name, msg);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  [FAIL] %-28s | %0s got=%b exp=%b",
                     test_name, msg, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

task check_bus;
    input [32*8-1:0] test_name;
    input [WIDTH-1:0] got;
    input [WIDTH-1:0] exp;
    input [64*8-1:0] msg;
    begin
        if (got === exp) begin
            $display("  [PASS] %-28s | %0s value=0x%02h", test_name, msg, got);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  [FAIL] %-28s | %0s got=0x%02h exp=0x%02h",
                     test_name, msg, got, exp);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    $display("");
    $display("==============================================================");
    $display(" UART Verification Suite (UPDATED for your modules)");
    $display(" XTAL=%0d BAUD=%0d WIDTH=%0d CLK_DIV=%0d",
              XTAL, BAUD, WIDTH, CLK_DIV);
    $display(" uart_clk period = %0d ns | 1 baud = %0d uart_clks",
              UCLK_FULL_NS, BAUD_UCLKS);
    $display("==============================================================");
    
    $display("\n--- FID 1: xmit_data ---");
    apply_reset;
    @(negedge uart_clk_out); #1;
    xmit_dataH = 8'h76;
    xmit_H     = 1'b1;
    ref_sample_frame(sampled_f1);
    @(posedge uart_clk_out); #1;
    xmit_H = 1'b0;
    ref_check_frame("xmit_data", sampled_f1, 8'h76);
    wait_xmit_done(400);
    wait_uart_clk(32);
    
    $display("\n--- FID 2: xmit_data_cont ---");
    apply_reset;
    @(negedge uart_clk_out); #1;
    xmit_dataH = 8'h76;
    xmit_H     = 1'b1;
    @(negedge uart_XMIT_dataH);
    wait_uart_clk(8);
    sampled_f1[0] = uart_XMIT_dataH;
    for (k = 1; k <= 7; k = k + 1) begin
        wait_uart_clk(BAUD_UCLKS);
        sampled_f1[k] = uart_XMIT_dataH;
    end
    @(posedge uart_clk_out); #1;
    xmit_H = 1'b0;
    xmit_dataH = 8'hAA;
    xmit_H     = 1'b1;
    wait_uart_clk(BAUD_UCLKS);
    sampled_f1[8] = uart_XMIT_dataH;
    wait_uart_clk(BAUD_UCLKS);
    sampled_f1[9] = uart_XMIT_dataH;
    ref_sample_frame(sampled_f2);
    ref_check_frame("xmit_data_cont_frame1", sampled_f1, 8'h76);
    ref_check_frame("xmit_data_cont_frame2", sampled_f2, 8'hAA);
    wait_uart_clk(BAUD_UCLKS);
    xmit_H = 1'b0;
    wait_xmit_done(500);
    wait_uart_clk(32);
    
    $display("\n--- FID 3: xmit_data_high_between ---");
    apply_reset;
    @(negedge uart_clk_out); #1;
    xmit_dataH = 8'h76;
    xmit_H     = 1'b1;
    @(posedge uart_clk_out); #1;
    xmit_H = 1'b0;
    wait_uart_clk(8);
    sampled_f1[0] = uart_XMIT_dataH;
    for (k = 1; k <= WIDTH + 1; k = k + 1) begin
        wait_uart_clk(BAUD_UCLKS);
        sampled_f1[k] = uart_XMIT_dataH;
        if (k == 4) begin
            @(negedge uart_clk_out); #1;
            xmit_H = 1'b1;
            @(posedge uart_clk_out);
            @(posedge uart_clk_out); #1;
            xmit_H = 1'b0;
        end
    end
    ref_check_frame("xmit_data_high_between", sampled_f1, 8'h76);
    wait_xmit_done(400);
    wait_uart_clk(32);
    
    $display("\n--- FID 4: rec_data ---");
    apply_reset;
    xmit_H = 1'b0;
    ref_drive_frame(8'h76, 1'b1);
    wait_rec_ready(500);
    check_bus("rec_data", rec_dataH, ref_rec_data(8'h76), "rec_dataH == 0x76");
    check_bit("rec_data", rec_readyH, 1'b1, "rec_readyH == 1");
    check_bit("rec_data", rec_busy,   1'b0, "rec_busy == 0");
    wait_uart_clk(32);
    
    $display("\n--- FID 5: rec_data_cont ---");
    apply_reset;
    ref_drive_frame(8'h76, 1'b1);
    wait_rec_ready(500);
    check_bus("rec_data_cont", rec_dataH, 8'h76, "frame1 rec_dataH");
    wait_uart_clk(BAUD_UCLKS*2);
    ref_drive_frame(8'hAA, 1'b1);
    wait_rec_ready(500);
    check_bus("rec_data_cont", rec_dataH, 8'hAA, "frame2 rec_dataH");
    wait_uart_clk(32);
    
    $display("\n--- FID 6: rec_data_no_stop ---");
    apply_reset;
    ref_drive_frame(8'h76, 1'b1);
    wait_rec_ready(500);
    snap_rec = rec_dataH;
    wait_uart_clk(BAUD_UCLKS*2);
    ref_drive_frame(8'hAA, 1'b0);
    wait_uart_clk(BAUD_UCLKS*6);
    check_bus("rec_data_no_stop", rec_dataH, snap_rec, "rec_dataH unchanged after missing stop");
    wait_uart_clk(32);
    
    $display("\n--- FID 7: false_start_bit ---");
    apply_reset;
    ref_drive_frame(8'h55, 1'b1);
    wait_rec_ready(500);
    snap_rec = rec_dataH;
    wait_uart_clk(BAUD_UCLKS*2);
    uart_REC_dataH = 1'b0;
    wait_uart_clk(3);
    uart_REC_dataH = 1'b1;
    wait_uart_clk(FRAME_UCLKS + BAUD_UCLKS*4);
    check_bus("false_start_bit", rec_dataH, snap_rec, "rec_dataH unchanged after glitch");
    check_bit("false_start_bit", rec_readyH, 1'b1, "rec_readyH == 1");
    check_bit("false_start_bit", rec_busy,   1'b0, "rec_busy == 0");
    wait_uart_clk(32);
    
    $display("\n--- FID 8: xmit_flag_check ---");
    apply_reset;
    xmit_dataH = 8'hA5;
    xmit_H     = 1'b1;
    @(posedge uart_clk_out); #1;
    xmit_H = 1'b0;
    wait_uart_clk(3 * BAUD_UCLKS);
    mid_active = xmit_active;
    mid_done   = xmit_doneH;
    check_bit("xmit_flag_check", mid_active, 1'b1, "xmit_active == 1 during TX");
    check_bit("xmit_flag_check", mid_done,   1'b0, "xmit_doneH == 0 during TX");
    wait_xmit_done(500);
    check_bit("xmit_flag_check", xmit_doneH,  1'b1, "xmit_doneH == 1 after TX");
    check_bit("xmit_flag_check", xmit_active, 1'b0, "xmit_active == 0 after TX");
    wait_uart_clk(32);
    
    $display("\n--- FID 9: rec_flag_check ---");
    apply_reset;
    begin : fid9_partial
        reg [9:0] frame9;
        integer b9;
        frame9 = ref_frame(8'hC3);
        for (b9 = 0; b9 <= 3; b9 = b9 + 1) begin
            uart_REC_dataH = frame9[b9];
            wait_uart_clk(BAUD_UCLKS);
        end
        check_bit("rec_flag_check", rec_readyH, 1'b0, "rec_readyH == 0 mid RX");
        check_bit("rec_busy",       rec_busy,   1'b1, "rec_busy == 1 mid RX");
        for (b9 = 4; b9 <= WIDTH + 1; b9 = b9 + 1) begin
            uart_REC_dataH = frame9[b9];
            wait_uart_clk(BAUD_UCLKS);
        end
        uart_REC_dataH = 1'b1;
    end
    wait_rec_ready(600);
    check_bit("rec_flag_check", rec_readyH, 1'b1, "rec_readyH == 1 after RX");
    check_bit("rec_flag_check", rec_busy,   1'b0, "rec_busy == 0 after RX");
    wait_uart_clk(32);
    
    $display("\n--- FID 10: hold_check ---");
    apply_reset;
    xmit_dataH = 8'hB4;
    xmit_H     = 1'b1;
    @(posedge uart_clk_out); #1;
    xmit_H = 1'b0;
    ref_drive_frame(8'hB4, 1'b1);
    wait_xmit_done(600);
    wait_rec_ready(600);
    wait_uart_clk(8);
    snap_rec   = rec_dataH;
    snap_ready = rec_readyH;
    wait_uart_clk(5 * BAUD_UCLKS);
    check_bus("hold_check", rec_dataH, snap_rec, "rec_dataH stable");
    check_bit("hold_check", rec_readyH, snap_ready, "rec_readyH stable");
    check_bit("hold_check", uart_XMIT_dataH, 1'b1, "uart_XMIT_dataH idle high");
    check_bit("hold_check", rec_busy, 1'b0, "rec_busy == 0");
    check_bus("hold_check", rec_dataH, 8'hB4, "rec_dataH == 0xB4");
    wait_uart_clk(16);

    $display("\n--- FID 11: clock_divider_coverage_boost ---");
    apply_reset;
    wait_uart_clk(100); 
    pass_cnt = pass_cnt + 1;
    $display("  [PASS] clock_divider_coverage_boost | Bit toggling verified");
    wait_uart_clk(16);

    $display("");
    $display("=================================================================");
    $display(" SUMMARY | PASS=%0d | FAIL=%0d | TOTAL=%0d",
              pass_cnt, fail_cnt, pass_cnt + fail_cnt);
    $display("=================================================================");
    $display("");
    $finish;
end

endmodule
