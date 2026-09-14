class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);

`uvm_object_utils(qpsk_base_seq)

function new(string name = "qpsk_base_seq");
    super.new(name);
endfunction

virtual task body();
    bit [1:0] patt [0:39];
    qpsk_seq_item req;
    int i;

    patt[0]  = 2'b00;
    patt[1]  = 2'b01;
    patt[2]  = 2'b10;
    patt[3]  = 2'b11;
    patt[4]  = 2'b00;
    patt[5]  = 2'b10;
    patt[6]  = 2'b11;
    patt[7]  = 2'b01;
    patt[8]  = 2'b10;
    patt[9]  = 2'b00;
    patt[10] = 2'b11;
    patt[11] = 2'b01;
    patt[12] = 2'b00;
    patt[13] = 2'b11;
    patt[14] = 2'b01;
    patt[15] = 2'b10;
    patt[16] = 2'b11;
    patt[17] = 2'b10;
    patt[18] = 2'b00;
    patt[19] = 2'b01;
    patt[20] = 2'b01;
    patt[21] = 2'b00;
    patt[22] = 2'b10;
    patt[23] = 2'b11;
    patt[24] = 2'b10;
    patt[25] = 2'b11;
    patt[26] = 2'b01;
    patt[27] = 2'b00;
    patt[28] = 2'b11;
    patt[29] = 2'b00;
    patt[30] = 2'b01;
    patt[31] = 2'b10;
    patt[32] = 2'b00;
    patt[33] = 2'b10;
    patt[34] = 2'b01;
    patt[35] = 2'b11;
    patt[36] = 2'b11;
    patt[37] = 2'b01;
    patt[38] = 2'b10;
    patt[39] = 2'b00;

    for (i = 0; i < 40; i++) begin
        req = qpsk_seq_item::type_id::create("req");
        start_item(req);
        req.bits = patt[i];
        finish_item(req);
    end
endtask

endclass