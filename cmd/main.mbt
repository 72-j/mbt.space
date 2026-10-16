// ===== moonspace/cmd —— typed codegen 再生入口 =====
// 用法：仓根 `moon run moonspace/cmd --target native` 或独立仓模块根
// `moon run cmd --target native`（双路锚点探测，dep_gate 先例）——读
// domain/*.toml 对 → emit → 写 out/spaces_gen.mbt；黄金门
// out/gen_gate_test.mbt 逐字节对拍。
// 名单口径：演示空间对（retrieval/reasoning）——宿主装配词表
// （agent_space/vibe_space 等）住宿主仓 domain/，不入本仓产物面。

///|
/// 锚点探测（dep_gate 双路先例）：宿主 workspace 仓根 cwd（锚
/// ./moonspace）与独立仓模块根 cwd（锚 .）两形兼容——探 domain 首
/// 件在即定锚。
async fn anchor() -> String {
  let probe = @utf8.decode(
    @fs.read_file("./moonspace/domain/retrieval_base.toml").binary(),
  ) catch {
    _ => ""
  }
  if probe != "" {
    return "./moonspace"
  }
  "."
}

///|
async fn main {
  let root = anchor()
  let spaces = ["retrieval", "reasoning"]
  let b = StringBuilder()
  b.write_string(
    "// ===== moonspace/out · typed 产物（再生：moon run moonspace/cmd；黄金门 out/gen_gate_test.mbt 逐字节对拍；禁手写）=====\n\n",
  )
  for index, name in spaces {
    if index > 0 {
      b.write_string("\n")
    }
    let base = @gen.parse_space_base(
      @utf8.decode(@fs.read_file("\{root}/domain/\{name}_base.toml").binary()),
    )
    let domain = @gen.parse_space_domain(
      @utf8.decode(@fs.read_file("\{root}/domain/\{name}_domain.toml").binary()),
    )
    b.write_string(@gen.emit_space_typed(base, domain))
  }
  @fs.write_file("\{root}/out/spaces_gen.mbt", @utf8.encode(b.to_string()))
  // R-7 handler stub 产物（非编译文本区 stub_out/；消费者拷贝填空）
  for name in spaces {
    let base = @gen.parse_space_base(
      @utf8.decode(@fs.read_file("\{root}/domain/\{name}_base.toml").binary()),
    )
    let text = @gen.emit_handler_stub(base)
    @fs.write_file(
      "\{root}/out/stub_out/\{base.meta.name}_handler_stub.mbt",
      @utf8.encode(text),
    )
  }
  println(
    "typed codegen: 已生成 out/spaces_gen.mbt + stub_out/ handler stubs（\{spaces.length()} spaces）",
  )
}
