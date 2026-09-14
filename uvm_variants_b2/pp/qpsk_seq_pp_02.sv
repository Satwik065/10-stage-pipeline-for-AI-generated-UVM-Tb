class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        qpsk_seq_item req;
        bit [1:0] syms[] = '{2'b00, 2'b01, 2'b10, 2'b11};

        // 10 iterations x 4 symbols = exactly 40 items.
        // Fixed order per iteration: 00, 01, 10, 11.
        repeat (10) begin
            foreach (syms[i]) begin
                req = qpsk_seq_item::type_id::create($sformatf("qpsk_req_%0d", i));
                start_item(req);
                if (!req.randomize() with { bits == syms[i]; })
                    `uvm_fatal(get_type_name(), "qpsk_base_seq: randomization failed")
                finish_item(req);
            end
        end
    endtask : body
endclass