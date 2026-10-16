// ===== moonspace/gen —— handler stub 发射器（R-7，装配役战训新格）=====
// 口径（spec §4.7）：per-space match 臂/哨兵回执/fail 逃逸三段式骨架
// ——新消费者 = TOML 对 + stub 填空（moonagentic cmd/SpaceHandler 手写
// 先例的可产形）。发射器只见词表数据（宪法：业务词零渗入生成器）；
// semantics 标签注记 = 模板指令集（宪法唯一可硬编面）。产物 = 非编译
// 文本区 out/stub_out/（消费者拷贝填空，禁回写本产物；fmt 禁面——
// 黄金门逐字节对拍）。

///|
/// semantics 标签 → 填空注记（模板指令集；越表标签在 check_space_base
/// 封闭词表门后不达，兜底臂如实注记）
fn semantics_note(semantics : String) -> String {
  match semantics {
    "query" => "只读查询面（可安全重试；结果事件纯装填）"
    "command" =>
      "改世界面/计费面（须审计；重试策略在 Runner 资源面）"
    "commit" =>
      "提交面（不可逆点——失败转补偿/哨兵，禁裸重试）"
    "rollback" => "回滚面（补偿执行）"
    "stop" => "停机面（终局语义）"
    other => "（越出语义词表——门后不达：\{other}）"
  }
}

///|
/// 结果事件构造型样例（词表首事件；哨兵回执/直返的 LoopEvent 字面形）
fn event_sample(base : SpaceBase) -> String {
  let head : EventDecl? = base.events.get(0)
  match head {
    Some(event) => {
      let fields = event.payload.map(fn(field) {
        "(\"\{field.name}\", Text(\"\"))"
      })
      let payload = if fields.length() == 0 {
        "Map([])"
      } else {
        "Map([\{fields.join(", ")}])"
      }
      "{ name: \"\{event.name}\", payload: \{payload}, }"
    }
    None => "{ name: \"…\", payload: Map([]), }"
  }
}

///|
/// 词表 → EffectHandler stub 骨架文本（纯函数；产物逐字节由黄金门钉）
pub fn emit_handler_stub(base : SpaceBase) -> String {
  let b = StringBuilder()
  let name = base.meta.name
  let prefix = base.meta.prefix
  let struct_name = "\{prefix}HandlerStub"
  let sample = event_sample(base)
  b.write_string(
    "// ===== \{name} EffectHandler stub（R-7 生成；拷贝到消费者包填空，禁回写）=====\n",
  )
  b.write_string(
    "// 再生：moon run moonspace/cmd（黄金门 out/gen_gate_test.mbt 逐字节）\n",
  )
  b.write_string(
    "// 三段式口径（moonagentic cmd/SpaceHandler 手写先例）：\n",
  )
  b.write_string(
    "//   拆臂——供方/世界一次响应按判定值拆成已判定事件（拆臂判定在本包）；\n",
  )
  b.write_string(
    "//   哨兵回执——域内可恢复错自转哨兵事件回灌（正道，非 raise）；\n",
  )
  b.write_string(
    "//   fail 逃逸——不可恢复错 fail/raise ⇒ Runner HandlerError 拦停。\n",
  )
  b.write_string("// 事件词表（结果事件名必须闭合于此）：\n")
  for event in base.events {
    b.write_string("//   \{event.name}\n")
  }
  b.write_string("// LoopEvent 构造型样例：\{sample}\n")
  b.write_string(
    "// 落点要求：本包须 import thy1016/moonspace/runtime 与 thy1016/moonspace/space。\n",
  )
  b.write_string("\n")
  b.write_string("///|\n")
  b.write_string("pub struct \{struct_name} {\n")
  b.write_string(
    "  // 填空位：依赖 port / 状态槽（SpaceHandler 先例：provider/registry/policy/…）\n",
  )
  b.write_string("}\n")
  b.write_string("\n")
  b.write_string("///|\n")
  b.write_string(
    "impl @runtime.EffectHandler for \{struct_name} with fn handle(\n",
  )
  b.write_string("  self : \{struct_name},\n")
  b.write_string("  effect : @space.LoopEffect,\n")
  b.write_string(") -> @space.LoopEvent raise {\n")
  b.write_string("  ignore(self)\n")
  b.write_string("  match effect.name {\n")
  for effect in base.effects {
    b.write_string("    \"\{effect.name}\" =>\n")
    b.write_string(
      "      // semantics=\{effect.semantics}：\{semantics_note(effect.semantics)}\n",
    )
    b.write_string(
      "      // 填空：翻译语义（拆臂/哨兵回执/直返）——返回 LoopEvent\n",
    )
    b.write_string("      fail(\"stub: \{name}.\{effect.name} 未填空\")\n")
  }
  b.write_string("    other =>\n")
  b.write_string(
    "      // 未知效应（check_space 词表闭合后不达）：fail 逃逸上报\n",
  )
  b.write_string(
    "      fail(\"stub: unknown effect \\{other}（越出 \{name} 词表）\")\n",
  )
  b.write_string("  }\n")
  b.write_string("}\n")
  b.to_string()
}
