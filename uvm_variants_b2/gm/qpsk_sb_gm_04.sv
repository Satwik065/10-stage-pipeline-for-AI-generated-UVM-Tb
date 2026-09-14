class qpsk_scoreboard extends uvm_scoreboard;

`uvm_component_utils(qpsk_scoreboard)

qpsk_seq_item expected_q; qpsk_seq_item observed_q;

int errors = 0;

function new(string name, uvm_component parent); super.new(name, parent); endfunction

function void write_expected(qpsk_seq_item item); if (item.valid) begin expected_q = item; // Need to store a copy, as the original item might be reused or modified // by the driver or other components after write_expected returns. // A simple assignment to a class member does create a copy for objects. end endfunction

function void write_observed(qpsk_seq_item item); if (item.valid) begin observed_q = item; // Similar reasoning as for write_expected. end endfunction

virtual function void check_phase(uvm_phase phase); super.check_phase(phase);


if (expected_q == null || observed_q == null) begin
  `uvm_warning("SB_NULL_ITEM", "One of the queues is null in check_phase. Skipping comparison for this cycle.")
  return;
end

if (expected_q.bits != observed_q.bits_out) begin
  `uvm_error("SB_MISMATCH", $sformatf("Mismatch detected: Expected bits = %h, Observed bits_out = %h", expected_q.bits, observed_q.bits_out))
  errors++;
end

// Clean up the queues for the next check_phase iteration
expected_q = null;
observed_q = null;
endfunction

virtual function void report_phase(uvm_phase phase); super.report_phase(phase); if (errors == 0) begin $display(“[RESULT] PASS”); end else begin $display(“[RESULT] FAIL errors=%0d”, errors); end endfunction

endclass