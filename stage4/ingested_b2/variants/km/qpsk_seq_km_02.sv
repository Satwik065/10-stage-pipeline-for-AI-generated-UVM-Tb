class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        qpsk_seq_item item;
        static bit [1:0] sym_order [4] = '{2'b00, 2'b01, 2'b10, 2'b11};
        for (int sym = 0; sym < 4; sym++) begin
            for (int rep = 0; rep < 10; rep++) begin
                `uvm_do_with(item, { bits == sym_order[sym]; })
            end
        end
    endtask

endclass