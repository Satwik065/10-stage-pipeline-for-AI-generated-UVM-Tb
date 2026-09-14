class qpsk_scoreboard extends uvm_scoreboard;

qpsk_seq_item expected_item; qpsk_seq_item observed_item; int errors = 0;

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected; uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

`uvm_component_utils(qpsk_scoreboard)

function new(string name, uvm_component parent = null); super.new(name, parent); endfunction : new

function void write_expected(qpsk_seq_item item); `uvm_info(get_full_name(), $sformatf(“Received expected item: %s”, item.sprint()), UVM_HIGH) expected_item = item; endfunction : write_expected

function void write_observed(qpsk_seq_item item); uvm_info(get_full_name(), $sformatf("Received observed item: %s", item.sprint()), UVM_HIGH)     observed_item = item;     // Compare when both expected and observed items are available     if (expected_item != null && expected_item.valid == 1 && item.valid == 1) begin       if (expected_item.bits != item.bits_out) begin         uvm_error(get_full_name(), $sformatf(“Mismatch detected! Expected: %0b, Observed: %0b”, expected_item.bits, item.bits_out)) errors++; end // Clear items after comparison to avoid comparing old data expected_item = null; observed_item = null; end endfunction : write_observed

virtual function void check_phase(uvm_phase phase); super.check_phase(phase); if (errors == 0) begin uvm_info(get_full_name(), "[RESULT] PASS", UVM_ALL)     end else begin       uvm_info(get_full_name(), $sformatf(“[RESULT] FAIL errors=%0d”, errors), UVM_ALL) end endfunction : check_phase

endclass : qpsk_scoreboard