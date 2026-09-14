class qpsk_scoreboard extends uvm_scoreboard; qpsk_seq_item expected_q[int]; qpsk_seq_item observed_q[int]; int expected_count = 0; int observed_count = 0; int errors = 0;


`uvm_component_utils(qpsk_scoreboard)

function new(string name, uvm_component parent = null);
    super.new(name, parent);
endfunction

function void write_expected(qpsk_seq_item item);
    // Make a copy to avoid issues with object sharing across analysis ports
    expected_q[expected_count++] = item.clone();
endfunction

function void write_observed(qpsk_seq_item item);
    // Make a copy to avoid issues with object sharing across analysis ports
    observed_q[observed_count++] = item.clone();
endfunction

virtual task check_phase(uvm_phase phase);
    super.check_phase(phase);
    string verdict = "PASS";
    int num_to_check = (expected_count < observed_count) ? expected_count : observed_count;

    for (int i = 0; i < num_to_check; i++)
    begin
        if (expected_q[i].valid != observed_q[i].valid) begin
            errors++;
            `uvm_error("SB", $sformatf("Mismatch on valid for item %0d: expected=%0b, observed=%0b", i, expected_q[i].valid, observed_q[i].valid));
        end
        if (expected_q[i].valid && observed_q[i].valid) begin
            if (expected_q[i].bits != observed_q[i].bits_out) begin
                errors++;
                `uvm_error("SB", $sformatf("Mismatch on bits for item %0d: expected=%0b, observed=%0b", i, expected_q[i].bits, observed_q[i].bits_out));
            end
        end
    end

    if (expected_count != observed_count) begin
        errors += $abs(expected_count - observed_count);
        `uvm_warning("SB", $sformatf("Number of expected items (%0d) does not match number of observed items (%0d)", expected_count, observed_count));
    end

    if (errors > 0) begin
        verdict = $sformatf("FAIL errors=%0d", errors);
    end

    `uvm_info("SB", $sformatf("Check phase complete. Expected: %0d, Observed: %0d", expected_count, observed_count), UVM_MEDIUM);
    $display("[RESULT] %s", verdict);
endtask
endclass