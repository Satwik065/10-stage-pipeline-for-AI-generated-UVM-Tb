class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
    `uvm_object_utils(qpsk_base_seq)

    localparam int unsigned NUM_PER_SYM = 10;
    bit [1:0] patterns [4] = '{2'b00, 2'b01, 2'b10, 2'b11};

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction : new

    task body();
        qpsk_seq_item req;
        for (int i = 0; i < 4; i++) begin
            repeat (NUM_PER_SYM) begin
                `uvm_do_with(req, { req.bits == patterns[i]; })
            end
        end
    endtask : body
endclass