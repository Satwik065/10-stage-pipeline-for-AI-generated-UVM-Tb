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

task body();
    int r;
    int i;
    bit [1:0] sym_table[4];

    sym_table[0] = 2'b00;
    sym_table[1] = 2'b10;
    sym_table[2] = 2'b01;
    sym_table[3] = 2'b11;

    for (r = 0; r < 10; r++) begin
        for (i = 0; i < 4; i++) begin
            emit_one(sym_table[i]);
        end
    end
endtask
endclass