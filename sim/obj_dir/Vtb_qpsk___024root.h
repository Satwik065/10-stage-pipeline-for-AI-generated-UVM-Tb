// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_qpsk.h for the primary calling header

#ifndef VERILATED_VTB_QPSK___024ROOT_H_
#define VERILATED_VTB_QPSK___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb_qpsk__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_qpsk___024root final {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ tb_qpsk__DOT__clk;
    CData/*0:0*/ tb_qpsk__DOT__rst;
    CData/*0:0*/ tb_qpsk__DOT__valid_in;
    CData/*1:0*/ tb_qpsk__DOT__bits_in;
    CData/*0:0*/ tb_qpsk__DOT__mod_valid;
    CData/*7:0*/ tb_qpsk__DOT__mod_i;
    CData/*7:0*/ tb_qpsk__DOT__mod_q;
    CData/*0:0*/ tb_qpsk__DOT__demod_valid;
    CData/*1:0*/ tb_qpsk__DOT__bits_out;
    CData/*1:0*/ tb_qpsk__DOT__run_symbol__Vstatic__sym;
    CData/*0:0*/ __Vtrigprevexpr___TOP__tb_qpsk__DOT__clk__0;
    IData/*31:0*/ tb_qpsk__DOT__errors;
    IData/*31:0*/ tb_qpsk__DOT__k;
    IData/*31:0*/ __Vi;
    VlUnpacked<CData/*1:0*/, 4> tb_qpsk__DOT__pattern;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggeredAcc;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    VlUnpacked<CData/*0:0*/, 4> __Vm_traceActivity;
    VlDelayScheduler __VdlySched;
    VlTriggerScheduler __VtrigSched_ha1ed4730__0;

    // INTERNAL VARIABLES
    Vtb_qpsk__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vtb_qpsk___024root(Vtb_qpsk__Syms* symsp, const char* namep);
    ~Vtb_qpsk___024root();
    VL_UNCOPYABLE(Vtb_qpsk___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
