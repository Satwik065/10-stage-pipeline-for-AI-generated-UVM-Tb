class qpsk_base_seq extends uvm_sequence #(qpsk_seq_item); `uvm_object_utils(qpsk_base_seq)

function new(string name=”qpsk_base_seq”); super.new(name); endfunction

virtual task body(); qpsk_seq_item item; repeat (10) begin item = qpsk_seq_item::type_id::create(“item”); start_item(item); item.bits = 2’b00; item.valid = 1; finish_item(item); end repeat (10) begin item = qpsk_seq_item::type_id::create(“item”); start_item(item); item.bits = 2’b01; item.valid = 1; finish_item(item); end repeat (10) begin item = qpsk_seq_item::type_id::create(“item”); start_item(item); item.bits = 2’b10; item.valid = 1; finish_item(item); end repeat (10) begin item = qpsk_seq_item::type_id::create(“item”); start_item(item); item.bits = 2’b11; item.valid = 1; finish_item(item); end endtask : body

endclass : qpsk_base_seq