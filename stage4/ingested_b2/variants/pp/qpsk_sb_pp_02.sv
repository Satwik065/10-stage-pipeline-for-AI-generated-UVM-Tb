class qpsk_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(qpsk_scoreboard)

  // FIFOs to buffer expected and observed items
  uvm_tlm_analysis_fifo #(qpsk_seq_item) expected_fifo;
  uvm_tlm_analysis_fifo #(qpsk_seq_item) observed_fifo;

  // Analysis imps (declared externally via uvm_analysis_imp_decl)
  uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
  uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

  // Error counter
  int unsigned error_count;

  function new(string name = "qpsk_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    observed_fifo = new("observed_fifo", this);
    ap_imp_expected  = new("ap_imp_expected",  this);
    ap_imp_observed  = new("ap_imp_observed",  this);
    error_count   = 0;
  endfunction : build_phase

  function void write_expected(qpsk_seq_item item);
    qpsk_seq_item clone;
    `uvm_info(get_type_name(), $sformatf("Received expected item: bits=%0b", item.bits), UVM_HIGH)
    clone = qpsk_seq_item::type_id::create("clone");
    clone.copy(item);
    expected_fifo.write(clone);
  endfunction : write_expected

  function void write_observed(qpsk_seq_item item);
    qpsk_seq_item clone;
    `uvm_info(get_type_name(), $sformatf("Received observed item: bits_out=%0b, valid=%0b", item.bits_out, item.valid), UVM_HIGH)
    if (item.valid) begin
      clone = qpsk_seq_item::type_id::create("clone");
      clone.copy(item);
      observed_fifo.write(clone);
    end
  endfunction : write_observed

  function void check_phase(uvm_phase phase);
    qpsk_seq_item expected_item;
    qpsk_seq_item observed_item;
    bit expected_found;
    bit observed_found;

    super.check_phase(phase);

    while (1) begin
      expected_found = expected_fifo.try_get(expected_item);
      observed_found = observed_fifo.try_get(observed_item);

      if (!expected_found && !observed_found) break;

      if (expected_found && observed_found) begin
        if (expected_item.bits !== observed_item.bits_out) begin
          `uvm_error(get_type_name(), $sformatf("Mismatch: expected=%0b, observed=%0b", expected_item.bits, observed_item.bits_out))
          error_count++;
        end
      end else if (expected_found && !observed_found) begin
        `uvm_error(get_type_name(), $sformatf("Missing observed item for expected=%0b", expected_item.bits))
        error_count++;
      end else if (!expected_found && observed_found) begin
        `uvm_error(get_type_name(), $sformatf("Unexpected observed item: bits_out=%0b", observed_item.bits_out))
        error_count++;
      end
    end

    if (error_count == 0) begin
      $display("[RESULT] PASS");
    end else begin
      $display("[RESULT] FAIL errors=%0d", error_count);
    end
  endfunction : check_phase

endclass