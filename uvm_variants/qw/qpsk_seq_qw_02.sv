class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

task body();
    qpsk_seq_item req;
    int i;

    // Block 1: ten 2'b00
    for (i = 0; i < 10; i++) begin
        start_item(req);
        req.bits = 2'b00;
        finish_item(req);
    end

    // Block 2: ten 2'b01
    for (i = 0; i < 10; i++) begin
        start_item(req);
        req.bits = 2'b01;
        finish_item(req);
    end

    // Block 3: ten 2'b10
    for (i = 0; i < 10; i++) begin
        start_item(req);
        req.bits = 2'b10;
        finish_item(req);
    end

    // Block 4: ten 2'b11
    for (i = 0; i < 10; i++) begin
        start_item(req);
        req.bits = 2'b11;
        finish_item(req);
    end
endtask

endclass