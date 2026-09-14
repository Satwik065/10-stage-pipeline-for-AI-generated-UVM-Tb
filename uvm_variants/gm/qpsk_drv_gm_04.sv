class qpsk_driver extends uvm_driver #(qpsk_seq_item);

`uvm_component_utils(qpsk_driver)

virtual qpsk_dut_if vif;
bit [31:0] ch_seed = 32'hDEADBEEF;
uvm_analysis_port #(qpsk_seq_item) ap_expected;

function new(string name = "qpsk_driver", uvm_component parent = null);
    super.new(name, parent);
    ap_expected = new("ap_expected", this);
endfunction

virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual qpsk_dut_if)::get(null, "*", "vif", vif)) begin
        `uvm_fatal(get_type_name(), "no vif in config_db")
    end
    void'(uvm_config_db#(bit [31:0])::get(null, "*", "ch_seed", ch_seed));
endfunction

virtual task run_phase(uvm_phase phase);
    qpsk_seq_item exp_item;

    wait (vif.rst == 1'b0);
    @(vif.drv_cb);
    vif.drv_cb.ch_seed <= ch_seed;

    forever begin
        seq_item_port.get_next_item(req);

        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b1;
        vif.drv_cb.bits_in  <= req.bits;

        @(vif.drv_cb);
        vif.drv_cb.valid_in <= 1'b0;
        vif.drv_cb.bits_in  <= 2'b00;

        exp_item = qpsk_seq_item::type_id::create("exp_item");
        exp_item.bits = req.bits;
        ap_expected.write(exp_item);

        for (int i = 0; i < 2; i++) begin
            @(vif.drv_cb);
        end

        seq_item_port.item_done();
    end
endtask
endclass