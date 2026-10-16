// ===== moonspace/gen —— handler stub 发射器结构门（R-7，黑盒）=====
// 口径：sample fixture 直发，断言三段式骨架结构——全 effect 臂在产
//（词表臂集闭合）、semantics 注记随臂、未知效应兜底臂、三段式口径
// 注记、per-space struct 命名、LoopEvent 构造型样例。逐字节面由
// out/gen_gate_test.mbt 黄金门钉（cmd 同款装配），本门管结构语义。

///|
async test "stub 发射器结构：词表臂集闭合 + 三段式注记（R-7）" {
  let base = @gen.sample_retrieval_base()
  let text = @gen.emit_handler_stub(base)
  for effect in base.effects {
    assert_true(text.contains("\"\{effect.name}\" =>"))
    assert_true(text.contains("semantics=\{effect.semantics}"))
    assert_true(text.contains("stub: retrieval_space.\{effect.name} 未填空"))
  }
  assert_true(text.contains("unknown effect"))
  assert_true(text.contains("哨兵回执"))
  assert_true(text.contains("fail 逃逸"))
  assert_true(text.contains("拆臂"))
  assert_true(text.contains("RetrievalHandlerStub"))
  assert_true(
    text.contains("impl @runtime.EffectHandler for RetrievalHandlerStub"),
  )
  assert_true(text.contains("name: \"Query\""))
}

///|
async test "stub 发射器结构：agent 空间双效应臂 + 空表兜底形" {
  let text = @gen.emit_handler_stub(@gen.sample_reasoning_base())
  assert_true(text.contains("\"LLMCall\" =>"))
  assert_true(text.contains("ReasoningHandlerStub"))
  // 事件词表注记行（ContextReady 在首）
  assert_true(text.contains("//   ContextReady"))
}
