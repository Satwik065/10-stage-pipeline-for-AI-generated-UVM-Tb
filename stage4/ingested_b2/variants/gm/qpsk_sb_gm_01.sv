class qpsk_scoreboard extends uvm_scoreboard;

qpsk_seq_item expected_qpsk_q[$]; qpsk_seq_item observed_qpsk_q[$]; int errors = 0;

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected; uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

uvm_component_utils_begin(qpsk_scoreboard)   uvm_component_utils_end

function new(string name, uvm_component parent = null); super.new(name, parent); endfunction

function void build_phase(uvm_phase phase); super.build_phase(phase); ap_imp_expected = new(“ap_imp_expected”, this); ap_imp_observed = new(“ap_imp_observed”, this); endfunction

function void write_expected(qpsk_seq_item item); `uvm_info(get_full_name(), $sformatf(“Received expected item: bits=%0d, valid=%0d”, item.bits, item.valid), UVM_HIGH) expected_qpsk_q.push_back(item.clone()); endfunction

function void write_observed(qpsk_seq_item item); `uvm_info(get_full_name(), $sformatf(“Received observed item: bits_out=%0d, valid=%0d”, item.bits_out, item.valid), UVM_HIGH) observed_qpsk_q.push_back(item.clone()); endfunction

function void check_phase(uvm_phase phase); qpsk_seq_item expected_item; qpsk_seq_item observed_item;


`uvm_info(get_full_name(), $sformatf("Checking phase. Expected queue size: %0d, Observed queue size: %0d", expected_qpsk_q.size(), observed_qpsk_q.size()), UVM_MEDIUM)

while (expected_qpsk_q.size() > 0 && observed_qpsk_q.size() > 0) begin
  expected_item = expected_qpsk_q.pop_front();
  observed_item = observed_qpsk_q.pop_front();

  if (expected_item.valid != observed_item.valid) begin
    `uvm_error(get_full_name(), $sformatf("Mismatch in valid signal. Expected: %0d, Observed: %0d", expected_item.valid, observed_item.valid))
    errors++;
  end else if (expected_item.valid && observed_item.valid) begin
    if (expected_item.bits != observed_item.bits_out) begin
      `uvm_error(get_full_name(), $sformatf("Mismatch in bits. Expected: %0d, Observed: %0d", expected_item.bits, observed_item.bits_out))
      errors++;
    end
  end
end

// Check for remaining items in either queue, which indicates a length mismatch
if (expected_qpsk_q.size() > 0) begin
  `uvm_error(get_full_name(), $sformatf("Expected queue has %0d remaining items.", expected_qpsk_q.size()))
  errors += expected_qpsk_q.size();
end
if (observed_qpsk_q.size() > 0) begin
  `uvm_error(get_full_name(), $sformatf("Observed queue has %0d remaining items.", observed_qpsk_q.size()))
  errors += observed_qpsk_q.size();
end

if (errors == 0) begin
  `uvm_info(get_full_name(), "[RESULT] PASS", UVM_NONE)
end else begin
  `uvm_info(get_full_name(), $sformatf("[RESULT] FAIL errors=%0d", errors), UVM_NONE)
end
endfunction

endclass