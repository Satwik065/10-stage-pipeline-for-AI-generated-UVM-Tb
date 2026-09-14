class qpsk_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(qpsk_scoreboard)

  local bit [1:0] expected_queue[$];
  local int unsigned error_count;

  function new(string name = "qpsk_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    error_count = 0;
  endfunction

  function void write_expected(qpsk_seq_item item);
    expected_queue.push_back(item.bits);
  endfunction

  function void write_observed(qpsk_seq_item item);
    if (expected_queue.size() == 0) begin
      `uvm_error("QPSK_SB", "Observed symbol received with no expected symbol queued")
      error_count++;
      return;
    end

    bit [1:0] expected;
    expected = expected_queue.pop_front();

    if (item.bits_out !== expected) begin
      `uvm_error("QPSK_SB", $sformatf("Mismatch: expected 2'b%b, observed 2'b%b", expected, item.bits_out))
      error_count++;
    end
  endfunction

  function void check_phase(uvm_phase phase);
    if (expected_queue.size() != 0) begin
      `uvm_error("QPSK_SB", $sformatf("%0d expected symbol(s) not observed", expected_queue.size()))
      error_count += expected_queue.size();
      expected_queue.delete();
    end

    if (error_count == 0) begin
      $display("[RESULT] PASS");
    end else begin
      $display("[RESULT] FAIL errors=%0d", error_count);
    end
  endfunction

endclass