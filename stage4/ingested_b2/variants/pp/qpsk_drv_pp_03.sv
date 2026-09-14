class qpsk_driver extends uvm_driver #(qpsk_seq_item);

  virtual qpsk_dut_if vif;
  uvm_analysis_port #(qpsk_seq_item) ap_expected;

  `uvm_component_utils(qpsk_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found")
    end
    ap_expected = new("ap_expected", this);
  endfunction

  task run_phase(uvm_phase phase);
    qpsk_seq_item item;
    qpsk_seq_item expected_item;

    forever begin
      seq_item_port.get_next_item(item);

      // Drive one symbol: valid_in = 1 for one cycle
      vif.drv_cb.valid_in  <= 1'b1;
      vif.drv_cb.bits_in   <= item.bits;
      @(vif.drv_cb);

      // Create and write expected item to analysis port
      expected_item = qpsk_seq_item::type_id::create("expected_item");
      expected_item.bits = item.bits;
      ap_expected.write(expected_item);

      // Deassert valid and drive at least 2 idle cycles
      vif.drv_cb.valid_in <= 1'b0;
      vif.drv_cb.bits_in  <= 2'b00;
      repeat (2) @(vif.drv_cb);

      seq_item_port.item_done();
    end
  endtask

endclass