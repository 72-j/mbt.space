// ===== moonspace/verify —— 属性门（黑盒；R-3 首件）=====
// qc 词表闭合属性：任意事件 × 任意声明态 → step 终局不出骨架词表
// （NoRule/守卫三分合法，Stepped 终态必在声明集）——转移表漂移的
// 随机钉。fixture 手构 EffectSpace 字面量（verify 独立面：不依
// 赖 gen 解析器，R-7）。

///|
/// 手构最小解空间（Idle --E--> S1 --E--> S2；S2 吸收）
fn fixture_space() -> @space.EffectSpace {
  {
    name: "fixture",
    states: ["Idle", "S1", "S2"],
    initial_state: "Idle",
    events: [{ name: "E", payload_fields: [], }],
    effects: [],
    rules: [
      {
        from_state: "Idle",
        on_event: "E",
        to_state: "S1",
        effect_name: None,
        guard_name: None,
        args: [],
        assigns: [],
      },
      {
        from_state: "S1",
        on_event: "E",
        to_state: "S2",
        effect_name: None,
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
test "qc：词表闭合——任意事件×任意声明态，终局不出骨架词表" {
  let space = fixture_space()
  @qc.check(fn(seed : Int32) {
    // 位掩码取非负（Arbitrary 生成 Int 极值含 MIN——取反溢出陷阱）
    let event_index = seed & 0x7fffffff
    let event_name = space.events[event_index % space.events.length()].name
    let state = space.states[event_index /
      space.events.length() %
      space.states.length()]
    let event : @space.LoopEvent = { name: event_name, payload: Map([]), }
    match @space.EffectSpace::step(space, state, event, Map([]), Map([])) {
      NoRule => true
      GuardRejected(_) => true
      MissingGuard(_) => true
      Stepped(step_result) => space.states.contains(step_result.next_state)
    }
  })
}

///|
test "三元组：{初态} --E--> {终态在词表}（check_triple 确定性面）" {
  let space = fixture_space()
  let in_vocabulary = fn(_pre : String, _event : String, post : String) {
    space.states.contains(post)
  }
  assert_true(
    @space.EffectSpace::step(
      space,
      "Idle",
      { name: "E", payload: Map([]), },
      Map([]),
      Map([]),
    )
    is Stepped(_),
  )
  assert_true(
    @verify.check_triple(
      fn(state) { state == "Idle" },
      fn(state, _event) {
        match
          @space.EffectSpace::step(
            space,
            state,
            { name: "E", payload: Map([]), },
            Map([]),
            Map([]),
          ) {
          Stepped(step_result) => step_result.next_state
          _ => state
        }
      },
      in_vocabulary,
      "Idle",
      "E",
    ),
  )
}
