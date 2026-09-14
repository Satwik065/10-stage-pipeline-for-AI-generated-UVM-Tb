class qpsk_scoreboard extends uvm_scoreboard;
`uvm_component_utils(qpsk_scoreboard)

uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

bit [1:0] exp_arr [0:39];
int       exp_count = 0;
int       obs_count = 0;
int       errors = 0;
localparam int EXPECTED_COUNT = 40;

function new(string name, uvm_component parent);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
endfunction

function void write_expected(qpsk_seq_item item);
    if (exp_count >= EXPECTED_COUNT) begin
        uvm_error("SCOREBOARD", "expected overflow");
        errors++;
        return;
    end
    exp_arr[exp_count] = item.bits;
    exp_count++;
endfunction

function void write_observed(qpsk_seq_item item);
    if (obs_count >= EXPECTED_COUNT) begin
        uvm_error("SCOREBOARD", "observed overflow");
        errors++;
        return;
    end
    if (item.bits_out !== exp_arr[obs_count]) begin
        uvm_error("SCOREBOARD", $sformatf("symbol mismatch at index %0d: expected %b got %b", obs_count, exp_arr[obs_count], item.bits_out));
        errors++;
    end
    obs_count++;
endfunction

function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (obs_count != exp_count) begin
        int leftover;
        leftover = exp_count - obs_count;
        if (leftover > 0) begin
            uvm_error("SCOREBOARD", $sformatf("%0d expected symbols remaining in queue", leftover));
            errors += leftover;
        end
    end
    if (obs_count != EXPECTED_COUNT) begin
        uvm_error("SCOREBOARD", $sformatf("observed total %0d != expected %0d", obs_count, EXPECTED_COUNT));
        errors++;
    end
    if (errors == 0) begin
        $display("[RESULT] PASS");
    end else begin
        $display("[RESULT] FAIL errors=%0d", errors);
    end
endfunction

endclass