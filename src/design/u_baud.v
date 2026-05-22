module u_baud (
    input  wire sys_clk,
    input  wire sys_rst,
    output reg  baud_clk
);

localparam baud_rate = 9600;
localparam clk       = 5000000;

localparam divisor = clk / (baud_rate * 32);
localparam cw      = $clog2(divisor) + 1;

reg [cw - 1: 0] clk_divider;

always @(posedge sys_clk) begin
    if (sys_rst) begin
        clk_divider <= 0;
        baud_clk    <= 1'b0;
    end else begin
        if (clk_divider == (divisor - 1)) begin
            baud_clk    <= ~baud_clk;
            clk_divider <= 0;
        end else begin
            clk_divider <= clk_divider + 1'b1;
        end
    end
end

endmodule
