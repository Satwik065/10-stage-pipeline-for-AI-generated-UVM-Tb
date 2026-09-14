class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

task automatic emit_one(bit [1:0] sym);
    qpsk_seq_item req;
    req = qpsk_seq_item::type_id::create("req");
    start_item(req);
    req.bits = sym;
    finish_item(req);
endtask

virtual task body();
    int i;
    int j;
    bit [1:0] symbols[3:0];

    symbols[0] = 2'b00;
    symbols[1] = 2'b10;
    symbols[2] = 2'b01;
    symbols[3] = 2'b11;

    for (i = 0; i < 10; i++) begin
        for (j = 0; j < 4; j++) begin
            emit_one(symbols[j]);
        end
    end
endtask

endclass