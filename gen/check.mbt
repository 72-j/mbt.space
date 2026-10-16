// ===== moonspace/gen —— 域合同闭合核对（验收口径面）=====
// 口径（domain/*.toml 头注定案，gen 解析器核对；对照测试漂移即红）：
//   骨架恰一门：is_initial 全表恰一；semantics 落封闭词表
//     （effect_semantics，生成器唯一可硬编码面）
//   行为闭合门：meta.name 配对一致；from+on 组合唯一；to/effect/
//     guard/args/assign 引用在骨架词表内闭合
//   组合闭合门：space 引用闭合到已声明文件对；sync 事件两边全在；
//     adapter/router 桥行引用闭合；feedback 守卫必填（两值至少
//     启用其一，0 = 不启用）
// 谓词本体（invariants 语义）不在本面——verify 包手写。

///|
/// 名字集合（词表成员 -> 在）
fn name_set(names : Array[String]) -> Map[String, Bool] {
  let set : Map[String, Bool] = Map([])
  for name in names {
    set.set(name, true)
  }
  set
}

///|
/// 骨架自检（*_base.toml）
pub fn check_space_base(base : SpaceBase) -> Unit raise {
  let initial_count = base.states
    .filter(fn(state) { state.is_initial })
    .length()
  if initial_count != 1 {
    raise ValueErr(
      "\{base.meta.name}: is_initial 全表恰一，实得 \{initial_count}",
    )
  }
  let vocabulary : Array[String] = @space.effect_semantics
  let separator : StringView = "/"
  for effect in base.effects {
    if !vocabulary.contains(effect.semantics) {
      raise ValueErr(
        "\{base.meta.name}.effects.\{effect.name}: semantics \"\{effect.semantics}\" 越出封闭词表 \{vocabulary.join(separator)}",
      )
    }
  }
}

///|
/// 行为闭合核对（base × domain 配对）
pub fn check_space(base : SpaceBase, domain : SpaceDomain) -> Unit raise {
  if domain.meta.name != base.meta.name {
    raise ValueErr(
      "domain meta.name \"\{domain.meta.name}\" 与配对 base \"\{base.meta.name}\" 不一致",
    )
  }
  let state_set = name_set(base.states.map(fn(state) { state.name }))
  let event_payloads : Map[String, Map[String, Bool]] = Map([])
  for event in base.events {
    let fields = name_set(event.payload.map(fn(field) { field.name }))
    event_payloads.set(event.name, fields)
  }
  let effect_set = name_set(base.effects.map(fn(effect) { effect.name }))
  let guard_set = name_set(base.guards.map(fn(guard_decl) { guard_decl.name }))
  let context_set = name_set(base.context.map(fn(field) { field.name }))
  let seen_pairs : Map[String, Bool] = Map([])
  for transition in domain.transitions {
    let where_ = "transition \{transition.from_state}+\{transition.on_event}"
    if !state_set.contains(transition.from_state) {
      raise ValueErr(
        "\{where_}: from_state \"\{transition.from_state}\" 不在骨架状态词表",
      )
    }
    if !state_set.contains(transition.to_state) {
      raise ValueErr(
        "\{where_}: to_state \"\{transition.to_state}\" 不在骨架状态词表",
      )
    }
    if !event_payloads.contains(transition.on_event) {
      raise ValueErr(
        "\{where_}: on_event \"\{transition.on_event}\" 不在骨架事件词表",
      )
    }
    match transition.effect {
      Some(effect_name) =>
        if !effect_set.contains(effect_name) {
          raise ValueErr(
            "\{where_}: effect \"\{effect_name}\" 不在骨架效应词表",
          )
        }
      None => ()
    }
    match transition.guard_name {
      Some(guard_name) =>
        if !guard_set.contains(guard_name) {
          raise ValueErr(
            "\{where_}: guard \"\{guard_name}\" 不在骨架守卫词表",
          )
        }
      None => ()
    }
    match event_payloads.get(transition.on_event) {
      Some(fields) => {
        for arg in transition.args {
          if !fields.contains(arg) {
            raise ValueErr(
              "\{where_}: args \"\{arg}\" 不是事件 \{transition.on_event} 的 payload 字段",
            )
          }
        }
        let mapped : Map[String, Bool] = Map([])
        for mapping in transition.assign_from {
          if !transition.assign.contains(mapping.slot) {
            raise ValueErr(
              "\{where_}: assign_from slot \"\{mapping.slot}\" 不在 assign 列表",
            )
          }
          if mapped.contains(mapping.slot) {
            raise ValueErr(
              "\{where_}: assign_from slot \"\{mapping.slot}\" 重复映射",
            )
          }
          mapped.set(mapping.slot, true)
          if !fields.contains(mapping.from_field) {
            raise ValueErr(
              "\{where_}: assign_from from_field \"\{mapping.from_field}\" 不是事件 \{transition.on_event} 的 payload 字段",
            )
          }
        }
        for slot in transition.assign {
          if !context_set.contains(slot) {
            raise ValueErr(
              "\{where_}: assign \"\{slot}\" 不在骨架 context 槽位词表",
            )
          }
          if !mapped.contains(slot) && !fields.contains(slot) {
            raise ValueErr(
              "\{where_}: assign \"\{slot}\" 无同名 payload 字段且无 assign_from 显式映射",
            )
          }
        }
      }
      None => ()
    }
    let pair = "\{transition.from_state}+\{transition.on_event}"
    if seen_pairs.contains(pair) {
      raise ValueErr("\{where_}: from+on 组合重复（转移表唯一性）")
    }
    seen_pairs.set(pair, true)
  }
  // cells（USA §8 方言注册）：error_event/effect ∈ 阳集 + form ∈ v1
  // 闭合集 + fields 非空（D 拍合同门——格1 黑盒门升构造期正门）
  for cell in domain.cells {
    let where_ = "cell \{cell.name}"
    if !effect_set.contains(cell.effect) {
      raise ValueErr(
        "\{where_}: effect \"\{cell.effect}\" 不在骨架效应词表",
      )
    }
    if !event_payloads.contains(cell.error_event) {
      raise ValueErr(
        "\{where_}: error_event \"\{cell.error_event}\" 不在骨架事件词表",
      )
    }
    if cell.form != "jsonl" {
      raise ValueErr(
        "\{where_}: form \"\{cell.form}\" 不在 v1 闭合集（jsonl）",
      )
    }
    if cell.fields.length() == 0 {
      raise ValueErr("\{where_}: fields 不得为空")
    }
  }
  // E 门（可达性）：初态可达吸收终局 + 无死角可达非吸收态——LLM 出
  // 机最怕"停不下来/到不了终局"（moonspace_review E 条；守卫忽略的
  // 结构近似，格3 生成机的硬件门）
  check_reachability(base, domain)
}

///|
/// E 门（可达性，moonspace_review E 条）：初态结构可达某吸收终局，
/// 且每个**可达非吸收态**结构可达吸收终局（无死角态）。守卫忽略 =
/// 结构近似（守卫有界环语义见评审原文）。吸收态 = 无出边转移的态。
fn check_reachability(base : SpaceBase, domain : SpaceDomain) -> Unit raise {
  let absorbing : Map[String, Bool] = Map([])
  for state in base.states {
    absorbing.set(state.name, true)
  }
  for t in domain.transitions {
    absorbing.set(t.from_state, false)
  }
  let fwd : Map[String, Array[String]] = Map([])
  let rev : Map[String, Array[String]] = Map([])
  for state in base.states {
    fwd.set(state.name, [])
    rev.set(state.name, [])
  }
  for t in domain.transitions {
    match fwd.get(t.from_state) {
      Some(nexts) => nexts.push(t.to_state)
      None => ()
    }
    match rev.get(t.to_state) {
      Some(prevs) => prevs.push(t.from_state)
      None => ()
    }
  }
  let initial = initial_state_name(base)
  // 正向 DFS：初态可达集
  let reachable : Map[String, Bool] = Map([])
  let work : Array[String] = [initial]
  while work.length() > 0 {
    let cur = work.remove(0)
    let seen = match reachable.get(cur) {
      Some(b) => b
      None => false
    }
    if seen {
      continue
    }
    reachable[cur] = true
    match fwd.get(cur) {
      Some(nexts) =>
        for nxt in nexts {
          let nseen = match reachable.get(nxt) {
            Some(b) => b
            None => false
          }
          if !nseen {
            work.push(nxt)
          }
        }
      None => ()
    }
  }
  // 反向 DFS：吸收终局的反向可达集
  let reaches_terminal : Map[String, Bool] = Map([])
  let work2 : Array[String] = []
  for name, is_abs in absorbing {
    if is_abs {
      reaches_terminal[name] = true
      work2.push(name)
    }
  }
  while work2.length() > 0 {
    let cur = work2.remove(0)
    match rev.get(cur) {
      Some(prevs) =>
        for p in prevs {
          let seen = match reaches_terminal.get(p) {
            Some(b) => b
            None => false
          }
          if !seen {
            reaches_terminal[p] = true
            work2.push(p)
          }
        }
      None => ()
    }
  }
  // 判一：初态可达吸收终局
  let mut terminal_reached = false
  for name, is_abs in absorbing {
    let reached = match reachable.get(name) {
      Some(b) => b
      None => false
    }
    if is_abs && reached {
      terminal_reached = true
    }
  }
  if !terminal_reached {
    raise ValueErr(
      "E 门：初态 \"\{initial}\" 无结构可达路径到吸收终局（守卫忽略近似）",
    )
  }
  // 判二：每个可达非吸收态可达吸收终局（无死角态）
  for name, is_abs in absorbing {
    let reached = match reachable.get(name) {
      Some(b) => b
      None => false
    }
    if reached && !is_abs {
      let ok = match reaches_terminal.get(name) {
        Some(b) => b
        None => false
      }
      if !ok {
        raise ValueErr(
          "E 门：可达非吸收态 \"\{name}\" 无路径到吸收终局（死角态）",
        )
      }
    }
  }
}

///|
/// 组合闭合核对（composition.toml × 已声明骨架集）
pub fn check_composition(
  composition : Composition,
  bases : Map[String, SpaceBase],
) -> Unit raise {
  for parallel in composition.parallels {
    if parallel.spaces.length() < 2 {
      raise ValueErr("parallel \{parallel.name}: spaces 至少两个")
    }
    for space_name in parallel.spaces {
      if !bases.contains(space_name) {
        raise ValueErr(
          "parallel \{parallel.name}: space \"\{space_name}\" 未声明（base 文件对缺失）",
        )
      }
    }
    for sync_event in parallel.sync {
      for space_name in parallel.spaces {
        match bases.get(space_name) {
          Some(base) => {
            let event_names = base.events.map(fn(event) { event.name })
            if !event_names.contains(sync_event) {
              raise ValueErr(
                "parallel \{parallel.name}: sync 事件 \"\{sync_event}\" 在 space \"\{space_name}\" 未声明",
              )
            }
          }
          None => ()
        }
      }
    }
    if parallel.merge_effects != "union" {
      raise ValueErr(
        "parallel \{parallel.name}: merge_effects \"\{parallel.merge_effects}\" 越出现役词表（union）",
      )
    }
  }
  for series_row in composition.series {
    let source = match bases.get(series_row.source) {
      Some(base) => base
      None =>
        raise ValueErr(
          "series \{series_row.name}: source \"\{series_row.source}\" 未声明",
        )
    }
    let target = match bases.get(series_row.target) {
      Some(base) => base
      None =>
        raise ValueErr(
          "series \{series_row.name}: target \"\{series_row.target}\" 未声明",
        )
    }
    let source_states = name_set(source.states.map(fn(state) { state.name }))
    let target_events = name_set(target.events.map(fn(event) { event.name }))
    for bridge in series_row.adapter {
      if !source_states.contains(bridge.from_state) {
        raise ValueErr(
          "series \{series_row.name}: adapter from_state \"\{bridge.from_state}\" 不在源空间状态词表",
        )
      }
      if !target_events.contains(bridge.to_event) {
        raise ValueErr(
          "series \{series_row.name}: adapter to_event \"\{bridge.to_event}\" 不在目标空间事件词表",
        )
      }
    }
  }
  for feedback in composition.feedbacks {
    let host = match bases.get(feedback.space) {
      Some(base) => base
      None =>
        raise ValueErr(
          "feedback \{feedback.name}: space \"\{feedback.space}\" 未声明",
        )
    }
    let host_states = name_set(host.states.map(fn(state) { state.name }))
    let host_events = name_set(host.events.map(fn(event) { event.name }))
    // A1 回灌投影闭合：to_event 的 payload 字段须 ⊆ 宿主 ctx 槽位——
    // make_loopback 按字段名取 ctx，缺键静默空文回灌（指错字段名的
    // router 每轮空转，无门能红——moonxllm 评审 A1 拍）
    let host_context = name_set(host.context.map(fn(field) { field.name }))
    let host_payloads : Map[String, Map[String, Bool]] = Map([])
    for event in host.events {
      let fields = name_set(event.payload.map(fn(field) { field.name }))
      host_payloads.set(event.name, fields)
    }
    for bridge in feedback.router {
      if !host_states.contains(bridge.from_state) {
        raise ValueErr(
          "feedback \{feedback.name}: router from_state \"\{bridge.from_state}\" 不在宿主状态词表",
        )
      }
      if !host_events.contains(bridge.to_event) {
        raise ValueErr(
          "feedback \{feedback.name}: router to_event \"\{bridge.to_event}\" 不在宿主事件词表",
        )
      }
      match host_payloads.get(bridge.to_event) {
        Some(fields) =>
          for field, _ in fields {
            if !host_context.contains(field) {
              raise ValueErr(
                "feedback \{feedback.name}: router to_event \"\{bridge.to_event}\" payload 字段 \"\{field}\" 不在宿主 ctx 槽位词表（LoopBack 回灌将空文）",
              )
            }
          }
        None => ()
      }
    }
    match feedback.loop_guard {
      Some(loop_guard) =>
        if loop_guard.max_rounds <= 0 && loop_guard.timeout_ms <= 0 {
          raise ValueErr(
            "feedback \{feedback.name}: 守卫两值全零（max_rounds/timeout_ms 至少启用其一）",
          )
        }
      None =>
        raise ValueErr(
          "feedback \{feedback.name}: 守卫必填（max_rounds/timeout_ms）",
        )
    }
  }
}

///|
/// 语义装填（USA §15 意图编程语法糖）：assign 槽位在事件载荷**恰一
/// 字段**时，系统自动补 assign_from 映射（from_field = 唯一字段）。
/// 格3b 实测：assign_from 嵌套表形是 LLM 语法盲区（三轮教学未愈），
/// 难处收归系统侧；手写机显式映射不动。返回新 SpaceDomain（原域不改）。
pub fn normalize_assigns(base : SpaceBase, domain : SpaceDomain) -> SpaceDomain {
  let payloads : Map[String, Array[String]] = Map([])
  for event in base.events {
    payloads.set(event.name, event.payload.map(fn(p) { p.name }))
  }
  let transitions : Array[TransitionDecl] = []
  for t in domain.transitions {
    let fields = match payloads.get(t.on_event) {
      Some(f) => f
      None => []
    }
    let new_assign_from : Array[AssignFrom] = []
    for m in t.assign_from {
      new_assign_from.push(m)
    }
    // args 修正：非载荷字段名（常见 = 槽位名误用）且载荷恰一字段时，
    // 修正为唯一载荷字段（机械可推导）；多字段载荷的坏名留给闭合门
    let new_args : Array[String] = []
    for a in t.args {
      if fields.contains(a) {
        new_args.push(a)
      } else if fields.length() == 1 {
        new_args.push(fields[0])
      } else {
        new_args.push(a)
      }
    }
    for slot in t.assign {
      let in_payload = fields.contains(slot)
      let mut mapped = false
      for m in t.assign_from {
        if m.slot == slot {
          mapped = true
        }
      }
      if !in_payload && !mapped && fields.length() == 1 {
        new_assign_from.push({ slot, from_field: fields[0], })
      }
    }
    // from_field 修正：提供了映射但 from_field 非载荷字段，而载荷
    // 恰一字段时——from_field 机械可推导（唯一候选），修正之
    for i in 0..<new_assign_from.length() {
      let m = new_assign_from[i]
      let known = fields.contains(m.from_field)
      if !known && fields.length() == 1 {
        new_assign_from[i] = { slot: m.slot, from_field: fields[0], }
      }
    }
    transitions.push({
      from_state: t.from_state,
      on_event: t.on_event,
      to_state: t.to_state,
      effect: t.effect,
      args: new_args,
      assign: t.assign,
      assign_from: new_assign_from,
      guard_name: t.guard_name,
      doc: t.doc,
    })
  }
  {
    meta: domain.meta,
    transitions,
    invariants: domain.invariants,
    cells: domain.cells,
  }
}
