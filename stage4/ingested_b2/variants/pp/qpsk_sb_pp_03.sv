class qpsk_scoreboard extends uvm_scoreboard;

    uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
    uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

    qpsk_seq_item expected_queue[$];
    qpsk_seq_item observed_queue[$];

    int unsigned errors;

    `uvm_component_utils(qpsk_scoreboard)

    function new(string name = "qpsk_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp_expected = new("ap_imp_expected", this);
        ap_imp_observed = new("ap_imp_observed", this);
        errors = 0;
    endfunction

    function void write_expected(qpsk_seq_item item);
        qpsk_seq_item item_copy;
        if (item == null) begin
            errors++;
            return;
        end

        item_copy = qpsk_seq_item::type_id::create("expected_item_copy");
        item_copy.copy(item);
        expected_queue.push_back(item_copy);
        compare_available();
    endfunction

    function void write_observed(qpsk_seq_item item);
        qpsk_seq_item item_copy;
        if (item == null) begin
            errors++;
            return;
        end

        item_copy = qpsk_seq_item::type_id::create("observed_item_copy");
        item_copy.copy(item);
        observed_queue.push_back(item_copy);
        compare_available();
    endfunction

    function void compare_available();
        qpsk_seq_item expected_item;
        qpsk_seq_item observed_item;

        while ((expected_queue.size() != 0) &&
               (observed_queue.size() != 0)) begin
            expected_item = expected_queue.pop_front();
            observed_item = observed_queue.pop_front();

            if (observed_item.bits_out !== expected_item.bits) begin
                errors++;
            end
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        compare_available();

        if (expected_queue.size() != 0) begin
            errors += expected_queue.size();
            expected_queue.delete();
        end

        if (observed_queue.size() != 0) begin
            errors += observed_queue.size();
            observed_queue.delete();
        end

        if (errors == 0)
            $display("[RESULT] PASS");
        else
            $display("[RESULT] FAIL errors=%0d", errors);
    endfunction

endclass