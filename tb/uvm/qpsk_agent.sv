class qpsk_agent extends uvm_agent;
    `uvm_component_utils(qpsk_agent)

    qpsk_driver                    drv;
    uvm_sequencer #(qpsk_seq_item) seqr;
    qpsk_monitor                   mon;

    // NOTE: typed as uvm_analysis_export, not uvm_analysis_port, as
    // given in the original spec. mon.ap is a real analysis_port
    // (producer); a port cannot legally .connect() to another port --
    // only to something that implements write() (an export or imp).
    // An export both accepts the monitor's port on one side and can
    // itself be .connect()-chained onward to the scoreboard's imp in
    // qpsk_env, which is the standard UVM agent-proxies-monitor-port
    // pattern.
    uvm_analysis_export #(qpsk_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = qpsk_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv  = qpsk_driver::type_id::create("drv", this);
            seqr = uvm_sequencer#(qpsk_seq_item)::type_id::create("seqr", this);
        end
        ap = new("ap", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon.ap.connect(ap);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass