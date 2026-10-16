// ===== moonspace/verify —— 轻量霍尔先形（guan.md 契约面落形）=====
// A3 探针实证（2026-10-11）：proof_requires/ensures 关键字面**不在**
// 现役工具链（verify.md 访谈断言陈旧——两形皆 [4021]/[3002]）；
// `moon prove` 真存但 Why3 系（.mbtp 模型面 + proof_assert +
// SMT solver，环境缺 z3/cvc5/alt-ergo）——prove 面挂台账待环境
// 装机，本役走 guan.md 轻量先形 + core @qc 属性双轨。

///|
/// 转移级三元组：{pre} step(event) {post}——霍尔语义：前件不成立 =
/// 空洞真；后件签 (pre_state, event, post_state) 三位全给（审计面
/// 可判迁移合法性）。泛型于 State/Event——verify 只吃解空间类型
/// （R-7），零 Port。
pub fn[State, Event] check_triple(
  pre : (State) -> Bool,
  step : (State, Event) -> State,
  post : (State, Event, State) -> Bool,
  state : State,
  event : Event,
) -> Bool {
  if pre(state) {
    post(state, event, step(state, event))
  } else {
    true
  }
}

///|
/// 状态级断言先形（guan.md check_pre/check_post）：谓词本体调用方
/// 手写（C-21 白盒面），本面只定接口序
pub fn check_pre(pre : (String) -> Bool, state : String) -> Bool {
  pre(state)
}

///|
pub fn check_post(post : (String) -> Bool, state : String) -> Bool {
  post(state)
}
