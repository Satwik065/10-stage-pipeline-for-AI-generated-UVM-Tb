class qpsk_scoreboard extends uvm_scoreboard;

`uvm_component_utils(qpsk_scoreboard)

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

qpsk_seq_item expected_q[$];
int           errors = 0;
int           observed_total = 0;
localparam int EXPECTED_COUNT = 40;

function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
endfunction

function void write_expected(qpsk_seq_item item);
    expected_q.push_back(item);
endfunction

function void compare_symbols(bit [1:0] exp, bit [1:0] got, int idx);
    if (got !== exp) begin
        errors++;
        `uvm_error("QPSK_SCB",
            $sformatf("symbol index %0d: expected=%2b got=%2b",
                      idx, exp, got))
    end
endfunction

function void write_observed(qpsk_seq_item item);
    qpsk_seq_item exp;
    int idx;

    observed_total++;
    idx = observed_total;

    if (expected_q.size() == 0) begin
        errors++;
        `uvm_error("QPSK_SCB",
            $sformatf("unexpected valid_out #%0d", idx))
    end
    else begin
        exp = expected_q.pop_front();
        compare_symbols(exp.bits, item.bits_out, idx);
    end
endfunction

function void check_phase(uvm_phase phase);
    int leftover;

    super.check_phase(phase);

    leftover = expected_q.size();

    if (leftover != 0) begin
        errors += leftover;
        `uvm_error("QPSK_SCB",
            $sformatf("%0d expected symbols remain in queue", leftover))
    end

    if (observed_total != EXPECTED_COUNT) begin
        errors++;
        `uvm_error("QPSK_SCB",
            $sformatf("observed_total=%0d expected=%0d",
                      observed_total, EXPECTED_COUNT))
    end

    if (errors == 0) $display("[RESULT] PASS");
    else             $display("[RESULT] FAIL errors=%0d", errors);
endfunction

endclass