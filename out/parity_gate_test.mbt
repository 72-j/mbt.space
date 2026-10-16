// ===== moonspace/out —— 行为对拍门（typed codegen 次格；两皮一致性
// 质量闸）=====
// 两皮：皮 A = @space 数据驱动解释器（gen sample 构造）；皮 B = 本包
// typed 生成物。对拍什么（穷举 demo 全集：retrieval 4×3×2 +
// reasoning 3×2×2）：① 可转移性（Stepped↔Some，NoRule/守卫拒↔None）
// ② 终态名 ③ effect 名+实参（按名对齐）④ assign 后 ctx 槽值
// （Option 槽 Some↔Text 归一）。守卫两形同一判据（hits 非空）。

///|
/// CtxValue 相等（verify 独立面外的对拍助件——本包消费面）
fn ctx_value_eq(a : @space.CtxValue, b : @space.CtxValue) -> Bool {
  match (a, b) {
    (Text(x), Text(y)) => x == y
    (Texts(x), Texts(y)) => x == y
    (JsonVal(x), JsonVal(y)) => x == y
    _ => false
  }
}

///|
fn r_state_name(state : RetrievalState) -> String {
  match state {
    Idle => "Idle"
    SearchingBM25 => "SearchingBM25"
    SearchingVector => "SearchingVector"
    Done => "Done"
  }
}

///|
fn r_effect_name(effect : RetrievalEffect) -> String {
  match effect {
    BM25Search(_) => "BM25Search"
    VectorSearch(_) => "VectorSearch"
  }
}

///|
fn r_effect_args(effect : RetrievalEffect) -> Array[@space.CtxValue] {
  match effect {
    BM25Search(query) => [Text(query)]
    VectorSearch(query) => [Texts(query)]
  }
}

///|
fn n_state_name(state : ReasoningState) -> String {
  match state {
    Waiting => "Waiting"
    Thinking => "Thinking"
    Answered => "Answered"
  }
}

///|
fn n_effect_name(effect : ReasoningEffect) -> String {
  match effect {
    LLMCall(_) => "LLMCall"
  }
}

///|
fn n_effect_args(effect : ReasoningEffect) -> Array[@space.CtxValue] {
  match effect {
    LLMCall(prompt) => [Text(prompt)]
  }
}

///|
/// 检索空间对拍组合（解释器入参固定构造；两皮守卫同判据）
async fn parity_retrieval(
  interp : @space.EffectSpace,
  guard_mode_full : Bool,
) -> Unit {
  let states : Array[(String, RetrievalState)] = [
    ("Idle", Idle),
    ("SearchingBM25", SearchingBM25),
    ("SearchingVector", SearchingVector),
    ("Done", Done),
  ]
  let hits_value : @space.CtxValue = if guard_mode_full {
    Texts(["d1"])
  } else {
    Texts([])
  }
  let events : Array[(String, @space.LoopEvent, RetrievalEvent)] = [
    (
      "Query",
      { name: "Query", payload: Map([("text", Text("q"))]), },
      Query("q"),
    ),
    (
      "BM25Done",
      { name: "BM25Done", payload: Map([("hits", Texts(["d1"]))]), },
      BM25Done(["d1"]),
    ),
    (
      "VectorDone",
      { name: "VectorDone", payload: Map([("hits", Texts(["d1"]))]), },
      VectorDone(["d1"]),
    ),
  ]
  let ctx_a : Map[String, @space.CtxValue] = Map([
    ("query_text", Text("q")),
    ("hits", hits_value),
  ])
  let ctx_b : RetrievalCtx = {
    query_text: Some("q"),
    hits: if guard_mode_full {
      ["d1"]
    } else {
      []
    },
  }
  let guards_a : Map[String, (Map[String, @space.CtxValue]) -> Bool] = Map([
    (
      "has_hits",
      fn(m) {
        match m.get("hits") {
          Some(Texts(xs)) => xs.length() > 0
          _ => false
        }
      },
    ),
  ])
  let guards_b : (String, RetrievalCtx) -> Bool = fn(_name, ctx) {
    ctx.hits.length() > 0
  }
  for state_entry in states {
    let (state_name, state_b) = state_entry
    for event_entry in events {
      let (event_name, event_a, event_b) = event_entry
      let where_ = "retrieval \{state_name}+\{event_name} guard_full=\{guard_mode_full}"
      match
        @space.EffectSpace::step(interp, state_name, event_a, ctx_a, guards_a) {
        Stepped(step_result) =>
          match RetrievalState::step(state_b, ctx_b, event_b, guards_b) {
            Some((next_b, next_ctx_b, effect_b)) => {
              assert_eq(r_state_name(next_b), step_result.next_state)
              match (step_result.effect, effect_b) {
                (Some(effect_a), Some(typed_effect)) => {
                  assert_eq(r_effect_name(typed_effect), effect_a.name)
                  let typed_args = r_effect_args(typed_effect)
                  assert_eq(typed_args.length(), effect_a.args.length())
                  for index, value in effect_a.args {
                    assert_true(ctx_value_eq(typed_args[index], value))
                  }
                }
                (Some(_), None) => fail("\{where_}: 皮B无效应而皮A有")
                (None, Some(_)) => fail("\{where_}: 皮A无效应而皮B有")
                (None, None) => ()
              }
              // ctx 对拍：皮 A assigns 应用后逐槽比对
              let ctx_a_applied : Map[String, @space.CtxValue] = Map([])
              for key, value in ctx_a {
                ctx_a_applied.set(key, value)
              }
              for assign in step_result.assigns {
                let (slot, value) = assign
                ctx_a_applied.set(slot, value)
              }
              let ctx_b_map : Map[String, @space.CtxValue] = Map([])
              ctx_b_map.set(
                "query_text",
                match next_ctx_b.query_text {
                  Some(t) => Text(t)
                  None => Text("")
                },
              )
              ctx_b_map.set("hits", Texts(next_ctx_b.hits))
              for key, value in ctx_a_applied {
                match ctx_b_map.get(key) {
                  Some(b_value) => assert_true(ctx_value_eq(value, b_value))
                  None => assert_true(ctx_value_eq(value, Text("")))
                }
              }
            }
            None => fail("\{where_}: 皮B None 而皮A Stepped")
          }
        _ =>
          match RetrievalState::step(state_b, ctx_b, event_b, guards_b) {
            Some(_) => fail("\{where_}: 皮A非Stepped 而皮B Some")
            None => ()
          }
      }
    }
  }
}

///|
/// 推理空间对拍组合
async fn parity_reasoning(interp : @space.EffectSpace) -> Unit {
  let states : Array[(String, ReasoningState)] = [
    ("Waiting", Waiting),
    ("Thinking", Thinking),
    ("Answered", Answered),
  ]
  let events : Array[(String, @space.LoopEvent, ReasoningEvent)] = [
    (
      "ContextReady",
      { name: "ContextReady", payload: Map([("context", Text("c"))]), },
      ContextReady("c"),
    ),
    (
      "ThinkDone",
      { name: "ThinkDone", payload: Map([("text", Text("t"))]), },
      ThinkDone("t"),
    ),
  ]
  let ctx_a : Map[String, @space.CtxValue] = Map([("prompt", Text("p"))])
  let ctx_b : ReasoningCtx = { prompt: Some("p"), answer: None, context: None, }
  let guards_a : Map[String, (Map[String, @space.CtxValue]) -> Bool] = Map([])
  let guards_b : (String, ReasoningCtx) -> Bool = fn(_name, _ctx) { true }
  for state_entry in states {
    let (state_name, state_b) = state_entry
    for event_entry in events {
      let (event_name, event_a, event_b) = event_entry
      let where_ = "reasoning \{state_name}+\{event_name}"
      match
        @space.EffectSpace::step(interp, state_name, event_a, ctx_a, guards_a) {
        Stepped(step_result) =>
          match ReasoningState::step(state_b, ctx_b, event_b, guards_b) {
            Some((next_b, next_ctx_b, effect_b)) => {
              assert_eq(n_state_name(next_b), step_result.next_state)
              match (step_result.effect, effect_b) {
                (Some(effect_a), Some(typed_effect)) => {
                  assert_eq(n_effect_name(typed_effect), effect_a.name)
                  let typed_args = n_effect_args(typed_effect)
                  assert_eq(typed_args.length(), effect_a.args.length())
                  for index, value in effect_a.args {
                    assert_true(ctx_value_eq(typed_args[index], value))
                  }
                }
                (Some(_), None) => fail("\{where_}: 皮B无效应而皮A有")
                (None, Some(_)) => fail("\{where_}: 皮A无效应而皮B有")
                (None, None) => ()
              }
              let ctx_a_applied : Map[String, @space.CtxValue] = Map([])
              for key, value in ctx_a {
                ctx_a_applied.set(key, value)
              }
              for assign in step_result.assigns {
                let (slot, value) = assign
                ctx_a_applied.set(slot, value)
              }
              let ctx_b_map : Map[String, @space.CtxValue] = Map([])
              ctx_b_map.set(
                "prompt",
                match next_ctx_b.prompt {
                  Some(t) => Text(t)
                  None => Text("")
                },
              )
              ctx_b_map.set(
                "answer",
                match next_ctx_b.answer {
                  Some(t) => Text(t)
                  None => Text("")
                },
              )
              ctx_b_map.set(
                "context",
                match next_ctx_b.context {
                  Some(t) => Text(t)
                  None => Text("")
                },
              )
              for key, value in ctx_a_applied {
                match ctx_b_map.get(key) {
                  Some(b_value) => assert_true(ctx_value_eq(value, b_value))
                  None => assert_true(ctx_value_eq(value, Text("")))
                }
              }
            }
            None => fail("\{where_}: 皮B None 而皮A Stepped")
          }
        _ =>
          match ReasoningState::step(state_b, ctx_b, event_b, guards_b) {
            Some(_) => fail("\{where_}: 皮A非Stepped 而皮B Some")
            None => ()
          }
      }
    }
  }
}

///|
async test "对拍门：retrieval 两皮穷举等价（4×3×守卫两态）" {
  let interp = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  parity_retrieval(interp, true)
  parity_retrieval(interp, false)
}

///|
async test "对拍门：reasoning 两皮穷举等价（3×2）" {
  let interp = @gen.space_from_contract(
    @gen.sample_reasoning_base(),
    @gen.sample_reasoning_domain(),
    [],
  )
  parity_reasoning(interp)
}
