// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals

#include "verilated_vcd_c.h"
#include "Vtb_qpsk__Syms.h"


void Vtb_qpsk___024root__trace_chg_0_sub_0(Vtb_qpsk___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_qpsk___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root__trace_chg_0\n"); );
    // Body
    Vtb_qpsk___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_qpsk___024root*>(voidSelf);
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    Vtb_qpsk___024root__trace_chg_0_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_qpsk___024root__trace_chg_0_sub_0(Vtb_qpsk___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root__trace_chg_0_sub_0\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 0);
    if (VL_UNLIKELY(((vlSelfRef.__Vm_traceActivity[1U] 
                      | vlSelfRef.__Vm_traceActivity[2U])))) {
        bufp->chgBit(oldp+0,(vlSelfRef.tb_qpsk__DOT__rst));
        bufp->chgBit(oldp+1,(vlSelfRef.tb_qpsk__DOT__valid_in));
        bufp->chgCData(oldp+2,(vlSelfRef.tb_qpsk__DOT__bits_in),2);
        bufp->chgIData(oldp+3,(vlSelfRef.tb_qpsk__DOT__errors),32);
        bufp->chgIData(oldp+4,(vlSelfRef.tb_qpsk__DOT__k),32);
        bufp->chgCData(oldp+5,(vlSelfRef.tb_qpsk__DOT__pattern[0]),2);
        bufp->chgCData(oldp+6,(vlSelfRef.tb_qpsk__DOT__pattern[1]),2);
        bufp->chgCData(oldp+7,(vlSelfRef.tb_qpsk__DOT__pattern[2]),2);
        bufp->chgCData(oldp+8,(vlSelfRef.tb_qpsk__DOT__pattern[3]),2);
        bufp->chgCData(oldp+9,(vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym),2);
    }
    if (VL_UNLIKELY((vlSelfRef.__Vm_traceActivity[3U]))) {
        bufp->chgBit(oldp+10,(vlSelfRef.tb_qpsk__DOT__mod_valid));
        bufp->chgCData(oldp+11,(vlSelfRef.tb_qpsk__DOT__mod_i),8);
        bufp->chgCData(oldp+12,(vlSelfRef.tb_qpsk__DOT__mod_q),8);
        bufp->chgBit(oldp+13,(vlSelfRef.tb_qpsk__DOT__demod_valid));
        bufp->chgCData(oldp+14,(vlSelfRef.tb_qpsk__DOT__bits_out),2);
    }
    bufp->chgBit(oldp+15,(vlSelfRef.tb_qpsk__DOT__clk));
}

void Vtb_qpsk___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root__trace_cleanup\n"); );
    // Body
    Vtb_qpsk___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_qpsk___024root*>(voidSelf);
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    vlSymsp->__Vm_activity = false;
    vlSymsp->TOP.__Vm_traceActivity[0U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[1U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[2U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[3U] = 0U;
}
