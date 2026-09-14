class qpsk_scoreboard extends uvm_scoreboard;
`uvm_component_utils(qpsk_scoreboard)

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

bit [1:0] expected_q[$];
int       errors = 0;
int       observed_total = 0;
localparam int EXPECTED_COUNT = 40;

function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
endfunction

function void write_expected(qpsk_seq_item item);
    expected_q.push_back(item.bits);
endfunction

function void write_observed(qpsk_seq_item item);
    bit [1:0] exp_sym;
    observed_total++;
    if (expected_q.size() == 0) begin
        errors++;
        `uvm_error("UNEXPECTED", $sformatf("unexpected valid_out #%0d", observed_total))
    end else begin
        exp_sym = expected_q.pop_front();
        if (item.bits_out !== exp_sym) begin
            errors++;
            `uvm_error("MISMATCH", $sformatf("symbol index %0d: expected %b, got %b", observed_total, exp_sym, item.bits_out))
        end
    end
endfunction

function void check_phase(uvm_phase phase);
    int leftover;
    super.check_phase(phase);
    leftover = expected_q.size();
    if (leftover > 0) begin
        errors += leftover;
        `uvm_error("MISSING", $sformatf("%0d expected symbols remaining in queue", leftover))
    end
    if (observed_total != EXPECTED_COUNT) begin
        errors++;
        `uvm_error("COUNT_MISMATCH", $sformatf("observed_total=%0d, expected=%0d", observed_total, EXPECTED_COUNT))
    end
    if (errors == 0) begin
        $display("[RESULT] PASS");
    end else begin
        $display("[RESULT] FAIL errors=%0d", errors);
    end
endfunction

endclass