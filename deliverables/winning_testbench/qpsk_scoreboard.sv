class qpsk_scoreboard extends uvm_scoreboard;
`uvm_component_utils(qpsk_scoreboard)

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

bit [1:0] exp_arr [0:39];
int       exp_count = 0;
int       obs_count = 0;
int       errors = 0;
int       observed_total = 0;

localparam int EXPECTED_COUNT = 40;

function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
endfunction

function void write_expected(qpsk_seq_item item);
    if (exp_count >= EXPECTED_COUNT) begin
        `uvm_error("QPSK_SB", "expected overflow")
        errors++;
        return;
    end
    exp_arr[exp_count] = item.bits;
    exp_count++;
endfunction

function void write_observed(qpsk_seq_item item);
    if (obs_count >= EXPECTED_COUNT) begin
        `uvm_error("QPSK_SB", "observed overflow")
        errors++;
        return;
    end

    if (item.bits_out !== exp_arr[obs_count]) begin
        errors++;
        `uvm_error("QPSK_SB",
                   $sformatf("symbol index %0d: expected=%2b got=%2b",
                             obs_count, exp_arr[obs_count], item.bits_out))
    end

    obs_count++;
    observed_total++;
endfunction

function void check_phase(uvm_phase phase);
    int leftover;

    super.check_phase(phase);

    leftover = exp_count - obs_count;
    if (leftover > 0) begin
        errors += leftover;
        `uvm_error("QPSK_SB",
                   $sformatf("leftover expected symbols: %0d", leftover))
    end

    if (obs_count != EXPECTED_COUNT) begin
        errors++;
        `uvm_error("QPSK_SB",
                   $sformatf("observed_total=%0d, expected=%0d",
                             obs_count, EXPECTED_COUNT))
    end

    if (errors == 0) $display("[RESULT] PASS");
    else             $display("[RESULT] FAIL errors=%0d", errors);
endfunction

endclass