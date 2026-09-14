class qpsk_driver extends uvm_driver #(qpsk_seq_item);

    virtual qpsk_dut_if vif;
    uvm_analysis_port #(qpsk_seq_item) ap_expected;

    `uvm_component_utils(qpsk_driver)

    function new(string name = "qpsk_driver", uvm_component parent = null);
        super.new(name, parent);
        ap_expected = new("ap_expected", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface qpsk_dut_if was not found")
        end
    endfunction

    task run_phase(uvm_phase phase);
        qpsk_seq_item req;
        qpsk_seq_item expected;
        bit [1:0] symbol;

        vif.drv_cb.ch_seed  <= '0;
        vif.drv_cb.valid_in <= 1'b0;
        vif.drv_cb.bits_in  <= '0;

        forever begin
            seq_item_port.get_next_item(req);

            symbol = req.bits;

            vif.drv_cb.valid_in <= 1'b1;
            vif.drv_cb.bits_in  <= symbol;
            @(vif.drv_cb);

            vif.drv_cb.valid_in <= 1'b0;
            vif.drv_cb.bits_in  <= '0;
            repeat (2) @(vif.drv_cb);

            expected = qpsk_seq_item::type_id::create("expected");
            expected.bits = symbol;
            expected.valid = 1'b1;
            ap_expected.write(expected);

            seq_item_port.item_done();
        end
    endtask

endclass