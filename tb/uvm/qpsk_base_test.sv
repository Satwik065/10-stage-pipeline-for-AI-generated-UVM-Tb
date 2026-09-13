class qpsk_base_test extends uvm_test;
    `uvm_component_utils(qpsk_base_test)

    qpsk_env    env;
    bit [31:0]  ch_seed = 32'hDEADBEEF;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'($value$plusargs("CHSEED=%d", ch_seed));
        uvm_config_db#(bit [31:0])::set(this, "*", "ch_seed", ch_seed);
        env = qpsk_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        qpsk_base_seq seq;
        phase.raise_objection(this);
        seq = qpsk_base_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask

endclass