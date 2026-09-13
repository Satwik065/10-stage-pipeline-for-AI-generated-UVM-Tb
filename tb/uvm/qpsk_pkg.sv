package qpsk_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Frozen contract — referenced by relative path, do NOT copy
    `include "../../contract/qpsk_seq_item.sv"

    // Forward declarations: qpsk_agent/qpsk_env/qpsk_base_test below
    // reference qpsk_driver/qpsk_scoreboard/qpsk_base_seq as member
    // types before those classes are `include`d later in this file.
    // Without these, the compile fails with "type not found" the
    // moment agent/env/base_test are parsed. Kept here rather than
    // reordering the includes, since the stub-vs-scaffolding include
    // order below is intentional (driver/seq/scoreboard are Stage 4
    // fill-ins, listed last on purpose).
    typedef class qpsk_driver;
    typedef class qpsk_base_seq;
    typedef class qpsk_scoreboard;

    // Stage 2 scaffolding
    `include "qpsk_monitor.sv"
    `include "qpsk_agent.sv"
    `include "qpsk_env.sv"
    `include "qpsk_base_test.sv"

    // Stage 4 logic placeholders — stubs for now, overwritten at Stage 4
    `include "qpsk_driver.sv"
    `include "qpsk_seq.sv"
    `include "qpsk_scoreboard.sv"
endpackage