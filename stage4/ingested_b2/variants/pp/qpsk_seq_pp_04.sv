class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        qpsk_seq_item req;
        bit [1:0]       sym;

        repeat (10) begin : repeat_loop
            for (int s = 0; s < 4; s++) begin : sym_loop
                sym = s[1:0];

                req = qpsk_seq_item::type_id::create($sformatf("qpsk_req_%0d", s));
                start_item(req);
                if (!req.randomize() with { bits == sym; }) begin
                    `uvm_fatal(get_type_name(), "randomize failed for qpsk_seq_item")
                end
                finish_item(req);
            end
        end
    endtask : body

endclass