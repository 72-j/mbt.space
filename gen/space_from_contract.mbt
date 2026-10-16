// ===== moonspace/gen —— 合同 → 解空间运行形构造器（役4）=====
// 口径：构造前重跑三门（恰一/行为闭合 + 骨架恰一），产物受 R-1..R-8
// 同约束；feedback 行按 space 名挂载并就地核对（R-3：桥行闭合 +
// 守卫必填 + 两值至少启用其一）。assign 投影在此解析归一（同名缺省/
// assign_from 显式 → from_field 单形，step 面零分支）。

///|
/// 骨架×行为（×可选 feedback 集）→ 解空间运行形
pub fn space_from_contract(
  base : SpaceBase,
  domain : SpaceDomain,
  feedbacks : Array[FeedbackDecl],
) -> @space.EffectSpace raise {
  check_space_base(base)
  check_space(base, domain)
  let initial_state = pick_initial(base)
  let events : Array[@space.EventSpec] = []
  for event in base.events {
    let payload_fields = event.payload.map(fn(field) { field.name })
    events.push({ name: event.name, payload_fields, })
  }
  let effects : Array[@space.EffectSpec] = []
  for effect in base.effects {
    effects.push({ name: effect.name, semantics: effect.semantics, })
  }
  let payload_fields : Map[String, Map[String, Bool]] = Map([])
  for event in base.events {
    let fields = name_set(event.payload.map(fn(field) { field.name }))
    payload_fields.set(event.name, fields)
  }
  let rules : Array[@space.TransitionRule] = []
  for transition in domain.transitions {
    rules.push({
      from_state: transition.from_state,
      on_event: transition.on_event,
      to_state: transition.to_state,
      effect_name: transition.effect,
      guard_name: transition.guard_name,
      args: transition.args,
      assigns: resolve_assigns(transition),
    })
  }
  let state_names = name_set(base.states.map(fn(state) { state.name }))
  let event_names = name_set(base.events.map(fn(event) { event.name }))
  let context_names = name_set(base.context.map(fn(field) { field.name }))
  let routers : Array[@space.FeedbackRouter] = []
  let mut loop_guard_spec : @space.LoopGuardSpec? = None
  for feedback in feedbacks {
    if feedback.space == base.meta.name {
      match feedback.loop_guard {
        Some(guard_values) => {
          if guard_values.max_rounds <= 0 && guard_values.timeout_ms <= 0 {
            raise ValueErr(
              "feedback \{feedback.name}: 守卫两值全零（R-3 至少启用其一）",
            )
          }
          loop_guard_spec = Some({
            max_rounds: guard_values.max_rounds,
            timeout_ms: guard_values.timeout_ms,
          })
        }
        None =>
          raise ValueErr(
            "feedback \{feedback.name}: 守卫必填（R-3；max_rounds/timeout_ms）",
          )
      }
      for
        bridge in attach_feedback(
          feedback, state_names, event_names, payload_fields, context_names,
        ) {
        routers.push(bridge)
      }
    }
  }
  {
    name: base.meta.name,
    states: base.states.map(fn(state) { state.name }),
    initial_state,
    events,
    effects,
    rules,
    feedback_routers: routers,
    loop_guard: loop_guard_spec,
  }
}

///|
/// 初始态拾取（恰一门后必恰一定；防御面兜底报错）
fn pick_initial(base : SpaceBase) -> String raise {
  let mut found : String? = None
  for state in base.states {
    if state.is_initial {
      found = Some(state.name)
    }
  }
  match found {
    Some(name) => name
    None =>
      raise ValueErr(
        "\{base.meta.name}: 初始态缺失（恰一门后不达）",
      )
  }
}

///|
/// assign 投影解析归一：显式映射优先，同名缺省（check_space 已保证
/// 二居其一，未命中同名即映射面）
fn resolve_assigns(transition : TransitionDecl) -> Array[@space.AssignSpec] {
  let mappings : Map[String, String] = Map([])
  for mapping in transition.assign_from {
    mappings.set(mapping.slot, mapping.from_field)
  }
  let assigns : Array[@space.AssignSpec] = []
  for slot in transition.assign {
    let from_field : String = match mappings.get(slot) {
      Some(source) => source
      None => slot
    }
    assigns.push({ slot, from_field, })
  }
  assigns
}

///|
/// feedback 桥行就地核对（R-3 + 评审 A1 回灌投影闭合）并落运行形
fn attach_feedback(
  feedback : FeedbackDecl,
  state_names : Map[String, Bool],
  event_names : Map[String, Bool],
  event_payloads : Map[String, Map[String, Bool]],
  context_names : Map[String, Bool],
) -> Array[@space.FeedbackRouter] raise {
  let routers : Array[@space.FeedbackRouter] = []
  for bridge in feedback.router {
    if !state_names.contains(bridge.from_state) {
      raise ValueErr(
        "feedback \{feedback.name}: from_state \"\{bridge.from_state}\" 不在宿主状态词表",
      )
    }
    if !event_names.contains(bridge.to_event) {
      raise ValueErr(
        "feedback \{feedback.name}: to_event \"\{bridge.to_event}\" 不在宿主事件词表",
      )
    }
    // A1：to_event payload 字段 ⊆ 宿主 ctx 槽位（make_loopback 缺键
    // 静默空文回灌——check_composition 同口径，构造期双位钉）
    match event_payloads.get(bridge.to_event) {
      Some(fields) =>
        for field, _ in fields {
          if !context_names.contains(field) {
            raise ValueErr(
              "feedback \{feedback.name}: to_event \"\{bridge.to_event}\" payload 字段 \"\{field}\" 不在宿主 ctx 槽位词表（LoopBack 回灌将空文）",
            )
          }
        }
      None => ()
    }
    routers.push({ from_state: bridge.from_state, to_event: bridge.to_event, })
  }
  routers
}
