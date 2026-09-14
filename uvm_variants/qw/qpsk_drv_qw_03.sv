class qpsk_driver extends uvm_driver #(qpsk_seq_item);
    `uvm_component_utils(qpsk_driver)
virtual qpsk_dut_if vif;
bit [31:0] ch_seed = 32'hDEADBEEF;
uvm_analysis_port #(qpsk_seq_item) ap_expected;
function new(string name = "qpsk_driver", uvm_component parent = null);
super.new(name, parent);
ap_expected = new("ap_expected", this);
endfunction : new
function void build_phase(uvm_phase phase);
super.build_phase(phase);
if (!uvm_config_db#(virtual qpsk_dut_if)::get(this, "", "vif", vif)) begin
uvm_fatal(get_type_name(), "no vif in config_db");
end
void'(uvm_config_db#(bit [31:0])::get(this, "", "ch_seed", ch_seed));
endfunction : build_phase
task automatic publish_expected(bit [1:0] sym);
qpsk_seq_item exp_item;
exp_item = qpsk_seq_item::type_id::create("exp_item");
exp_item.bits = sym;
ap_expected.write(exp_item);
endtask : publish_expected
task run_phase(uvm_phase phase);
qpsk_seq_item req;
phase.raise_objection(this);
wait (vif.rst == 1'b0);
@(vif.drv_cb);
vif.drv_cb.ch_seed <= ch_seed;
while (1) begin
seq_item_port.get_next_item(req);
@(vif.drv_cb);
vif.drv_cb.valid_in <= 1'b1;
vif.drv_cb.bits_in <= req.bits;
@(vif.drv_cb);
vif.drv_cb.valid_in <= 1'b0;
vif.drv_cb.bits_in <= 2'b00;
publish_expected(req.bits);
repeat (2) @(vif.drv_cb);
seq_item_port.item_done();
end
phase.drop_objection(this);
endtask : run_phase
endclass
