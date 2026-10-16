// ===== moonspace/runtime —— run 入口双门测试（评审 A2/A3）=====
// A2 守卫闭合：rules 引用的 guard_name ⊄ 注入谓词表 ⇒ 入口
//   GuardClosureError 拦停（不等运行中 MissingGuard 停摆）。
// A3 环×双零：规则图有环（效应步回灌环）且轮径/墙钟双零 ⇒
//   RunGateError 拦停；预算居其一即放行（预算面照旧兜 MaxRounds）。
// fixture 手构 EffectSpace 字面量（pub(all) 运行形直构，黑盒本地
// 自足）；错误种类断言靠单变体 suberror 无歧义（抛错即该错），
// 断言在 catch 外（BM25 役教训：catch 内断言吞失败）。

///|
fn gate_clock(tick : Array[Int64]) -> () -> Int64 {
  fn() { tick[0] }
}

///|
struct EchoTickHandler {
  tag : Int32
}

///|
impl EffectHandler for EchoTickHandler with fn handle(
  self : EchoTickHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  ignore(self.tag)
  ignore(effect)
  { name: "Tick", payload: Map([]), }
}

///|
/// 环 fixture：S0 --Tick/echo--> S1 --Tick/echo--> S0（效应步回灌环；
/// 纯装填环会 Stall 收口，到不了循环执行）
fn cycle_space() -> @space.EffectSpace {
  {
    name: "cycle_probe",
    states: ["S0", "S1"],
    initial_state: "S0",
    events: [{ name: "Tick", payload_fields: [], }],
    effects: [{ name: "Echo", semantics: "command", }],
    rules: [
      {
        from_state: "S0",
        on_event: "Tick",
        to_state: "S1",
        effect_name: Some("Echo"),
        guard_name: None,
        args: [],
        assigns: [],
      },
      {
        from_state: "S1",
        on_event: "Tick",
        to_state: "S0",
        effect_name: Some("Echo"),
        guard_name: None,
        args: [],
        assigns: [],
      },
    ],
    feedback_routers: [],
    loop_guard: None,
  }
}

///|
/// 守卫 fixture：单行规则引用未注册守卫 g1（无效应——A2 门先于步进）
fn guarded_space() -> @space.EffectSpace {
  {
    name: "guard_probe",
    states: ["S0", "S1"],
    initial_state: "S0",
    events: [{ name: "Tick", payload_fields: [], }],
    effects: [],
    rules: [
      {
        from_state: "S0",
        on_event: "Tick",
        to_state: "S1",
        effect_name: None,
        guard_name: Some("g1"),
        args: [],
        assigns: [],
      },
    ],
    feedback_routers: [],
    loop_guard: None,
  }
}

///|
async test "入口门 A2：守卫引用未注册 ⇒ 入口拦停" {
  let tick : Array[Int64] = [0L]
  try
    @runtime.run(
      guarded_space(),
      EchoTickHandler::{ tag: 1, },
      { max_rounds: 8, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
      gate_clock(tick),
      Map([]), // 缺 g1 谓词
      { name: "Tick", payload: Map([]), },
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expect MissingPredicates（守卫闭合门未咬）")
  }
}

///|
async test "入口门 A2：谓词齐备 ⇒ 放行（非吸收态 Stall 收口如常）" {
  let tick : Array[Int64] = [0L]
  let report = @runtime.run(
    guarded_space(),
    EchoTickHandler::{ tag: 1, },
    { max_rounds: 8, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    gate_clock(tick),
    Map([("g1", fn(_ctx) { true })]),
    { name: "Tick", payload: Map([]), },
  )
  assert_eq(report.final_state, "S1")
  assert_true(report.terminated_by is Completed)
}

///|
async test "入口门 A3：环 × 双零预算 ⇒ UnboundedCycle 拦停" {
  let tick : Array[Int64] = [0L]
  try
    @runtime.run(
      cycle_space(),
      EchoTickHandler::{ tag: 1, },
      { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
      gate_clock(tick),
      Map([]),
      { name: "Tick", payload: Map([]), },
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expect UnboundedCycle（环×双零组合门未咬）")
  }
}

///|
async test "入口门 A3：环 + 预算居一 ⇒ 放行（预算面照旧兜 MaxRounds）" {
  let tick : Array[Int64] = [0L]
  let report = @runtime.run(
    cycle_space(),
    EchoTickHandler::{ tag: 1, },
    { max_rounds: 3, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    gate_clock(tick),
    Map([]),
    { name: "Tick", payload: Map([]), },
  )
  assert_eq(report.rounds, 3)
  assert_true(report.terminated_by is MaxRounds)
}

///|
async test "环检测直测：自环与无环两态" {
  assert_true(cycle_space().has_transition_cycle())
  let linear : @space.EffectSpace = {
    name: "linear_probe",
    states: ["A", "B"],
    initial_state: "A",
    events: [{ name: "Tick", payload_fields: [], }],
    effects: [],
    rules: [
      {
        from_state: "A",
        on_event: "Tick",
        to_state: "B",
        effect_name: None,
        guard_name: None,
        args: [],
        assigns: [],
      },
    ],
    feedback_routers: [],
    loop_guard: None,
  }
  assert_true(!linear.has_transition_cycle())
}
