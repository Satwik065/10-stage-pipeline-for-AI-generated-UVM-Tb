class qpsk_driver extends uvm_driver #(qpsk_seq_item);
    `uvm_component_utils(qpsk_driver)

    virtual qpsk_dut_if vif;
    uvm_analysis_port #(qpsk_seq_item) ap_expected;

    function new(string name = "qpsk_driver", uvm_component parent = null);
        super.new(name, parent);
        ap_expected = new("ap_expected", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "qpsk_driver: virtual interface not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        qpsk_seq_item req_item;
        qpsk_seq_item exp_item;

        vif.drv_cb.ch_seed   <= 32'hDEAD_BEEF;
        vif.drv_cb.valid_in  <= 1'b0;
        vif.drv_cb.bits_in   <= 2'b00;

        forever begin
            seq_item_port.get_next_item(req_item);

            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b1;
            vif.drv_cb.bits_in  <= req_item.bits;

            exp_item = qpsk_seq_item::type_id::create("exp_item");
            exp_item.bits = req_item.bits;
            ap_expected.write(exp_item);

            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b0;
            vif.drv_cb.bits_in  <= 2'b00;

            repeat (2) @(vif.drv_cb);

            seq_item_port.item_done();
        end
    endtask
endclass