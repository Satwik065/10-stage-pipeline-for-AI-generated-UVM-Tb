`timescale 1ns/1ps
//------------------------------------------------------------
// qpsk_demodulator.sv
// QPSK demodulator: zero-threshold slicer on signed (I,Q)
// Polarity matched to qpsk_modulator constellation table:
//   i_in < 0 -> I_bit (bits[1]) = 1, else 0
//   q_in < 0 -> Q_bit (bits[0]) = 1, else 0
// 1-cycle latency: outputs registered, valid_out <= valid_in
//------------------------------------------------------------
module qpsk_demodulator (
    input  wire              clk,
    input  wire              rst,
    input  wire              valid_in,
    input  wire signed [7:0] i_in,
    input  wire signed [7:0] q_in,
    output reg               valid_out,
    output reg  [1:0]        bits
);

    reg       r_valid;
    reg [1:0] r_bits;

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            bits      <= 2'b00;
            r_valid   <= 1'b0;
            r_bits    <= 2'b00;
        end else begin
            r_valid   <= valid_in;
            r_bits    <= {(i_in < 8'sd0), (q_in < 8'sd0)};
            valid_out <= r_valid;
            bits      <= r_bits;
        end
    end

endmodule