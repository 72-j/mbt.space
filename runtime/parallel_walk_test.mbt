// ===== moonspace/runtime —— parallel BFS 随机游走门（R-3 续格）=====
// 口径：任意种子驱动的双成员随机游走（32 种子 × 16 步），访问过的
// 每个状态对必 ∈ BFS 剪后集——剪枝器完备性的抽样钉（若 BFS 漏对，
// 游走踏上即红）。守卫拒否/无规则 = 原地停留（仍在集内——归纳不
// 变量：起点在集内，每步转移是 BFS 边，故恒在集内）。

///|
fn lcg_next(seed : Int32) -> Int32 {
  (seed * 1103515245 + 12345) & 0x7fffffff
}

///|
fn pair_in(pairs : Array[(String, String)], a : String, b : String) -> Bool {
  for pair in pairs {
    let (x, y) = pair
    if x == a && y == b {
      return true
    }
  }
  false
}

///|
test "qc：BFS 剪枝完备——32 种子×16 步随机游走，访问对 ⊆ 剪后集" {
  let base = @gen.sample_retrieval_base()
  let domain = @gen.sample_retrieval_domain()
  let comp_text = [
    "[meta]", "schema_version = \"2.0\"", "name = \"walk_case\"", "prefix = \"Walk\"",
    "", "[[parallel]]", "name = \"WalkParallel\"", "spaces = [\"retrieval_space\", \"retrieval_space\"]",
    "sync = []", "merge_effects = \"union\"",
  ].join("\n")
  let comp = @gen.parse_composition(comp_text)
  let form = @gen.parallel_from_contract(
    base,
    domain,
    base,
    domain,
    comp.parallels[0],
  )
  let mut seed = 20261011
  for _round in 0..<32 {
    let mut a = form.member0.initial_state
    let mut b = form.member1.initial_state
    let mut s = seed
    for _step in 0..<16 {
      s = lcg_next(s)
      let side = s & 1
      s = lcg_next(s)
      let event_index = (s >> 8) % 3
      let (space, state, event_name) = if side == 0 {
        (form.member0, a, form.member0.events[event_index].name)
      } else {
        (form.member1, b, form.member1.events[event_index].name)
      }
      match
        @space.EffectSpace::step(
          space,
          state,
          { name: event_name, payload: Map([]), },
          Map([]),
          Map([]),
        ) {
        Stepped(step_result) =>
          if side == 0 {
            a = step_result.next_state
          } else {
            b = step_result.next_state
          }
        _ => ()
      }
      assert_true(pair_in(form.reachable, a, b))
    }
    seed = lcg_next(seed)
  }
}
