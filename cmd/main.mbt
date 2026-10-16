// ===== moonspace/cmd —— typed codegen 再生入口（A2 落形，moonxllm cmd 同款）=====
// 用法：moon run moonspace/cmd（读 domain/*.toml 对 → emit → 写
// out/spaces_gen.mbt；黄金门 out/gen_gate_test.mbt 逐字节对拍）
// 役R-6 续格：agent_space 对入列（moonxllm 装配正身词表进 typed 产物）

///|
async fn main {
  let pairs = [
    (
      "./moonspace/domain/retrieval_base.toml", "./moonspace/domain/retrieval_domain.toml",
    ),
    (
      "./moonspace/domain/reasoning_base.toml", "./moonspace/domain/reasoning_domain.toml",
    ),
    (
      "./moonspace/domain/agent_space_base.toml", "./moonspace/domain/agent_space_domain.toml",
    ),
    (
      "./moonspace/domain/vibe_space_base.toml", "./moonspace/domain/vibe_space_domain.toml",
    ),
  ]
  let b = StringBuilder()
  b.write_string(
    "// ===== moonspace/out · typed 产物（再生：moon run moonspace/cmd；黄金门 out/gen_gate_test.mbt 逐字节对拍；禁手写）=====\n\n",
  )
  for index, pair in pairs {
    if index > 0 {
      b.write_string("\n")
    }
    let (base_path, domain_path) = pair
    let base = @gen.parse_space_base(
      @utf8.decode(@fs.read_file(base_path).binary()),
    )
    let domain = @gen.parse_space_domain(
      @utf8.decode(@fs.read_file(domain_path).binary()),
    )
    b.write_string(@gen.emit_space_typed(base, domain))
  }
  @fs.write_file("./moonspace/out/spaces_gen.mbt", @utf8.encode(b.to_string()))
  // R-7 handler stub 产物（非编译文本区 stub_out/；消费者拷贝填空）
  for pair in pairs {
    let (base_path, _) = pair
    let base = @gen.parse_space_base(
      @utf8.decode(@fs.read_file(base_path).binary()),
    )
    let text = @gen.emit_handler_stub(base)
    @fs.write_file(
      "./moonspace/out/stub_out/\{base.meta.name}_handler_stub.mbt",
      @utf8.encode(text),
    )
  }
  println(
    "typed codegen: 已生成 moonspace/out/spaces_gen.mbt + stub_out/ handler stubs（4 spaces）",
  )
}
