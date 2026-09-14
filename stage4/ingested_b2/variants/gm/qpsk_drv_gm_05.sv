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

        if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "qpsk_driver virtual interface 'vif' was not found")
        end
    endfunction

    task run_phase(uvm_phase phase);
        qpsk_seq_item req;
        qpsk_seq_item expected;

        vif.drv_cb.valid_in <= 1'b0;
        vif.drv_cb.bits_in  <= 2'b00;

        forever begin
            seq_item_port.get_next_item(req);

            while (vif.rst) begin
                vif.drv_cb.valid_in <= 1'b0;
                vif.drv_cb.bits_in  <= 2'b00;
                @(vif.drv_cb);
            end

            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b1;
            vif.drv_cb.bits_in  <= req.bits;

            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b0;
            vif.drv_cb.bits_in  <= 2'b00;

            repeat (2) begin
                @(vif.drv_cb);
                vif.drv_cb.valid_in <= 1'b0;
                vif.drv_cb.bits_in  <= 2'b00;
            end

            expected = qpsk_seq_item::type_id::create("expected");
            expected.bits  = req.bits;
            expected.valid = 1'b1;
            ap_expected.write(expected);

            seq_item_port.item_done();
        end
    endtask

endclass