// ===== moonspace/examples · 示例 loop（合同 → 门 → 大 loop 全栈自证）=====
// 跑法：cd moonspace && moon run examples --target native
//（run 缺省 wasm 后端——native 钉面必带；本包 supported_targets=native）
// 面：手写最小合同（3 态机 Idle→Working→Done + Fail 修复环）→
// gen 解析 + §15 意图装填（assign_from 糖收归系统）+ 闭合门 →
// space_from_contract → runtime.run（罐头效应臂，零 LLM）→
// 审计尾迹 + 槽位落 ctx 打印。阳面 = base 词表；阴面 = domain 转移表。
// 罐头合同与 gen/runtime 罐头测试同构（黑盒测试钉过门，此处跑给人看）。

///|
/// 阳面：base 合同（词表 = 态/事件/效应/槽位——只选不发明的封闭面）
fn hello_base() -> String {
  (
    #|[meta]
    #|schema_version = "2.0"
    #|name = "hello_loop_space"
    #|dialect = "moonspace"
    #|prefix = "Hello"
    #|
    #|[space]
    #|strategy = "Mealy"
    #|interpretation = "cps"
    #|
    #|[[space.context]]
    #|name = "result_summary"
    #|type = "String?"
    #|semantics = "slot"
    #|doc = "结果摘要槽"
    #|
    #|[[space.events]]
    #|name = "Kick"
    #|payload = [{ name = "text", type = "String" }]
    #|
    #|[[space.events]]
    #|name = "WorkDone"
    #|payload = [{ name = "note", type = "String" }]
    #|
    #|[[space.events]]
    #|name = "Fail"
    #|payload = [{ name = "reason", type = "String" }]
    #|
    #|[[space.effects]]
    #|name = "DoIt"
    #|semantics = "command"
    #|payload = [{ name = "text", type = "String" }]
    #|
    #|[[space.states]]
    #|name = "Idle"
    #|is_initial = true
    #|
    #|[[space.states]]
    #|name = "Working"
    #|
    #|[[space.states]]
    #|name = "Done"
  )
}

///|
/// 阴面：domain 转移表（WorkDone→Done 带 §15 assign_from 糖——效应
/// 回执字段 note 落槽 result_summary）
fn hello_domain() -> String {
  (
    #|[meta]
    #|schema_version = "2.0"
    #|name = "hello_loop_space"
    #|dialect = "moonspace"
    #|prefix = "Hello"
    #|
    #|[[space.transitions]]
    #|from = "Idle"
    #|on = "Kick"
    #|to = "Working"
    #|effect = "DoIt"
    #|args = ["text"]
    #|
    #|[[space.transitions]]
    #|from = "Working"
    #|on = "WorkDone"
    #|to = "Done"
    #|assign = ["result_summary"]
    #|assign_from = [{ slot = "result_summary", from_field = "note" }]
    #|
    #|[[space.transitions]]
    #|from = "Working"
    #|on = "Fail"
    #|to = "Idle"
  )
}

///|
/// 罐头效应臂：DoIt → WorkDone（零 LLM；真身效应面在宿主装配位——
/// moonxllm/cmd VibeHandler 先例）
struct HelloHandler {}

///|
impl @runtime.EffectHandler for HelloHandler with fn handle(
  self : HelloHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  ignore(self)
  match effect.name {
    "DoIt" =>
      { name: "WorkDone", payload: Map([("note", @space.Text("did it"))]), }
    other => raise Failure("未知效应 \{other}（罐头臂只认 DoIt）")
  }
}

///|
/// 终结形态 → 文案（与 cmd 装配位同款判词，examples 自带不跨包）
fn term_text(termination : @runtime.Termination) -> String {
  match termination {
    @runtime.Completed => "Completed"
    @runtime.MaxRounds => "MaxRounds"
    @runtime.Timeout => "Timeout"
    @runtime.Cancelled => "Cancelled"
    @runtime.DeadEnd(kind) => "DeadEnd(\{deadend_text(kind)})"
    @runtime.HandlerError(detail) => "HandlerError(\{detail})"
  }
}

///|
/// 停摆分型 → 文案（C1 分型消费面；@runtime 导出 deadend_text?——
/// 不导出则本地重写，与 cmd 判词同款）
fn deadend_text(kind : @runtime.DeadEndKind) -> String {
  match kind {
    @runtime.NoRule(state~, event~) => "no_rule:\{state}+\{event}"
    @runtime.GuardRejected(name~) => "guard:\{name}"
    @runtime.MissingGuard(name~) => "missing_guard:\{name}"
    @runtime.Stall(state~) => "stall:\{state}"
  }
}

///|
async fn main {
  // 合同面：解析 → 意图装填（assign_from 糖）→ 闭合门（E 可达 + 阳集闭合）
  let base = @gen.parse_space_base(hello_base())
  let domain = @gen.parse_space_domain(hello_domain())
  let normalized = @gen.normalize_assigns(base, domain)
  @gen.check_space(base, normalized)
  println(
    "合同 \{base.meta.name} 过门：态 \{base.states.length()} / 事件 \{base.events.length()} / 效应 \{base.effects.length()} / 转移 \{normalized.transitions.length()}",
  )
  // 构造 + 大 loop（boot = Kick，载任务槽）
  let space = @gen.space_from_contract(base, normalized, [])
  let report = @runtime.run(
    space,
    HelloHandler::{ },
    @runtime.ResourceLimit::{
      max_rounds: 12,
      timeout_ms: 0,
      effect_timeout_ms: 0,
      max_retries: 0,
    },
    fn() { 0L },
    Map([]),
    { name: "Kick", payload: Map([("text", @space.Text("写一首诗"))]), },
  )
  // 报告面：终局 + 审计尾迹 + 槽位落 ctx 证据
  println(
    "终局: \{report.final_state} / \{term_text(report.terminated_by)} / rounds=\{report.rounds}",
  )
  for row in report.audit {
    println(
      "  r\{row.round}: \{row.effect_name} → \{row.result_event} (\{row.outcome})",
    )
  }
  match report.final_ctx.get("result_summary") {
    Some(@space.Text(summary)) => println("槽位 result_summary = \{summary}")
    Some(_) => println("槽位 result_summary = (非文本形)")
    None => println("槽位 result_summary = (未落)")
  }
}
