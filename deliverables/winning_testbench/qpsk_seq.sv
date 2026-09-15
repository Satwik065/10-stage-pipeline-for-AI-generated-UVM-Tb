class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

`uvm_object_utils(qpsk_base_seq)

qpsk_seq_item req;

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

task automatic emit_one(bit [1:0] sym);
    req = qpsk_seq_item::type_id::create("req");
    start_item(req);
    req.bits = sym;
    finish_item(req);
endtask

task body();
    int round;

    for (round = 0; round < 10; round++) begin
        emit_one(2'b00);
        emit_one(2'b10);
        emit_one(2'b01);
        emit_one(2'b11);
    end
endtask

endclass