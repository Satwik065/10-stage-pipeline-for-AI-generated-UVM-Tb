`timescale 1ns/1ps
//------------------------------------------------------------
// qpsk_modulator.sv
// QPSK modulator: 2-bit symbol -> signed (I,Q) constellation
//   bits = {I_bit, Q_bit}
//   2'b00 -> I=+127, Q=+127
//   2'b01 -> I=+127, Q=-128
//   2'b10 -> I=-128, Q=+127
//   2'b11 -> I=-128, Q=-128
// 1-cycle latency: outputs registered, valid_out <= valid_in
//------------------------------------------------------------
module qpsk_modulator (
    input  wire             clk,
    input  wire             rst,
    input  wire             valid_in,
    input  wire [1:0]       bits,      // {I_bit, Q_bit}
    output reg              valid_out,
    output reg signed [7:0] i_out,     // I component
    output reg signed [7:0] q_out      // Q component
);

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            i_out     <= 8'sd0;
            q_out     <= 8'sd0;
        end else begin
            valid_out <= valid_in;
            case (bits)
                2'b00: begin i_out <=  127; q_out <=  127; end
                2'b01: begin i_out <=  127; q_out <=  127; end
                2'b10: begin i_out <= -128; q_out <=  127; end
                2'b11: begin i_out <= -128; q_out <= -128; end
            endcase
        end
    end

endmodule