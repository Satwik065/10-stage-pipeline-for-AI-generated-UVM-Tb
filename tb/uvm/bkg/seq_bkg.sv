class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction

    task body();
        // Deterministic envelope: (00,01,10,11) × 10 rounds = 40 symbols
        for (int round = 0; round < 10; round++) begin
            for (int sym = 0; sym < 4; sym++) begin
                qpsk_seq_item req =
                    qpsk_seq_item::type_id::create("req");
                start_item(req);
                req.bits = sym[1:0];
                finish_item(req);
            end
        end
    endtask
endclass