// ===== retrieval_space EffectHandler stub（R-7 生成；拷贝到消费者包填空，禁回写）=====
// 再生：moon run moonspace/cmd（黄金门 out/gen_gate_test.mbt 逐字节）
// 三段式口径（宿主 cmd/SpaceHandler 手写先例）：
//   拆臂——供方/世界一次响应按判定值拆成已判定事件（拆臂判定在本包）；
//   哨兵回执——域内可恢复错自转哨兵事件回灌（正道，非 raise）；
//   fail 逃逸——不可恢复错 fail/raise ⇒ Runner HandlerError 拦停。
// 事件词表（结果事件名必须闭合于此）：
//   Query
//   BM25Done
//   VectorDone
// LoopEvent 构造型样例：{ name: "Query", payload: Map([("text", Text(""))]), }
// 落点要求：本包须 import thy1016/moonspace/runtime 与 thy1016/moonspace/space。

///|
pub struct RetrievalHandlerStub {
  // 填空位：依赖 port / 状态槽（SpaceHandler 先例：provider/registry/policy/…）
}

///|
impl @runtime.EffectHandler for RetrievalHandlerStub with fn handle(
  self : RetrievalHandlerStub,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  ignore(self)
  match effect.name {
    "BM25Search" =>
      // semantics=query：只读查询面（可安全重试；结果事件纯装填）
      // 填空：翻译语义（拆臂/哨兵回执/直返）——返回 LoopEvent
      fail("stub: retrieval_space.BM25Search 未填空")
    "VectorSearch" =>
      // semantics=query：只读查询面（可安全重试；结果事件纯装填）
      // 填空：翻译语义（拆臂/哨兵回执/直返）——返回 LoopEvent
      fail("stub: retrieval_space.VectorSearch 未填空")
    other =>
      // 未知效应（check_space 词表闭合后不达）：fail 逃逸上报
      fail("stub: unknown effect \{other}（越出 retrieval_space 词表）")
  }
}
