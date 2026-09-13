
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_observed)

class qpsk_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(qpsk_scoreboard)

    uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
    uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

    qpsk_seq_item expected_q[$];
    int           errors = 0;
    int           observed_total = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_imp_expected = new("ap_imp_expected", this);
        ap_imp_observed = new("ap_imp_observed", this);
    endfunction

    function void write_expected(qpsk_seq_item item);
        expected_q.push_back(item);
    endfunction

    function void write_observed(qpsk_seq_item item);
        qpsk_seq_item exp;            // declared at top — Verilator requirement
        observed_total++;
        if (expected_q.size() == 0) begin
            errors++;
            `uvm_error("SB", $sformatf(
                "unexpected valid_out #%0d, no expected symbol queued",
                observed_total))
            return;
        end
        exp = expected_q.pop_front();
        if (item.bits_out !== exp.bits) begin
            errors++;
            `uvm_error("SB", $sformatf(
                "symbol %0d mismatch: expected %b got %b",
                observed_total, exp.bits, item.bits_out))
        end
    endfunction

    function void check_phase(uvm_phase phase);
        int leftover;                 // declared at top — Verilator requirement
        super.check_phase(phase);
        leftover = expected_q.size();
        if (leftover > 0) begin
            errors += leftover;
            `uvm_error("SB", $sformatf(
                "%0d expected symbol(s) never observed", leftover))
        end
        if (observed_total != 40) begin
            errors++;
            `uvm_error("SB", $sformatf(
                "observed %0d valid_outs, expected 40", observed_total))
        end
        if (errors == 0)
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", errors);
    endfunction
endclass