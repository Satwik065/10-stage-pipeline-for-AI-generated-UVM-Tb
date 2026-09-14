class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

    // Number of items to send for each of the four QPSK symbol values.
    // 4 values * 10 = exactly 40 items total.
    protected int unsigned num_items_per_symbol = 10;

    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction : new

    // Deterministic order: the symbol sequence 00,01,10,11 is repeated
    // num_items_per_symbol times, so each value appears exactly 10 times.
    virtual task body();
        qpsk_seq_item req;
        bit [1:0]     sym;

        for (int i = 0; i < num_items_per_symbol; i++) begin
            for (int s = 0; s < 4; s++) begin
                sym = s[1:0];

                req = qpsk_seq_item::type_id::create(
                          $sformatf("qpsk_req_i%0d_s%0d", i, s));

                start_item(req);
                if (!req.randomize() with { bits == sym; }) begin
                    `uvm_fatal(get_type_name(),
                               "randomize() failed for qpsk_seq_item")
                end
                `uvm_info(get_type_name(),
                          $sformatf("Sending item %0d/40 : bits = 2'b%b",
                                    (i * 4 + s + 1), req.bits),
                          UVM_HIGH)
                finish_item(req);
            end
        end
    endtask : body

endclass : qpsk_base_seq