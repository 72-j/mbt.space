// ===== moonspace/gen —— 组合运行形构造门（黑盒）=====
// 口径：真 composition.toml 构造（对照口径）+ 剪枝率判据（钉③补）：
// (a) demo 自积精确断言（线性链自积全可达——剪枝零咬，机制在册；
//     数学：interleaving 积可达 = Π 成员可达）
// (b) 咬合用例：成员声明态 ⊋ 可达态（内嵌 TOML 声明不可达态）⇒
//     剪后对数精确断言 < 声明积

///|
async test "构造门：series 运行形（真 composition.toml；桥行闭合）" {
  let retrieval_base = @gen.parse_space_base(
    gate_text("./domain/retrieval_base.toml"),
  )
  let retrieval_domain = @gen.parse_space_domain(
    gate_text("./domain/retrieval_domain.toml"),
  )
  let reasoning_base = @gen.parse_space_base(
    gate_text("./domain/reasoning_base.toml"),
  )
  let reasoning_domain = @gen.parse_space_domain(
    gate_text("./domain/reasoning_domain.toml"),
  )
  let comp = @gen.parse_composition(gate_text("./domain/composition.toml"))
  let form = @gen.series_from_contract(
    retrieval_base,
    retrieval_domain,
    reasoning_base,
    reasoning_domain,
    comp.series[0],
  )
  assert_eq(form.name, "RetrievalToReasoning")
  assert_eq(form.bridges.length(), 1)
  assert_eq(form.bridges[0].from_state, "Done")
  assert_eq(form.bridges[0].to_event, "ContextReady")
}

///|
async test "构造门：parallel 运行形（真 composition.toml；自积全可达精确断言）" {
  let retrieval_base = @gen.parse_space_base(
    gate_text("./domain/retrieval_base.toml"),
  )
  let retrieval_domain = @gen.parse_space_domain(
    gate_text("./domain/retrieval_domain.toml"),
  )
  let comp = @gen.parse_composition(gate_text("./domain/composition.toml"))
  let form = @gen.parallel_from_contract(
    retrieval_base,
    retrieval_domain,
    retrieval_base,
    retrieval_domain,
    comp.parallels[0],
  )
  assert_eq(form.name, "SearchParallel")
  assert_eq(@gen.parallel_declared_pairs(form), 16)
  // 判据 (a)：4 态线性链自积 = 全 16 对可达（零咬）；BFS 对数精确
  assert_eq(form.reachable.length(), 16)
}

///|
/// 咬合用例 TOML（内嵌专用——真源五件由对照门钉，此处声明不可达态
/// 制造剪枝咬合：成员声明 4 态 / 可达 3 态）
fn synth_base_toml() -> String {
  [
    "[meta]", "schema_version = \"2.0\"", "name = \"synth_space\"", "prefix = \"Synth\"",
    "", "[space]", "strategy = \"Mealy\"", "effects_trait_open = false", "interpretation = \"cps\"",
    "", "[[space.events]]", "name = \"E\"", "", "[[space.states]]", "name = \"Idle\"",
    "is_initial = true", "", "[[space.states]]", "name = \"S1\"", "", "[[space.states]]",
    "name = \"S2\"", "", "[[space.states]]", "name = \"Lost\"", "", "[[space.transitions]]",
    "from = \"Idle\"", "on = \"E\"", "to = \"S1\"", "", "[[space.transitions]]",
    "from = \"S1\"", "on = \"E\"", "to = \"S2\"",
  ].join("\n")
}

///|
fn synth_domain_toml() -> String {
  [
    "[meta]", "schema_version = \"2.0\"", "name = \"synth_space\"", "prefix = \"Synth\"",
    "", "[[space.transitions]]", "from = \"Idle\"", "on = \"E\"", "to = \"S1\"",
    "", "[[space.transitions]]", "from = \"S1\"", "on = \"E\"", "to = \"S2\"",
  ].join("\n")
}

///|
fn bite_composition_toml() -> String {
  [
    "[meta]", "schema_version = \"2.0\"", "name = \"bite_case\"", "prefix = \"Bite\"",
    "", "[[parallel]]", "name = \"BiteCase\"", "spaces = [\"synth_space\", \"retrieval_space\"]",
    "sync = []", "merge_effects = \"union\"",
  ].join("\n")
}

///|
async test "剪枝咬合：Lost 不可达 ⇒ 剪后 12 < 声明积 16（判据 b）" {
  let synth_base = @gen.parse_space_base(synth_base_toml())
  let synth_domain = @gen.parse_space_domain(synth_domain_toml())
  let retrieval_base = @gen.parse_space_base(
    gate_text("./domain/retrieval_base.toml"),
  )
  let retrieval_domain = @gen.parse_space_domain(
    gate_text("./domain/retrieval_domain.toml"),
  )
  let comp = @gen.parse_composition(bite_composition_toml())
  let form = @gen.parallel_from_contract(
    synth_base,
    synth_domain,
    retrieval_base,
    retrieval_domain,
    comp.parallels[0],
  )
  // 声明积 = 4 × 4 = 16；剪后 = 3（Lost 不可达）× 4 = 12
  assert_eq(@gen.parallel_declared_pairs(form), 16)
  assert_eq(form.reachable.length(), 12)
  assert_true(form.reachable.length() < @gen.parallel_declared_pairs(form))
}
