class qpsk_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(qpsk_scoreboard)

    uvm_analysis_imp #(qpsk_seq_item, qpsk_scoreboard) ap_imp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(qpsk_seq_item item);
        // STAGE 2 STUB: empty. Stage 4 fills in the actual comparison
        // against the golden reference model.
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
    endfunction

endclass