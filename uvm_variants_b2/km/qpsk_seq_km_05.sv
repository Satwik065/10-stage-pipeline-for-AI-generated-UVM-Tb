class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
    `uvm_object_utils(qpsk_base_seq)

    function new(string name="qpsk_base_seq");
        super.new(name);
    endfunction

    task body();
        qpsk_seq_item req;
        bit [1:0] pattern [40] = '{
            2'b00, 2'b01, 2'b10, 2'b11, 2'b00, 2'b01, 2'b10, 2'b11,
            2'b00, 2'b01, 2'b10, 2'b11, 2'b00, 2'b01, 2'b10, 2'b11,
            2'b00, 2'b01, 2'b10, 2'b11, 2'b00, 2'b01, 2'b10, 2'b11,
            2'b00, 2'b01, 2'b10, 2'b11, 2'b00, 2'b01, 2'b10, 2'b11,
            2'b00, 2'b01, 2'b10, 2'b11, 2'b00, 2'b01, 2'b10, 2'b11
        };

        for (int i = 0; i < 40; i++) begin
            `uvm_create(req)
            start_item(req);
            if (!req.randomize() with { bits == pattern[i]; })
                `uvm_fatal("RAND", "Failed to randomize qpsk_seq_item")
            finish_item(req);
            get_response(req);
        end
    endtask
endclass