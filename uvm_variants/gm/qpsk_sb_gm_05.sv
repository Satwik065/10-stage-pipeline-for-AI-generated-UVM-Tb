class qpsk_scoreboard extends uvm_scoreboard;

`uvm_component_utils(qpsk_scoreboard)

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

qpsk_seq_item expected_q[$];
int errors = 0;
int observed_total = 0;
localparam int EXPECTED_COUNT = 40;

function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
endfunction

function void write_expected(qpsk_seq_item item);
    expected_q.push_back(item);
endfunction

function void write_observed(qpsk_seq_item item);
    qpsk_seq_item exp;
    bit [1:0] exp_sym;

    observed_total++;
    if (expected_q.size() == 0) begin
        errors++;
        `uvm_error("UNEXPECTED_VALID_OUT", $sformatf("unexpected valid_out #%0d with bits_out=%0b when expected queue is empty", observed_total, item.bits_out))
    end else begin
        exp = expected_q.pop_front();
        exp_sym = exp.bits;
        case (exp_sym)
            2'b00: if (item.bits_out !== 2'b00) begin errors++; `uvm_error("MISMATCH_SYM00", $sformatf("Symbol index %0d: expected 2'b00, got %0b", observed_total, item.bits_out)) end
            2'b01: if (item.bits_out !== 2'b01) begin errors++; `uvm_error("MISMATCH_SYM01", $sformatf("Symbol index %0d: expected 2'b01, got %0b", observed_total, item.bits_out)) end
            2'b10: if (item.bits_out !== 2'b10) begin errors++; `uvm_error("MISMATCH_SYM10", $sformatf("Symbol index %0d: expected 2'b10, got %0b", observed_total, item.bits_out)) end
            2'b11: if (item.bits_out !== 2'b11) begin errors++; `uvm_error("MISMATCH_SYM11", $sformatf("Symbol index %0d: expected 2'b11, got %0b", observed_total, item.bits_out)) end
        endcase
    end
endfunction

function void check_phase(uvm_phase phase);
    int leftover_count;

    super.check_phase(phase);
    leftover_count = expected_q.size();
    if (leftover_count > 0) begin
        errors += leftover_count;
        `uvm_error("LEFTOVER_EXPECTED", $sformatf("Queue has %0d expected symbols remaining at check_phase", leftover_count))
    end
    if (observed_total != EXPECTED_COUNT) begin
        errors++;
        `uvm_error("COUNT_MISMATCH", $sformatf("observed_total %0d does not match EXPECTED_COUNT %0d", observed_total, EXPECTED_COUNT))
    end

    if (errors == 0)
        $display("[RESULT] PASS");
    else
        $display("[RESULT] FAIL errors=%0d", errors);
endfunction
endclass