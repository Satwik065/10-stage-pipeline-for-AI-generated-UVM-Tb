class qpsk_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(qpsk_scoreboard)

    uvm_analysis_imp_expected #(qpsk_seq_item, qpsk_scoreboard) ap_imp_expected;
    uvm_analysis_imp_observed #(qpsk_seq_item, qpsk_scoreboard) ap_imp_observed;

    local qpsk_seq_item expected_q[$];
    local int unsigned error_count;

    function new(string name = "qpsk_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ap_imp_expected = new("ap_imp_expected", this);
        ap_imp_observed = new("ap_imp_observed", this);
        error_count = 0;
    endfunction

    virtual function void write_expected(qpsk_seq_item item);
        qpsk_seq_item exp_item;
        if (item == null) begin
            `uvm_error(get_type_name(), "Received null expected item")
            return;
        end
        exp_item = qpsk_seq_item::type_id::create("exp_item");
        exp_item.copy(item);
        expected_q.push_back(exp_item);
    endfunction

    virtual function void write_observed(qpsk_seq_item item);
        qpsk_seq_item exp_item;
        if (item == null) begin
            `uvm_error(get_type_name(), "Received null observed item")
            error_count++;
            return;
        end
        if (expected_q.size() == 0) begin
            `uvm_error(get_type_name(), "Observed symbol with no expected symbol pending")
            error_count++;
            return;
        end
        exp_item = expected_q.pop_front();
        if (item.bits_out !== exp_item.bits) begin
            `uvm_error(get_type_name(), $sformatf("Symbol mismatch: expected 2'b%0b, observed 2'b%0b", exp_item.bits, item.bits_out))
            error_count++;
        end
    endfunction

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (expected_q.size() != 0) begin
            `uvm_error(get_type_name(), $sformatf("%0d expected symbols were never observed", expected_q.size()))
            error_count += expected_q.size();
            expected_q.delete();
        end
        if (error_count == 0) begin
            `uvm_info(get_type_name(), "[RESULT] PASS", UVM_LOW)
        end
        else begin
            `uvm_info(get_type_name(), $sformatf("[RESULT] FAIL errors=%0d", error_count), UVM_LOW)
        end
    endfunction

endclass