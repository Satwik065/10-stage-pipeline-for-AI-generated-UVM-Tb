// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vtb_qpsk__pch.h"
#include "verilated_vcd_c.h"

//============================================================
// Constructors

Vtb_qpsk::Vtb_qpsk(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vtb_qpsk__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
    contextp()->traceBaseModelCbAdd(
        [this](VerilatedTraceBaseC* tfp, int levels, int options) { traceBaseModel(tfp, levels, options); });
}

Vtb_qpsk::Vtb_qpsk(const char* _vcname__)
    : Vtb_qpsk(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vtb_qpsk::~Vtb_qpsk() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vtb_qpsk___024root___eval_debug_assertions(Vtb_qpsk___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vtb_qpsk___024root___eval_static(Vtb_qpsk___024root* vlSelf);
void Vtb_qpsk___024root___eval_initial(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD bool Vtb_qpsk___024root___eval_stl(Vtb_qpsk___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vtb_qpsk___024root___eval_sample(Vtb_qpsk___024root* vlSelf);
bool Vtb_qpsk___024root___eval_ico(Vtb_qpsk___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vtb_qpsk___024root___eval_act(Vtb_qpsk___024root* vlSelf);
bool Vtb_qpsk___024root___eval_inact(Vtb_qpsk___024root* vlSelf);
bool Vtb_qpsk___024root___eval_nba(Vtb_qpsk___024root* vlSelf);
bool Vtb_qpsk___024root___eval_obs(Vtb_qpsk___024root* vlSelf);
bool Vtb_qpsk___024root___eval_react(Vtb_qpsk___024root* vlSelf);
void Vtb_qpsk___024root___eval_postponed(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_final(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_dump_triggers__stl(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_dump_triggers__ico(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_dump_triggers__act(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_dump_triggers__nba(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_dump_triggers__obs(Vtb_qpsk___024root* vlSelf);
VL_ATTR_COLD void Vtb_qpsk___024root___eval_dump_triggers__react(Vtb_qpsk___024root* vlSelf);

void Vtb_qpsk::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vtb_qpsk::eval_step\n"); );
    m_evalLoop.eval();
}

void Vtb_qpsk::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vtb_qpsk___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_activity = true;
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vtb_qpsk::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->TOP.__VdlySched.cleanupForevered();
}

void Vtb_qpsk::evalStatic() {
    Vtb_qpsk___024root___eval_static(&(vlSymsp->TOP));
}

void Vtb_qpsk::evalInitial() {
    Vtb_qpsk___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vtb_qpsk::evalStl(bool firstIteration) {
    return Vtb_qpsk___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vtb_qpsk::evalSample() {
    Vtb_qpsk___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vtb_qpsk::evalIco(bool firstIteration) {
    return Vtb_qpsk___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vtb_qpsk::evalAct() {
    return Vtb_qpsk___024root___eval_act(&(vlSymsp->TOP));
}

bool Vtb_qpsk::evalInact() {
    return Vtb_qpsk___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vtb_qpsk::evalNba() {
    return Vtb_qpsk___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vtb_qpsk::evalObs() {
    return Vtb_qpsk___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vtb_qpsk::evalReact() {
    return Vtb_qpsk___024root___eval_react(&(vlSymsp->TOP));
}

void Vtb_qpsk::evalPostponed() {
    Vtb_qpsk___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vtb_qpsk::evalFinal() {
    Vtb_qpsk___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_qpsk::dumpTriggersStl() {
    Vtb_qpsk___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_qpsk::dumpTriggersIco() {
    Vtb_qpsk___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_qpsk::dumpTriggersAct() {
    Vtb_qpsk___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_qpsk::dumpTriggersNba() {
    Vtb_qpsk___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_qpsk::dumpTriggersObs() {
    Vtb_qpsk___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vtb_qpsk::dumpTriggersReact() {
    Vtb_qpsk___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

void Vtb_qpsk::eval_end_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+eval_end_step Vtb_qpsk::eval_end_step\n"); );
#ifdef VM_TRACE
    // Tracing
    if (VL_UNLIKELY(vlSymsp->__Vm_dumping)) vlSymsp->_traceDump();
#endif  // VM_TRACE
}

//============================================================
// Events and timing
bool Vtb_qpsk::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vtb_qpsk::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vtb_qpsk::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vtb_qpsk::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vtb_qpsk::hierName() const { return vlSymsp->name(); }
const char* Vtb_qpsk::modelName() const { return "Vtb_qpsk"; }
unsigned Vtb_qpsk::threads() const { return 1; }
void Vtb_qpsk::prepareClone() const { contextp()->prepareClone(); }
void Vtb_qpsk::atClone() const {
    contextp()->threadPoolpOnClone();
}
std::unique_ptr<VerilatedTraceConfig> Vtb_qpsk::traceConfig() const {
    return std::unique_ptr<VerilatedTraceConfig>{new VerilatedTraceConfig{false}};
};

//============================================================
// Trace configuration

void Vtb_qpsk___024root__trace_decl_types(VerilatedVcd* tracep);

void Vtb_qpsk___024root__trace_init_top(Vtb_qpsk___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD static void trace_init(void* voidSelf, VerilatedVcd* tracep, uint32_t code) {
    // Callback from tracep->open()
    Vtb_qpsk___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_qpsk___024root*>(voidSelf);
    Vtb_qpsk__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (!vlSymsp->_vm_contextp__->calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
            "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vlSymsp->__Vm_baseCode = code;
    tracep->pushPrefix(vlSymsp->name(), VerilatedTracePrefixType::SCOPE_MODULE);
    Vtb_qpsk___024root__trace_decl_types(tracep);
    Vtb_qpsk___024root__trace_init_top(vlSelf, tracep);
    tracep->popPrefix();
}

VL_ATTR_COLD void Vtb_qpsk___024root__trace_register(Vtb_qpsk___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD void Vtb_qpsk::traceBaseModel(VerilatedTraceBaseC* tfp, int levels, int options) {
    (void)levels; (void)options;
    VerilatedVcdC* const stfp = dynamic_cast<VerilatedVcdC*>(tfp);
    if (VL_UNLIKELY(!stfp)) {
        vl_fatal(__FILE__, __LINE__, __FILE__,"'Vtb_qpsk::trace()' called on non-VerilatedVcdC object;"
            " use --trace-fst with VerilatedFst object, and --trace-vcd with VerilatedVcd object");
    }
    stfp->spTrace()->addModel(this);
    stfp->spTrace()->addInitCb(&trace_init, &(vlSymsp->TOP), name(), false, 16);
    Vtb_qpsk___024root__trace_register(&(vlSymsp->TOP), stfp->spTrace());
}
