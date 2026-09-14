class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

virtual task body();
    qpsk_seq_item req;
    bit [1:0] symbols[4];
    int round;
    int i;

    symbols[0] = 2'b00;
    symbols[1] = 2'b01;
    symbols[2] = 2'b10;
    symbols[3] = 2'b11;

    for (round = 0; round < 10; round++) begin
        for (i = 0; i < 4; i++) begin
            `uvm_do_with(req, { req.bits == symbols[i]; })
        end
    end
endtask

endclass