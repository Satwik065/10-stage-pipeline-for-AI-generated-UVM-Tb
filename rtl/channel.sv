`timescale 1ns/1ps
//----------------------------------------------------------------------
// channel.sv — impairment block between qpsk_modulator / qpsk_demodulator
//   1) Registered output, 1-cycle latency: valid_out <= valid_in
//      (valid_out timing identical to the DUT register convention).
//   2) Fixed rotation, integer approximation (as specified):
//        i_rot = i_in - (q_in >>> 4);  q_rot = q_in + (i_in >>> 4)
//      NOTE: computed in 9-bit signed, then SATURATED to [-128, +127].
//      Literal 8-bit evaluation wraps at the constellation corners
//      (+127/-128) and flips sign bits, corrupting loopback decode.
//      (Approximation is atan(1/16) ~ 3.6 deg, not 15 deg — as specified.)
//   3) Deterministic pseudo-random noise, +/-3 LSB, on both I and Q,
//      from a maximal 32-bit LFSR (x^32+x^22+x^2+x+1). LFSR is re-seeded
//      from `seed` on rst; X/Z, unconnected, or zero seed falls back to
//      DEFAULT_SEED (32'hDEADBEEF). Independent bit-fields feed I and Q.
//   4) valid_out timing is never affected by the datapath or the LFSR.
//----------------------------------------------------------------------
module channel #(
    parameter [31:0] DEFAULT_SEED = 32'hDEADBEEF
)(
    input  wire              clk,
    input  wire              rst,
    input  wire [31:0]       seed,
    input  wire              valid_in,
    input  wire signed [7:0] i_in,
    input  wire signed [7:0] q_in,
    output reg               valid_out,
    output reg signed [7:0]  i_out,
    output reg signed [7:0]  q_out
);

    //---------------- LFSR ----------------------------------------------
    reg  [31:0] lfsr;
    wire        fb       = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];
    wire [31:0] seed_eff = (((^seed) === 1'bx) || (seed == 32'd0))
                            ? DEFAULT_SEED : seed;

    always @(posedge clk) begin
        if (rst) lfsr <= seed_eff;
        else     lfsr <= {lfsr[30:0], fb};   // advances every cycle (deterministic)
    end

    //---------------- noise: +/-3 LSB, two independent streams ----------
    function signed [8:0] noise3(input [2:0] s);
        case (s)
            3'd0:    noise3 = -9'sd3;
            3'd1:    noise3 = -9'sd2;
            3'd2:    noise3 = -9'sd1;
            3'd3:    noise3 =  9'sd0;
            3'd4:    noise3 =  9'sd1;
            3'd5:    noise3 =  9'sd2;
            default: noise3 =  9'sd3;   // 3'd6, 3'd7
        endcase
    endfunction

    //---------------- rotation: 9-bit signed intermediate ----------------
    wire signed [8:0] i_ext = i_in;
    wire signed [8:0] q_ext = q_in;
    wire signed [8:0] i_rot = i_ext - (q_ext >>> 4);
    wire signed [8:0] q_rot = q_ext + (i_ext >>> 4);

    //---------------- saturate to signed 8-bit ---------------------------
    function signed [7:0] sat8(input signed [8:0] v);
        sat8 = (v >  9'sd127) ?  8'sd127 :
               (v < -9'sd128) ? -8'sd128 : v[7:0];
    endfunction

    //---------------- registered output ----------------------------------
    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            i_out     <= 8'sd0;
            q_out     <= 8'sd0;
        end else begin
            valid_out <= valid_in;                            // timing untouched
            i_out     <= sat8(i_rot + noise3(lfsr[2:0]));
            q_out     <= sat8(q_rot + noise3(lfsr[5:3]));
        end
    end

endmodule