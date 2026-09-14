class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction

    task body();
        qpsk_seq_item req;
        bit [1:0] sym_order [4] = '{2'b00, 2'b01, 2'b10, 2'b11};
        int unsigned rep;

        for (int unsigned s = 0; s < 4; s++) begin
            for (rep = 0; rep < 10; rep++) begin
                `uvm_do_with(req, { bits == sym_order[s]; })
            end
        end
    endtask

endclass