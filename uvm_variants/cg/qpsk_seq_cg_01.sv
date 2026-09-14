class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

task body();
    qpsk_seq_item req;
    int round;
    int sym_idx;
    bit [1:0] symbol;

    for (round = 0; round < 10; round++) begin
        for (sym_idx = 0; sym_idx < 4; sym_idx++) begin
            start_item(req);

            case (sym_idx)
                0: symbol = 2'b00;
                1: symbol = 2'b01;
                2: symbol = 2'b10;
                3: symbol = 2'b11;
            endcase

            req.bits = symbol;
            finish_item(req);
        end
    end
endtask

endclass