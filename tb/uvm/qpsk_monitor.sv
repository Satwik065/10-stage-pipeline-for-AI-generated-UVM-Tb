class qpsk_monitor extends uvm_monitor;
    `uvm_component_utils(qpsk_monitor)

    virtual qpsk_dut_if vif;
    uvm_analysis_port #(qpsk_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "virtual interface 'vif' not found in config_db")
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.valid_out) begin
                qpsk_seq_item item;
                item = qpsk_seq_item::type_id::create("mon_item");
                item.bits_out = vif.mon_cb.bits_out;
                item.valid    = 1'b1;
                ap.write(item);
            end
        end
    endtask

endclass