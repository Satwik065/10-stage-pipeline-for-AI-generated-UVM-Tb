//----------------------------------------------------------------------
// qpsk_pkg.sv — UVM package for the QPSK loopback TB.
//
// Include order is load-bearing. Verilator 5.053 is single-pass on
// `::` references: a class that names AnotherClass::type_id must have
// seen AnotherClass first. Order: contract item, then leaves, then
// composites.
//----------------------------------------------------------------------
package qpsk_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Fix#1: analysis imp_decl macros must be visible to qpsk_scoreboard.
    // Declaring them here, before any class, puts them in the package scope.
    `uvm_analysis_imp_decl(_expected)
    `uvm_analysis_imp_decl(_observed)

    // 1. Frozen contract — relative path, do not copy
    `include "../../contract/qpsk_seq_item.sv"

    // 2. Leaf logic components (referenced by composites below)
    `include "qpsk_monitor.sv"
    `include "qpsk_driver.sv"
    `include "qpsk_seq.sv"
    `include "qpsk_scoreboard.sv"

    // 3. Composites (reference the leaves above)
    `include "qpsk_agent.sv"
    `include "qpsk_env.sv"
    `include "qpsk_base_test.sv"
endpackage