class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item);
    `uvm_object_utils(qpsk_base_seq)

    function new(string name = "qpsk_base_seq");
        super.new(name);
    endfunction

    task body();
        qpsk_seq_item req;
        bit [1:0]      sym;

        for (int s = 0; s < 4; s++) begin
            sym = s[1:0];
            repeat (10) begin
                req = qpsk_seq_item::type_id::create("req");
                start_item(req);
                if (!req.randomize() with { bits == sym; }) begin
                    `uvm_error(get_type_name(), "Randomization failed for QPSK symbol")
                end
                finish_item(req);
            end
        end
    endtask
endclass