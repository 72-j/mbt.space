// ===== moonspace/out —— typed codegen 黄金门（黑盒）=====
// 口径（A2 定案）：重生成 ≡ 入库产物**逐字节**——cmd 再生链的同款装配
// 在门内复算（读真 domain/*.toml → emit 拼装），与入库 spaces_gen.mbt
// 逐字节全等；漂移即红（改 TOML 后必须 moon run moonspace/cmd 再生）。
// **产物禁手写亦禁 fmt 再排版**（fmt 的 ///| 插拔/尾逗号/单行臂折叠都是
// 改写产物）——fmt 后本门红 = 重跑 moon run moonspace/cmd 自愈（勘定：
// 规范化比对不可行，fmt 的单表达式臂折叠增删语义花括号，normalize 归一
// 不掉；2026-10-11 实证）。

///|
async fn gate_read(rel : String) -> String {
  // 双路径序：模块根（./out/…）先，workspace 根（./moonspace/out/…）后备
  let primary = @fs.read_file("./out/\{rel}") catch {
    _ => @fs.read_file("./moonspace/out/\{rel}")
  }
  @utf8.decode(primary.binary())
}

///|
async fn gate_domain(rel : String) -> String {
  let primary = @fs.read_file("./domain/\{rel}") catch {
    _ => @fs.read_file("./moonspace/domain/\{rel}")
  }
  @utf8.decode(primary.binary())
}

///|
async test "golden：重生成 ≡ 入库产物逐字节" {
  let pairs = [
    ("retrieval_base.toml", "retrieval_domain.toml"),
    ("reasoning_base.toml", "reasoning_domain.toml"),
    ("agent_space_base.toml", "agent_space_domain.toml"),
    ("vibe_space_base.toml", "vibe_space_domain.toml"),
  ]
  let b = StringBuilder()
  b.write_string(
    "// ===== moonspace/out · typed 产物（再生：moon run moonspace/cmd；黄金门 out/gen_gate_test.mbt 逐字节对拍；禁手写）=====\n\n",
  )
  for index, pair in pairs {
    if index > 0 {
      b.write_string("\n")
    }
    let (base_rel, domain_rel) = pair
    let base = @gen.parse_space_base(gate_domain(base_rel))
    let domain = @gen.parse_space_domain(gate_domain(domain_rel))
    b.write_string(@gen.emit_space_typed(base, domain))
  }
  let committed = gate_read("spaces_gen.mbt")
  assert_eq(b.to_string(), committed)
}

///|
async test "golden：handler stub 产物逐字节（R-7，stub_out/ 非编译文本区）" {
  let bases = [
    "retrieval_base.toml", "reasoning_base.toml", "agent_space_base.toml",
  ]
  for base_rel in bases {
    let base = @gen.parse_space_base(gate_domain(base_rel))
    let emitted = @gen.emit_handler_stub(base)
    let committed = gate_read("stub_out/\{base.meta.name}_handler_stub.mbt")
    assert_eq(emitted, committed)
  }
}
