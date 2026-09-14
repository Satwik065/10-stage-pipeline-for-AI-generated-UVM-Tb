class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

task body();
    qpsk_seq_item req;
    bit [1:0] symbols[4];
    int round;
    int i;

    symbols[0] = 2'b11;
    symbols[1] = 2'b10;
    symbols[2] = 2'b01;
    symbols[3] = 2'b00;

    for (round = 0; round < 10; round++) begin
        for (i = 0; i < 4; i++) begin
            start_item(req);
            req.bits = symbols[i];
            finish_item(req);
        end
    end
endtask

endclass
