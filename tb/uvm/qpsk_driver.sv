class qpsk_driver extends uvm_driver #(qpsk_seq_item);
    `uvm_component_utils(qpsk_driver)

    virtual qpsk_dut_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "virtual interface 'vif' not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        // STAGE 2 STUB: idles the bus. Stage 4 replaces this body with
        // the real get_next_item/drive/item_done stimulus loop.
        forever begin
            @(vif.drv_cb);
            vif.drv_cb.valid_in <= 1'b0;
            vif.drv_cb.bits_in  <= 2'b00;
        end
    endtask

endclass