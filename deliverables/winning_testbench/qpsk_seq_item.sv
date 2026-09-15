`ifndef QPSK_SEQ_ITEM_SV
`define QPSK_SEQ_ITEM_SV
//----------------------------------------------------------------------
// qpsk_seq_item — Stage 1 contract artifact (Constitution v2.1).
// Field automation macros INCLUDED deliberately: without them,
// clone()/compare() silently no-op on fields — silent corruption that
// would poison Stage 5 scoring.
// The uniform-symbol constraint mirrors the §3 envelope requirement
// (each of the 4 symbols >= 10 occurrences per scoring run).
//----------------------------------------------------------------------
class qpsk_seq_item extends uvm_sequence_item;

    // ---- transaction fields --------------------------------------------
    rand bit [1:0] bits;       // symbol to transmit {I_bit, Q_bit}
    bit       [1:0] bits_out;  // received symbol (monitor/scoreboard fill)
    bit             valid;     // response-validity flag

    // Uniform over the 4-symbol constellation. A 2-bit rand variable is
    // inherently uniform; this documents the legal domain and gives
    // Stage 1 a named, AST-checkable artifact.
    constraint c_sym_uniform { bits inside {2'b00, 2'b01, 2'b10, 2'b11}; }

    `uvm_object_utils_begin(qpsk_seq_item)
        `uvm_field_int(bits,     UVM_ALL_ON)
        `uvm_field_int(bits_out, UVM_ALL_ON)
        `uvm_field_int(valid,    UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "qpsk_seq_item");
        super.new(name);
    endfunction : new

    function string convert2string();
        return $sformatf("qpsk_seq_item: bits=%b bits_out=%b valid=%0b",
                         bits, bits_out, valid);
    endfunction : convert2string

endclass : qpsk_seq_item
`endif