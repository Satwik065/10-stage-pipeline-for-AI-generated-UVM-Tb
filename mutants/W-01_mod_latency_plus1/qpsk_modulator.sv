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

    reg              r_valid;
    reg signed [7:0] r_i;
    reg signed [7:0] r_q;

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            i_out     <= 8'sd0;
            q_out     <= 8'sd0;
            r_valid   <= 1'b0;
            r_i       <= 8'sd0;
            r_q       <= 8'sd0;
        end else begin
            r_valid   <= valid_in;
            case (bits)
                2'b00: begin r_i <=  127; r_q <=  127; end
                2'b01: begin r_i <=  127; r_q <= -128; end
                2'b10: begin r_i <= -128; r_q <=  127; end
                2'b11: begin r_i <= -128; r_q <= -128; end
            endcase
            valid_out <= r_valid;
            i_out     <= r_i;
            q_out     <= r_q;
        end
    end

endmodule