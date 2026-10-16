// ===== reasoning_space EffectHandler stub（R-7 生成；拷贝到消费者包填空，禁回写）=====
// 再生：moon run moonspace/cmd（黄金门 out/gen_gate_test.mbt 逐字节）
// 三段式口径（moonxllm cmd/SpaceHandler 手写先例）：
//   拆臂——供方/世界一次响应按判定值拆成已判定事件（拆臂判定在本包）；
//   哨兵回执——域内可恢复错自转哨兵事件回灌（正道，非 raise）；
//   fail 逃逸——不可恢复错 fail/raise ⇒ Runner HandlerError 拦停。
// 事件词表（结果事件名必须闭合于此）：
//   ContextReady
//   ThinkDone
// LoopEvent 构造型样例：{ name: "ContextReady", payload: Map([("context", Text(""))]), }
// 落点要求：本包须 import thy1016/moonspace/runtime 与 thy1016/moonspace/space。

///|
pub struct ReasoningHandlerStub {
  // 填空位：依赖 port / 状态槽（SpaceHandler 先例：provider/registry/policy/…）
}

///|
impl @runtime.EffectHandler for ReasoningHandlerStub with fn handle(
  self : ReasoningHandlerStub,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  ignore(self)
  match effect.name {
    "LLMCall" =>
      // semantics=command：改世界面/计费面（须审计；重试策略在 Runner 资源面）
      // 填空：翻译语义（拆臂/哨兵回执/直返）——返回 LoopEvent
      fail("stub: reasoning_space.LLMCall 未填空")
    other =>
      // 未知效应（check_space 词表闭合后不达）：fail 逃逸上报
      fail("stub: unknown effect \{other}（越出 reasoning_space 词表）")
  }
}
