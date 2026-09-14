class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

virtual task body();
    int r;
    int i;
    bit [1:0] syms[4];

    syms[0] = 2'b11;
    syms[1] = 2'b10;
    syms[2] = 2'b01;
    syms[3] = 2'b00;

    for (r = 0; r < 10; r++) begin
        for (i = 0; i < 4; i++) begin
            req = qpsk_seq_item::type_id::create("req");
            start_item(req);
            req.bits = syms[i];
            finish_item(req);
        end
    end
endtask
endclass