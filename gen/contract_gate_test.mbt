// ===== moonspace/gen —— 域合同对照门（黑盒）=====
// 口径：手写 domain/*.toml 是人维维护面，parse(*) 必须与 sample_*()
// 逐字段全等（漂移即红）；闭合核对（check_*）全绿。sample 跟随
// TOML 迁移，不反向。读真实文件钉漂移（scope_gate 先例，路径相对
// 模块根——moon test 工作目录 = 模块根）。

///|
async fn gate_text(rel_path : String) -> String {
  @utf8.decode(@fs.read_file(rel_path).binary())
}

///|
async test "对照门：domain/*.toml 与 sample fixture 逐字段全等" {
  let retrieval_base = @gen.parse_space_base(
    gate_text("./domain/retrieval_base.toml"),
  )
  assert_eq(retrieval_base, @gen.sample_retrieval_base())
  let retrieval_domain = @gen.parse_space_domain(
    gate_text("./domain/retrieval_domain.toml"),
  )
  assert_eq(retrieval_domain, @gen.sample_retrieval_domain())
  let reasoning_base = @gen.parse_space_base(
    gate_text("./domain/reasoning_base.toml"),
  )
  assert_eq(reasoning_base, @gen.sample_reasoning_base())
  let reasoning_domain = @gen.parse_space_domain(
    gate_text("./domain/reasoning_domain.toml"),
  )
  assert_eq(reasoning_domain, @gen.sample_reasoning_domain())
  let composition = @gen.parse_composition(
    gate_text("./domain/composition.toml"),
  )
  assert_eq(composition, @gen.sample_composition())
}

///|
async test "对照门：闭合核对全绿（恰一/词表/引用闭合/唯一性/守卫必填）" {
  let bases : Map[String, @gen.SpaceBase] = Map([])
  let retrieval_base = @gen.parse_space_base(
    gate_text("./domain/retrieval_base.toml"),
  )
  bases.set(retrieval_base.meta.name, retrieval_base)
  @gen.check_space_base(retrieval_base)
  let retrieval_domain = @gen.parse_space_domain(
    gate_text("./domain/retrieval_domain.toml"),
  )
  @gen.check_space(retrieval_base, retrieval_domain)
  let reasoning_base = @gen.parse_space_base(
    gate_text("./domain/reasoning_base.toml"),
  )
  bases.set(reasoning_base.meta.name, reasoning_base)
  @gen.check_space_base(reasoning_base)
  let reasoning_domain = @gen.parse_space_domain(
    gate_text("./domain/reasoning_domain.toml"),
  )
  @gen.check_space(reasoning_base, reasoning_domain)
  let composition = @gen.parse_composition(
    gate_text("./domain/composition.toml"),
  )
  @gen.check_composition(composition, bases)
}
