class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

virtual task body();
    int r;
    int i;
    bit [1:0] sym_arr [3:0];

    sym_arr[0] = 2'b00;
    sym_arr[1] = 2'b01;
    sym_arr[2] = 2'b10;
    sym_arr[3] = 2'b11;

    for (r = 0; r < 10; r++) begin
        for (i = 0; i < 4; i++) begin
            start_item(req);
            req.bits = sym_arr[i];
            finish_item(req);
        end
    end
endtask
endclass