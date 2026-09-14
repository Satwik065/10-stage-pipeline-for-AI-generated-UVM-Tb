class qpsk_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(qpsk_scoreboard)

    uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
    uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

    qpsk_seq_item expected_q[$];
    qpsk_seq_item observed_q[$];

    int unsigned error_count;
    int unsigned checked_count;

    function new(string name = "qpsk_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp_expected = new("ap_imp_expected", this);
        ap_imp_observed = new("ap_imp_observed", this);
        error_count    = 0;
        checked_count  = 0;
    endfunction

    function void write_expected(qpsk_seq_item item);
        qpsk_seq_item exp_item;
        if (item == null) begin
            `uvm_error("QPSK_SB", "write_expected received null item")
            return;
        end
        exp_item = qpsk_seq_item::type_id::create("exp_item");
        exp_item.copy(item);
        expected_q.push_back(exp_item);
    endfunction

    function void write_observed(qpsk_seq_item item);
        qpsk_seq_item obs_item;
        if (item == null) begin
            `uvm_error("QPSK_SB", "write_observed received null item")
            return;
        end
        obs_item = qpsk_seq_item::type_id::create("obs_item");
        obs_item.copy(item);
        observed_q.push_back(obs_item);
    endfunction

    function void check_phase(uvm_phase phase);
        qpsk_seq_item exp_item;
        qpsk_seq_item obs_item;

        super.check_phase(phase);

        while (expected_q.size() > 0 && observed_q.size() > 0) begin
            exp_item = expected_q.pop_front();
            obs_item = observed_q.pop_front();
            checked_count++;
            if (obs_item.bits_out !== exp_item.bits) begin
                error_count++;
                `uvm_error("QPSK_SB",
                    $sformatf("Symbol mismatch: expected bits=%0b, observed bits_out=%0b (error #%0d of %0d checked)",
                              exp_item.bits, obs_item.bits_out, error_count, checked_count))
            end
        end

        while (expected_q.size() > 0) begin
            void'(expected_q.pop_front());
            error_count++;
            `uvm_error("QPSK_SB",
                $sformatf("Missing observed symbol for expected bits (error #%0d)", error_count))
        end

        while (observed_q.size() > 0) begin
            obs_item = observed_q.pop_front();
            error_count++;
            `uvm_error("QPSK_SB",
                $sformatf("Extra observed symbol bits_out=%0b with no matching expected symbol (error #%0d)",
                          obs_item.bits_out, error_count))
        end

        if (error_count == 0) begin
            `uvm_info("QPSK_SB", "[RESULT] PASS", UVM_NONE)
        end
        else begin
            `uvm_info("QPSK_SB", $sformatf("[RESULT] FAIL errors=%0d", error_count), UVM_NONE)
        end
    endfunction

endclass