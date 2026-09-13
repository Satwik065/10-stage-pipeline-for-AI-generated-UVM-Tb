class qpsk_driver extends uvm_driver #(qpsk_seq_item);
    `uvm_component_utils(qpsk_driver)

    virtual qpsk_dut_if vif;
    bit [31:0]         ch_seed = 32'hDEADBEEF;

    uvm_analysis_port #(qpsk_seq_item) ap_expected;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_expected = new("ap_expected", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "no vif in config_db")
        void'(uvm_config_db#(bit [31:0])::get(this, "", "ch_seed", ch_seed));
    endfunction

    task run_phase(uvm_phase phase);
        wait (vif.rst == 1'b0);
        @(vif.drv_cb);
        vif.drv_cb.ch_seed <= ch_seed;
        forever begin
            qpsk_seq_item drive_item;
            qpsk_seq_item expect_item;
            seq_item_port.get_next_item(req);
            drive_item = req;
            vif.drv_cb.valid_in <= 1'b1;
            vif.drv_cb.bits_in  <= drive_item.bits;
            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b0;
            vif.drv_cb.bits_in  <= 2'b00;
            expect_item = qpsk_seq_item::type_id::create("expect_item");
            expect_item.bits = drive_item.bits;
            ap_expected.write(expect_item);
            repeat (2) @(vif.drv_cb);
            seq_item_port.item_done();
        end
    endtask
endclass