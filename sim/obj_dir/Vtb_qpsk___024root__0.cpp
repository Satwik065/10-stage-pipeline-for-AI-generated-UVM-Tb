// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_qpsk.h for the primary calling header

#include "Vtb_qpsk__pch.h"

VlCoroutine Vtb_qpsk___024root___eval_initial__TOP__Vtiming__0(Vtb_qpsk___024root* vlSelf);
VlCoroutine Vtb_qpsk___024root___eval_initial__TOP__Vtiming__1(Vtb_qpsk___024root* vlSelf);

void Vtb_qpsk___024root___eval_initial(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_initial\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    {
        // Inlined CFunc: _eval_initial__TOP
        vlSelfRef.tb_qpsk__DOT__clk = 0U;
    }
    vlSelfRef.__Vm_traceActivity[1U] = 1U;
    Vtb_qpsk___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb_qpsk___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

void Vtb_qpsk___024root___eval_sample(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_sample\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_qpsk___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vtb_qpsk___024root___eval_ico(Vtb_qpsk___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_ico\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_qpsk___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    return (0U);
}

void Vtb_qpsk___024root___timing_ready(Vtb_qpsk___024root* vlSelf);
void Vtb_qpsk___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_qpsk___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vtb_qpsk___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);
void Vtb_qpsk___024root___timing_resume(Vtb_qpsk___024root* vlSelf);

bool Vtb_qpsk___024root___eval_act(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_act\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((vlSelfRef.__VdlySched.awaitingCurrentTime() 
                                                          << 2U) 
                                                         | ((((~ (IData)(vlSelfRef.tb_qpsk__DOT__clk)) 
                                                              & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_qpsk__DOT__clk__0)) 
                                                             << 1U) 
                                                            | ((IData)(vlSelfRef.tb_qpsk__DOT__clk) 
                                                               & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_qpsk__DOT__clk__0)))))));
        vlSelfRef.__Vtrigprevexpr___TOP__tb_qpsk__DOT__clk__0 
            = vlSelfRef.tb_qpsk__DOT__clk;
    }
    Vtb_qpsk___024root___timing_ready(vlSelf);
    Vtb_qpsk___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_qpsk___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vtb_qpsk___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vtb_qpsk___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
    if (__VactExecute) {
        vlSelfRef.__VactTriggeredAcc.fill(0ULL);
        Vtb_qpsk___024root___timing_resume(vlSelf);
    }
    return (__VactExecute);
}

bool Vtb_qpsk___024root___eval_inact(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_inact\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("../tb/tb_qpsk.sv", 9, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

extern const VlUnpacked<CData/*0:0*/, 16> Vtb_qpsk__ConstPool__TABLE_hf99a53e2_0;
extern const VlUnpacked<CData/*7:0*/, 16> Vtb_qpsk__ConstPool__TABLE_h716cb5b4_0;
extern const VlUnpacked<CData/*7:0*/, 16> Vtb_qpsk__ConstPool__TABLE_h1c42072e_0;
void Vtb_qpsk___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out);

bool Vtb_qpsk___024root___eval_nba(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_nba\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vtb_qpsk___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_body__nba
            if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
                {
                    // Inlined CFunc: _nba_sequent__TOP__0
                    CData/*3:0*/ __Vinline_0__eval_body__nba___Vinline_0__nba_sequent__TOP__0___Vtableidx1;
                    __Vinline_0__eval_body__nba___Vinline_0__nba_sequent__TOP__0___Vtableidx1 = 0;
                    vlSelfRef.tb_qpsk__DOT__demod_valid 
                        = ((1U & (~ (IData)(vlSelfRef.tb_qpsk__DOT__rst))) 
                           && (IData)(vlSelfRef.tb_qpsk__DOT__mod_valid));
                    vlSelfRef.tb_qpsk__DOT__bits_out 
                        = ((IData)(vlSelfRef.tb_qpsk__DOT__rst)
                            ? 0U : ((VL_GTS_III(8, 0U, (IData)(vlSelfRef.tb_qpsk__DOT__mod_i)) 
                                     << 1U) | VL_GTS_III(8, 0U, (IData)(vlSelfRef.tb_qpsk__DOT__mod_q))));
                    __Vinline_0__eval_body__nba___Vinline_0__nba_sequent__TOP__0___Vtableidx1 
                        = (((IData)(vlSelfRef.tb_qpsk__DOT__bits_in) 
                            << 2U) | (((IData)(vlSelfRef.tb_qpsk__DOT__valid_in) 
                                       << 1U) | (IData)(vlSelfRef.tb_qpsk__DOT__rst)));
                    vlSelfRef.tb_qpsk__DOT__mod_valid 
                        = Vtb_qpsk__ConstPool__TABLE_hf99a53e2_0
                        [__Vinline_0__eval_body__nba___Vinline_0__nba_sequent__TOP__0___Vtableidx1];
                    vlSelfRef.tb_qpsk__DOT__mod_i = Vtb_qpsk__ConstPool__TABLE_h716cb5b4_0
                        [__Vinline_0__eval_body__nba___Vinline_0__nba_sequent__TOP__0___Vtableidx1];
                    vlSelfRef.tb_qpsk__DOT__mod_q = Vtb_qpsk__ConstPool__TABLE_h1c42072e_0
                        [__Vinline_0__eval_body__nba___Vinline_0__nba_sequent__TOP__0___Vtableidx1];
                }
                vlSelfRef.__Vm_traceActivity[3U] = 1U;
            }
        }
        Vtb_qpsk___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

bool Vtb_qpsk___024root___eval_obs(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_obs\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vtb_qpsk___024root___eval_react(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_react\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vtb_qpsk___024root___eval_postponed(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_postponed\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

void Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0(Vtb_qpsk___024root* vlSelf, const char* __VeventDescription);

VlCoroutine Vtb_qpsk___024root___eval_initial__TOP__Vtiming__0(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ tb_qpsk__DOT__unnamedblk1_1__DOT____Vrepeat0;
    tb_qpsk__DOT__unnamedblk1_1__DOT____Vrepeat0 = 0;
    CData/*1:0*/ __Vtask_tb_qpsk__DOT__run_symbol__0__sym;
    __Vtask_tb_qpsk__DOT__run_symbol__0__sym = 0;
    // Body
    vlSelfRef.tb_qpsk__DOT__rst = 1U;
    vlSelfRef.tb_qpsk__DOT__valid_in = 0U;
    vlSelfRef.tb_qpsk__DOT__bits_in = 0U;
    vlSelfRef.tb_qpsk__DOT__errors = 0U;
    vlSelfRef.tb_qpsk__DOT__pattern[0U] = 0U;
    vlSelfRef.tb_qpsk__DOT__pattern[1U] = 1U;
    vlSelfRef.tb_qpsk__DOT__pattern[2U] = 2U;
    vlSelfRef.tb_qpsk__DOT__pattern[3U] = 3U;
    vlSymsp->_vm_contextp__->dumpfile("tb_qpsk.vcd"s);
    vlSymsp->_traceDumpOpen();
    tb_qpsk__DOT__unnamedblk1_1__DOT____Vrepeat0 = 3U;
    while (VL_LTS_III(32, 0U, tb_qpsk__DOT__unnamedblk1_1__DOT____Vrepeat0)) {
        Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0(vlSelf, 
                                                       "@(negedge tb_qpsk.clk)");
        co_await vlSelfRef.__VtrigSched_ha1ed4730__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_qpsk.clk)", 
                                                             "../tb/tb_qpsk.sv", 
                                                             107);
        vlSelfRef.__Vm_traceActivity[2U] = 1U;
        tb_qpsk__DOT__unnamedblk1_1__DOT____Vrepeat0 
            = (tb_qpsk__DOT__unnamedblk1_1__DOT____Vrepeat0 
               - (IData)(1U));
    }
    vlSelfRef.tb_qpsk__DOT__rst = 0U;
    vlSelfRef.tb_qpsk__DOT__k = 0U;
    while (VL_GTS_III(32, 4U, vlSelfRef.tb_qpsk__DOT__k)) {
        __Vtask_tb_qpsk__DOT__run_symbol__0__sym = vlSelfRef.tb_qpsk__DOT__pattern
            [(3U & vlSelfRef.tb_qpsk__DOT__k)];
        vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym 
            = __Vtask_tb_qpsk__DOT__run_symbol__0__sym;
        Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0(vlSelf, 
                                                       "@(negedge tb_qpsk.clk)");
        co_await vlSelfRef.__VtrigSched_ha1ed4730__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_qpsk.clk)", 
                                                             "../tb/tb_qpsk.sv", 
                                                             67);
        vlSelfRef.__Vm_traceActivity[2U] = 1U;
        vlSelfRef.tb_qpsk__DOT__valid_in = 1U;
        vlSelfRef.tb_qpsk__DOT__bits_in = vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym;
        Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0(vlSelf, 
                                                       "@(negedge tb_qpsk.clk)");
        co_await vlSelfRef.__VtrigSched_ha1ed4730__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_qpsk.clk)", 
                                                             "../tb/tb_qpsk.sv", 
                                                             71);
        vlSelfRef.__Vm_traceActivity[2U] = 1U;
        vlSelfRef.tb_qpsk__DOT__valid_in = 0U;
        Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0(vlSelf, 
                                                       "@(negedge tb_qpsk.clk)");
        co_await vlSelfRef.__VtrigSched_ha1ed4730__0.trigger(0U, 
                                                             nullptr, 
                                                             "@(negedge tb_qpsk.clk)", 
                                                             "../tb/tb_qpsk.sv", 
                                                             74);
        vlSelfRef.__Vm_traceActivity[2U] = 1U;
        if (VL_LIKELY((vlSelfRef.tb_qpsk__DOT__demod_valid))) {
            if (((IData)(vlSelfRef.tb_qpsk__DOT__bits_out) 
                 != (IData)(vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym))) {
                VL_WRITEF_NX("[FAIL] symbol %b: decoded %b (I=%0d Q=%0d)\n",4
                             , '#',2,vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym
                             , '#',2,(IData)(vlSelfRef.tb_qpsk__DOT__bits_out)
                             , '~',8,(IData)(vlSelfRef.tb_qpsk__DOT__mod_i)
                             , '~',8,(IData)(vlSelfRef.tb_qpsk__DOT__mod_q));
                vlSelfRef.tb_qpsk__DOT__errors = ((IData)(1U) 
                                                  + vlSelfRef.tb_qpsk__DOT__errors);
            } else {
                VL_WRITEF_NX("[ OK ] symbol %b -> I=%0d Q=%0d -> decoded %b\n",4
                             , '#',2,vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym
                             , '~',8,(IData)(vlSelfRef.tb_qpsk__DOT__mod_i)
                             , '~',8,(IData)(vlSelfRef.tb_qpsk__DOT__mod_q)
                             , '#',2,(IData)(vlSelfRef.tb_qpsk__DOT__bits_out));
            }
        } else {
            VL_WRITEF_NX("[FAIL] symbol %b: demod valid_out not asserted\n",1
                         , '#',2,vlSelfRef.tb_qpsk__DOT__run_symbol__Vstatic__sym);
            vlSelfRef.tb_qpsk__DOT__errors = ((IData)(1U) 
                                              + vlSelfRef.tb_qpsk__DOT__errors);
        }
        vlSelfRef.tb_qpsk__DOT__k = ((IData)(1U) + vlSelfRef.tb_qpsk__DOT__k);
    }
    if ((0U == vlSelfRef.tb_qpsk__DOT__errors)) {
        VL_WRITEF_NX("PASS: all 4 QPSK loopback symbols decoded correctly\n",0);
    } else {
        VL_WRITEF_NX("FAIL: %0d QPSK loopback error(s) detected\n",1
                     , '~',32,vlSelfRef.tb_qpsk__DOT__errors);
    }
    VL_FINISH_MT("../tb/tb_qpsk.sv", 118, "");
    vlSelfRef.__Vm_traceActivity[2U] = 1U;
    co_return;
}

VlCoroutine Vtb_qpsk___024root___eval_initial__TOP__Vtiming__1(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__VdlySched.delay(0x0000000000001388ULL, 
                                             nullptr, 
                                             "../tb/tb_qpsk.sv", 
                                             59);
        vlSelfRef.tb_qpsk__DOT__clk = (1U & (~ (IData)(vlSelfRef.tb_qpsk__DOT__clk)));
    }
    co_return;
}

bool Vtb_qpsk___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

bool Vtb_qpsk___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vtb_qpsk___024root___timing_ready(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___timing_ready\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((2ULL & vlSelfRef.__VactTriggered[0U])) {
        vlSelfRef.__VtrigSched_ha1ed4730__0.ready("@(negedge tb_qpsk.clk)");
    }
}

void Vtb_qpsk___024root___timing_resume(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___timing_resume\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VtrigSched_ha1ed4730__0.moveToResumeQueue(
                                                          "@(negedge tb_qpsk.clk)");
    vlSelfRef.__VtrigSched_ha1ed4730__0.resume("@(negedge tb_qpsk.clk)");
    if ((4ULL & vlSelfRef.__VactTriggered[0U])) {
        vlSelfRef.__VdlySched.resume();
    }
}

void Vtb_qpsk___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

void Vtb_qpsk___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

void Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0(Vtb_qpsk___024root* vlSelf, const char* __VeventDescription) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root____VbeforeTrig_ha1ed4730__0\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    VlUnpacked<QData/*63:0*/, 1> __VTmp;
    // Body
    __VTmp[0U] = (QData)((IData)((((~ (IData)(vlSelfRef.tb_qpsk__DOT__clk)) 
                                   & (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb_qpsk__DOT__clk__0)) 
                                  << 1U)));
    vlSelfRef.__Vtrigprevexpr___TOP__tb_qpsk__DOT__clk__0 
        = vlSelfRef.tb_qpsk__DOT__clk;
    if ((2ULL & __VTmp[0U])) {
        vlSelfRef.__VtrigSched_ha1ed4730__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_ha1ed4730__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_ha1ed4730__0.ready(__VeventDescription);
        vlSelfRef.__VtrigSched_ha1ed4730__0.ready(__VeventDescription);
    }
    vlSelfRef.__VactTriggeredAcc[0U] = (vlSelfRef.__VactTriggeredAcc[0U] 
                                        | __VTmp[0U]);
}

#ifdef VL_DEBUG
void Vtb_qpsk___024root___eval_debug_assertions(Vtb_qpsk___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_qpsk___024root___eval_debug_assertions\n"); );
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
