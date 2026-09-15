class qpsk_agent extends uvm_agent;
    `uvm_component_utils(qpsk_agent)

    qpsk_driver                        drv;
    uvm_sequencer #(qpsk_seq_item)     seqr;
    qpsk_monitor                       mon;
    uvm_analysis_port #(qpsk_seq_item) ap;             // monitor output
    uvm_analysis_port #(qpsk_seq_item) ap_expected;    // driver expected

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = qpsk_monitor::type_id::create("mon", this);
        ap  = new("ap", this);
        ap_expected = new("ap_expected", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv  = qpsk_driver::type_id::create("drv", this);
            seqr = uvm_sequencer#(qpsk_seq_item)::type_id::create("seqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
            drv.ap_expected.connect(ap_expected);
        end
    endfunction
endclass