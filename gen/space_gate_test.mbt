// ===== moonspace/gen —— 合同→运行形构造门（黑盒）=====
// 口径：构造产物结构面断言（初始态/词表规模/规则数/feedback 挂载/
// 守卫形）；行为面由 runtime 集成门兜（四环演示吃 sample 合同）。

///|
test "构造门：retrieval 运行形（初始态/规则数/无 feedback）" {
  let space = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  assert_eq(space.initial_state, "Idle")
  assert_eq(space.states.length(), 4)
  assert_eq(space.rules.length(), 3)
  assert_eq(space.feedback_routers.length(), 0)
  let done_absorbing = @space.EffectSpace::is_absorbing(space, "Done")
  assert_true(done_absorbing)
}

///|
test "构造门：reasoning 运行形（feedback 挂载 + 守卫形 + 回送落点）" {
  let space = @gen.space_from_contract(
    @gen.sample_reasoning_base(),
    @gen.sample_reasoning_domain(),
    @gen.sample_composition().feedbacks,
  )
  assert_eq(space.initial_state, "Waiting")
  assert_eq(space.feedback_routers.length(), 1)
  assert_eq(space.feedback_routers[0].to_event, "ContextReady")
  match space.loop_guard {
    Some(loop_guard) => assert_eq(loop_guard.max_rounds, 5)
    None => fail("loop_guard 缺失（R-3 必填面）")
  }
  let target = @space.EffectSpace::loopback_target(space, "ContextReady")
  assert_eq(target, "Waiting")
}

///|
test "构造门：assign 投影归一（同名缺省 + assign_from 显式单形化）" {
  let space = @gen.space_from_contract(
    @gen.sample_reasoning_base(),
    @gen.sample_reasoning_domain(),
    [],
  )
  let mut answer_from : String? = None
  for rule in space.rules {
    if rule.on_event == "ThinkDone" {
      for assign in rule.assigns {
        answer_from = Some(assign.from_field)
      }
    }
  }
  match answer_from {
    Some(from_field) => assert_eq(from_field, "text")
    None => fail("ThinkDone 行 assign 缺失")
  }
}

///|
/// 真实文件对 → 运行形（装配役词表合同对照门用）
async fn gate_space(rel_path : String) -> @space.EffectSpace {
  let base = @gen.parse_space_base(gate_text("\{rel_path}_base.toml"))
  let domain = @gen.parse_space_domain(gate_text("\{rel_path}_domain.toml"))
  @gen.space_from_contract(base, domain, [])
}

///|
async test "构造门：agent_space 词表合同对（拆臂/自环回灌/异名映射实装）" {
  let space = gate_space("./domain/agent_space")
  assert_eq(space.initial_state, "Idle")
  assert_eq(space.states.length(), 4)
  assert_eq(space.rules.length(), 5)
  let llm_call_from : Array[String] = []
  for rule in space.rules {
    if rule.effect_name == Some("LLMCall") {
      llm_call_from.push(rule.from_state)
    }
  }
  assert_eq(llm_call_from.length(), 3) // Idle 装填 + ToolCalling 自环×2（回执/判否各一）
  for rule in space.rules {
    if rule.from_state == "Answered" {
      fail("Answered 出边非零（answered_absorbing 违背）")
    }
  }
  let mut last_tool_source : String? = None
  for rule in space.rules {
    for assign in rule.assigns {
      if assign.slot == "last_tool" {
        last_tool_source = Some(assign.from_field)
      }
    }
  }
  match last_tool_source {
    Some(from_field) => assert_eq(from_field, "tool") // 异名映射归一实证
    None => fail("last_tool 落槽缺失")
  }
}
