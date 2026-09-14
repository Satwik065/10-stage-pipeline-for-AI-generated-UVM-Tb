class qpsk_scoreboard extends uvm_scoreboard; `uvm_component_utils(qpsk_scoreboard)


uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

protected qpsk_seq_item expected_queue[$];
protected int error_count = 0;

function new(string name, uvm_component parent = null);
    super.new(name, parent);
    ap_imp_expected = new("ap_imp_expected", this);
    ap_imp_observed = new("ap_imp_observed", this);
endfunction

function void write_expected(qpsk_seq_item item);
    qpsk_seq_item clone;
    $cast(clone, item.clone());
    expected_queue.push_back(clone);
endfunction

function void write_observed(qpsk_seq_item item);
    if (item.valid) begin
        if (expected_queue.size() > 0) begin
            qpsk_seq_item exp = expected_queue.pop_front();
            if (exp.bits !== item.bits_out) begin
                error_count++;
                `uvm_error("SCOREBOARD", $sformatf("Mismatch! Expected: %b, Observed: %b", exp.bits, item.bits_out))
            end
        end else begin
            error_count++;
            `uvm_error("SCOREBOARD", "Unexpected observation with no corresponding expected item")
        end
    end
endfunction

function void check_phase(uvm_phase phase);
    if (expected_queue.size() > 0) begin
        error_count += expected_queue.size();
        `uvm_error("SCOREBOARD", $sformatf("Queue not empty at end of test. Leftover items: %0d", expected_queue.size()))
    end

    if (error_count == 0) begin
        $display("[RESULT] PASS");
    end else begin
        $display("[RESULT] FAIL errors=%0d", error_count);
    end
endfunction
endclass