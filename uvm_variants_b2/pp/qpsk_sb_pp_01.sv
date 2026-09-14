class qpsk_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(qpsk_scoreboard)

    uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
    uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

    bit [1:0] expected_queue[$];
    bit [1:0] observed_queue[$];
    int errors;

    function new(string name = "qpsk_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp_expected = new("ap_imp_expected", this);
        ap_imp_observed = new("ap_imp_observed", this);
        errors = 0;
    endfunction

    function void write_expected(qpsk_seq_item item);
        if (item == null) begin
            errors++;
            return;
        end

        expected_queue.push_back(item.bits);
        compare_queues();
    endfunction

    function void write_observed(qpsk_seq_item item);
        if (item == null) begin
            errors++;
            return;
        end

        if (item.valid)
            observed_queue.push_back(item.bits_out);

        compare_queues();
    endfunction

    function void compare_queues();
        bit [1:0] expected_bits;
        bit [1:0] observed_bits;

        while ((expected_queue.size() > 0) &&
               (observed_queue.size() > 0)) begin
            expected_bits = expected_queue.pop_front();
            observed_bits = observed_queue.pop_front();

            if (expected_bits !== observed_bits)
                errors++;
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        compare_queues();

        if (expected_queue.size() > 0) begin
            errors += expected_queue.size();
            expected_queue.delete();
        end

        if (observed_queue.size() > 0) begin
            errors += observed_queue.size();
            observed_queue.delete();
        end

        if (errors == 0)
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", errors);
    endfunction

endclass