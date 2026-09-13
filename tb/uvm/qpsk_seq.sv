class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction

    task body();
        // STAGE 2 STUB: empty. Stage 4 fills in the actual stimulus
        // generation (randomized qpsk_seq_item transactions).
    endtask

endclass