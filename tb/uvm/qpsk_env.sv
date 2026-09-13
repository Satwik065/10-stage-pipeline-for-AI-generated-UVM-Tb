class qpsk_env extends uvm_env;
    `uvm_component_utils(qpsk_env)

    qpsk_agent      agent;
    qpsk_scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = qpsk_agent::type_id::create("agent", this);
        scb   = qpsk_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.ap.connect(scb.ap_imp_observed);
        agent.ap_expected.connect(scb.ap_imp_expected);
    endfunction
endclass