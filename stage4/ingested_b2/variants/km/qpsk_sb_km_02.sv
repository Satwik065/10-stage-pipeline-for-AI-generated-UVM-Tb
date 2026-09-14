class qpsk_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(qpsk_scoreboard)

  uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
  uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

  qpsk_seq_item expected_q[$];
  qpsk_seq_item observed_q[$];

  int unsigned error_count;

  function new(string name = "qpsk_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
    error_count = 0;
  endfunction

  function void write_expected(qpsk_seq_item item);
    qpsk_seq_item exp_item;
    if (item == null) begin
      `uvm_error("QPSK_SB", "write_expected received null item")
      return;
    end
    exp_item = qpsk_seq_item::type_id::create("exp_item");
    exp_item.copy(item);
    expected_q.push_back(exp_item);
  endfunction

  function void write_observed(qpsk_seq_item item);
    qpsk_seq_item obs_item;
    if (item == null) begin
      `uvm_error("QPSK_SB", "write_observed received null item")
      return;
    end
    obs_item = qpsk_seq_item::type_id::create("obs_item");
    obs_item.copy(item);
    observed_q.push_back(obs_item);
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    compare_streams();
    if (error_count == 0)
      `uvm_info("RESULT", "[RESULT] PASS", UVM_NONE)
    else
      `uvm_info("RESULT", $sformatf("[RESULT] FAIL errors=%0d", error_count), UVM_NONE)
  endfunction

  function void compare_streams();
    qpsk_seq_item exp_item;
    qpsk_seq_item obs_item;
    int unsigned idx;
    int unsigned min_len;

    idx = 0;
    while ((expected_q.size() > 0) && (observed_q.size() > 0)) begin
      exp_item = expected_q.pop_front();
      obs_item = observed_q.pop_front();
      if (obs_item.valid !== 1'b1) begin
        `uvm_error("QPSK_SB", $sformatf("Observed item %0d has valid deasserted (valid=%0b)", idx, obs_item.valid))
        error_count++;
      end
      else if (exp_item.bits !== obs_item.bits_out) begin
        `uvm_error("QPSK_SB", $sformatf("Symbol %0d mismatch: expected bits=%0b, got bits_out=%0b", idx, exp_item.bits, obs_item.bits_out))
        error_count++;
      end
      idx++;
    end

    while (expected_q.size() > 0) begin
      void'(expected_q.pop_front());
      `uvm_error("QPSK_SB", $sformatf("Missing observed symbol for expected item %0d", idx))
      error_count++;
      idx++;
    end

    while (observed_q.size() > 0) begin
      obs_item = observed_q.pop_front();
      if (obs_item.valid === 1'b1) begin
        `uvm_error("QPSK_SB", $sformatf("Extra observed symbol %0d with no matching expected item (bits_out=%0b)", idx, obs_item.bits_out))
        error_count++;
      end
      idx++;
    end
  endfunction

endclass