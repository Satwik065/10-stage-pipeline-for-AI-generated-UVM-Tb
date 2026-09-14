class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

virtual task body();
    bit [1:0] patt [0:39];
    int i;
    qpsk_seq_item req;

    // Deterministic order: 10 of each symbol
    for (i = 0; i < 40; i++) begin
        case (i % 4)
            0: patt[i] = 2'b00;
            1: patt[i] = 2'b01;
            2: patt[i] = 2'b10;
            3: patt[i] = 2'b11;
        endcase
    end

    for (i = 0; i < 40; i++) begin
        start_item(req);
        req.bits = patt[i];
        finish_item(req);
    end
endtask

endclass