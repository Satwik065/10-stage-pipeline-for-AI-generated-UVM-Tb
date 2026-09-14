class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        qpsk_seq_item req_item;
        bit [1:0] pattern [40];

        // Deterministic order: ten each of 00, 01, 10, 11
        for (int i = 0; i < 40; i++) begin
            pattern[i] = i[1:0];
        end

        for (int i = 0; i < 40; i++) begin
            `uvm_do_with(req_item, { bits == pattern[i]; })
        end
    endtask

endclass