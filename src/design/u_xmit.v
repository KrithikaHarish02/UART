`timescale 1ns/1ps
`default_nettype none
module uart_transmitter (
    input wire sys_clk,
    input wire sys_rst_l,
    input wire tick,
    input wire xmitH,
    input wire [7:0] xmit_dataH,
    output reg uart_XMIT_dataH,
    output reg xmit_doneH,
    output reg xmit_active
);
reg [8:0] shift_reg;
reg [3:0] bit_count;
reg [3:0] tick_count;
reg busy;
always @(posedge sys_clk or negedge sys_rst_l) begin
    if (!sys_rst_l) begin
        uart_XMIT_dataH<=1'b1;
        xmit_doneH<=1'b0;
        xmit_active<=1'b0;
        shift_reg<=9'b1_11111111;
        bit_count<=4'd0;
        tick_count<=4'd0;
        busy<=1'b0;
    end else begin
        xmit_doneH<=1'b0;
        if (xmitH && !busy) begin
            shift_reg<={1'b1, xmit_dataH};
            busy<=1'b1;
            xmit_active<=1'b1;
            uart_XMIT_dataH<=1'b0;
            bit_count<= 4'd1;
            tick_count<= 4'd0;
        end else if (busy && tick) begin
            if (tick_count == 4'd15) begin
                tick_count<=4'd0;
                uart_XMIT_dataH<=shift_reg[0];
                shift_reg<={1'b1, shift_reg[8:1]};
                if (bit_count == 4'd9) begin
                    busy<=1'b0;
                    xmit_active<=1'b0;
                    xmit_doneH<=1'b1;
                    uart_XMIT_dataH<=1'b1;
                end else begin
                    bit_count<=bit_count+1'b1;
                end
            end else begin
                tick_count<=tick_count+1'b1;
            end
        end
    end
end
endmodule
