// ===== moonspace/verify —— Verification Sandbox（验证环境沙箱）=====
// 隔离「验证环境」与「生产执行环境」：只吃 State/Event/Effect/
// Transition/Invariant，零真实 Port 依赖（RocksDB/LLM/Git 不见，R-7）。
// 谓词本体手写本包，gen 只产名字骨架。
// 本件（役4）：守卫谓词面（C-21 白盒件）——loop 注入用具名谓词，
// 与 [[space.guards]] 名字面合同对位。

///|
/// has_hits：ctx.hits 非空（retrieval_space 跨通道守卫，
/// retrieval_base.toml [[space.guards]] 名引用）
pub fn has_hits(ctx : Map[String, @space.CtxValue]) -> Bool {
  match ctx.get("hits") {
    Some(Texts(items)) => items.length() > 0
    _ => false
  }
}
