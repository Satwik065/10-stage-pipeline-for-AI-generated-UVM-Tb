class qpsk_driver extends uvm_driver #(qpsk_seq_item);
  virtual qpsk_dut_if vif;
  uvm_analysis_port #(qpsk_seq_item) ap_expected;

  `uvm_component_utils(qpsk_driver)

  function new(string name = "qpsk_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
    ap_expected = new("ap_expected", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive_symbol(req.bits);
      seq_item_port.item_done();
    end
  endtask

  task drive_symbol(input bit [1:0] sym);
    qpsk_seq_item expected_item;

    // Drive one cycle of valid_in with the symbol
    @(vif.drv_cb);
    vif.drv_cb.valid_in  <= 1'b1;
    vif.drv_cb.bits_in  <= sym;

    // At least 2 idle cycles between symbols
    repeat (2) begin
      @(vif.drv_cb);
      vif.drv_cb.valid_in <= 1'b0;
    end

    // Write expected item to analysis port
    expected_item = qpsk_seq_item::type_id::create("expected_item");
    expected_item.bits = sym;
    ap_expected.write(expected_item);
  endtask
endclass