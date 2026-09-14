class qpsk_driver extends uvm_driver #(qpsk_seq_item);

  virtual qpsk_dut_if vif;
  uvm_analysis_port #(qpsk_seq_item) ap_expected;

  `uvm_component_utils(qpsk_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_expected = new("ap_expected", this);
    if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ",get_full_name(),".vif"})
  endfunction

  task run_phase(uvm_phase phase);
    qpsk_seq_item item;
    qpsk_seq_item expected_item;

    forever begin
      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b0;

      seq_item_port.get_next_item(item);

      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b1;
      vif.drv_cb.bits_in  <= item.bits;

      expected_item = qpsk_seq_item::type_id::create("expected_item");
      expected_item.bits = item.bits;
      expected_item.valid = 1'b1;
      ap_expected.write(expected_item);

      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b0;

      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b0;

      seq_item_port.item_done();
    end
  endtask

endclass