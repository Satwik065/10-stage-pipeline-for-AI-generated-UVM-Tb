class qpsk_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(qpsk_scoreboard)

  local bit [1:0] expected_queue[$];
  local int unsigned error_count = 0;

  function new(string name = "qpsk_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void write_expected(qpsk_seq_item item);
    if (item.valid) begin
      expected_queue.push_back(item.bits);
    end
  endfunction

  function void write_observed(qpsk_seq_item item);
    bit [1:0] expected_bits;

    if (item.valid) begin
      if (expected_queue.size() == 0) begin
        `uvm_error("SCB", "Observed symbol with no matching expected symbol")
        error_count++;
      end else begin
        expected_bits = expected_queue.pop_front();
        if (item.bits_out !== expected_bits) begin
          `uvm_error("SCB", $sformatf("Mismatch: expected 2'b%0b, observed 2'b%0b", expected_bits, item.bits_out))
          error_count++;
        end
      end
    end
  endfunction

  function void check_phase(uvm_phase phase);
    if (expected_queue.size() != 0) begin
      `uvm_error("SCB", $sformatf("%0d expected symbol(s) never observed", expected_queue.size()))
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