class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

    `uvm_object_utils(qpsk_base_seq)

    function new(string name="qpsk_base_seq");
        super.new(name);
    endfunction

    task body();
        qpsk_seq_item item;
        bit [1:0] pattern [40];
        int idx;

        // Deterministic order: ten each of 00, 01, 10, 11, grouped.
        for (int i = 0; i < 10; i++) begin
            pattern[i]      = 2'b00;
            pattern[10 + i] = 2'b01;
            pattern[20 + i] = 2'b10;
            pattern[30 + i] = 2'b11;
        end

        for (idx = 0; idx < 40; idx++) begin
            `uvm_create(item)
            if (!item.randomize() with { bits == pattern[idx]; })
                `uvm_fatal("QPSK_SEQ", "Randomization failed in qpsk_base_seq")
            `uvm_send(item)
        end
    endtask

endclass