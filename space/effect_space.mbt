// ===== moonspace/space —— EffectSpace Sandbox（解空间沙箱）=====
// 职责：约束解空间——合法状态/事件/effect。Mealy 纯转移，effect 由
// handler 解释，持久化/权限/审计留 Port 层（.mingspace 定案）。
// 具体词表由 gen 从 domain/*.toml 生成；本包只放业务无关机器件。

///|
/// effect semantics 封闭词表（值域核对走 gen 解析役对照门）
pub let effect_semantics : Array[String] = [
  "query", "command", "commit", "rollback", "stop",
]

///|
/// 解空间接缝 = 生成物稳定命名约定（toolchain 实证：trait 不带类型
/// 参数表；泛型 struct 无构造点则长鸣 struct_never_constructed，
/// 按「真构造点」纪律撤形留档——形随 codegen 役落）。gen 为每个
/// 具体词表生成三件，签名按生成类型落：
///   transition(state, event) -> (State, Effect)?   // None = 未处理转移
///   allowed_effects(state) -> Array[Effect]        // 解空间边界
///   invariants_hold(state) -> Bool                 // verify 沙箱投影
