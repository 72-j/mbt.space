// ===== moonspace/space —— 沙箱大 loop 机器件（数据驱动解空间运行形）=====
// 形态裁定（役4，勘 moonxllm 消费面后拍）：
//   ① async 化——handler 直返形（async 对位 CPS 单层：k 恰一次施加
//     即返回；禁嵌套/捕获语义不变，R-2）
//   ② CtxValue 带 Json 臂（moonxllm 工具参数 Json 载荷对位）
//   ③ 执行错哨兵回执先例（moonxllm dispatch_one）：handler 应自转
//     哨兵事件；逃逸错 ⇒ Runner HandlerError 拦停（R-8 分判）
//   ④ 端口中立——moonxllm 装配只在 cmd/X3 位相接，agent 包白名单不动
// 数据驱动：词表/转移表是运行时数据（gen 从 domain/*.toml 构造）；
// typed codegen 路线仍列后续役（spec.md §5）。
// 本包依赖 = core 标准库面（json），零三方零业务（R-7 豁免注）。
//
// R-1 转移纯函数：step 只读词表/规则与入参，禁 IO/时钟；守卫谓词
// 由调用方注入（C-21 白盒面，谓词本体 verify/stub 手写）。

///|
/// ctx 数据槽值（v2 值域：文本/文本列表/JSON——工具参数载荷对位）
pub(all) enum CtxValue {
  Text(String)
  Texts(Array[String])
  JsonVal(Json)
}

///|
/// loop 事件（词表名 + payload 槽；运行时数据形）
pub(all) struct LoopEvent {
  name : String
  payload : Map[String, CtxValue]
}

///|
/// loop 效应（词表名 + 实参投影；只产出不执行，R-1）
pub(all) struct LoopEffect {
  name : String
  args : Array[CtxValue]
}

///|
/// 效应词表项（审计面读 semantics）
pub(all) struct EffectSpec {
  name : String
  semantics : String
}

///|
/// 事件词表项（LoopBack 回送投影读 payload 字段名）
pub(all) struct EventSpec {
  name : String
  payload_fields : Array[String]
}

///|
/// assign 落槽解析形（from_field 在合同构造期归一：同名缺省/
/// assign_from 显式映射 → 单形）
pub(all) struct AssignSpec {
  slot : String
  from_field : String
}

///|
/// 转移规则行（from+on 全表唯一，check_space 钉）
pub(all) struct TransitionRule {
  from_state : String
  on_event : String
  to_state : String
  effect_name : String?
  guard_name : String?
  args : Array[String]
  assigns : Array[AssignSpec]
}

///|
/// feedback 回送行（显式 LoopBack，R-3）
pub(all) struct FeedbackRouter {
  from_state : String
  to_event : String
}

///|
/// loop 守卫声明形（R-3：max_rounds/timeout_ms，0 = 不启用）
pub(all) struct LoopGuardSpec {
  max_rounds : Int32
  timeout_ms : Int32
}

///|
/// 解空间运行形（gen 包 space_from_contract 构造）
pub(all) struct EffectSpace {
  name : String
  states : Array[String]
  initial_state : String
  events : Array[EventSpec]
  effects : Array[EffectSpec]
  rules : Array[TransitionRule]
  feedback_routers : Array[FeedbackRouter]
  loop_guard : LoopGuardSpec?
}

///|
/// 步进产物（纯装填步 effect = None；assigns 由 runner 折入 ctx）
pub struct Step {
  next_state : String
  effect : LoopEffect?
  assigns : Array[(String, CtxValue)]
}

///|
/// 步进结局：判否/谓词未注册/无规则三分（审计面不混型，R-8）
pub(all) enum StepOutcome {
  Stepped(Step)
  GuardRejected(String)
  MissingGuard(String)
  NoRule
}

///|
/// Mealy 纯转移（R-1）。守卫判转移前 ctx；拒绝 ⇒ 转移不发生
/// （无 effect 无状态变更，domain TOML 头注口径）；谓词未注册 ⇒
/// MissingGuard（配置缺口面，与"判否"分列）。
pub fn EffectSpace::step(
  self : EffectSpace,
  state : String,
  event : LoopEvent,
  ctx : Map[String, CtxValue],
  guards : Map[String, (Map[String, CtxValue]) -> Bool],
) -> StepOutcome {
  let mut found : TransitionRule? = None
  for rule in self.rules {
    if rule.from_state == state && rule.on_event == event.name {
      found = Some(rule)
    }
  }
  match found {
    None => NoRule
    Some(rule) =>
      match rule.guard_name {
        Some(guard_name) =>
          match guards.get(guard_name) {
            Some(predicate) =>
              if predicate(ctx) {
                apply_rule(rule, event)
              } else {
                GuardRejected(guard_name)
              }
            None => MissingGuard(guard_name)
          }
        None => apply_rule(rule, event)
      }
  }
}

///|
/// 规则应用：args 按 effect 形参位取事件 payload 字段；assign 按
/// 归一 from_field 取事件 payload（缺键缺省空文本——合同闭合后
/// 由 handler 供给面兜底）
fn apply_rule(rule : TransitionRule, event : LoopEvent) -> StepOutcome {
  let args : Array[CtxValue] = []
  for arg_name in rule.args {
    let value : CtxValue = match event.payload.get(arg_name) {
      Some(v) => v
      None => Text("")
    }
    args.push(value)
  }
  let assigns : Array[(String, CtxValue)] = []
  for slot_spec in rule.assigns {
    let value : CtxValue = match event.payload.get(slot_spec.from_field) {
      Some(v) => v
      None => Text("")
    }
    assigns.push((slot_spec.slot, value))
  }
  let effect : LoopEffect? = match rule.effect_name {
    Some(name) => Some({ name, args, })
    None => None
  }
  Stepped({ next_state: rule.to_state, effect, assigns, })
}

///|
/// 效应语义词（审计面读；未知效应名返空串——合同闭合后不达）
pub fn EffectSpace::effect_semantics_of(
  self : EffectSpace,
  effect_name : String,
) -> String {
  let mut found = ""
  for effect in self.effects {
    if effect.name == effect_name {
      found = effect.semantics
    }
  }
  found
}

///|
/// 事件词表项查找（LoopBack 投影用）
pub fn EffectSpace::event_spec(
  self : EffectSpace,
  event_name : String,
) -> EventSpec? {
  let mut found : EventSpec? = None
  for event in self.events {
    if event.name == event_name {
      found = Some(event)
    }
  }
  found
}

///|
/// 状态到回送行查找（R-3：显式 LoopBack）
pub fn EffectSpace::router_for(
  self : EffectSpace,
  state : String,
) -> FeedbackRouter? {
  let mut found : FeedbackRouter? = None
  for router in self.feedback_routers {
    if router.from_state == state {
      found = Some(router)
    }
  }
  found
}

///|
/// 吸收态判（无出边规则 = 终态）
pub fn EffectSpace::is_absorbing(self : EffectSpace, state : String) -> Bool {
  for rule in self.rules {
    if rule.from_state == state {
      return false
    }
  }
  true
}

///|
/// LoopBack 落点：to_event 的首个规则源态（v1 口径 = 回灌落回受理
/// 该事件的态，tensor.md 回送口径；无规则时落初始态兜底。携带策略
/// 扩展待裁 spec.md A4）
pub fn EffectSpace::loopback_target(
  self : EffectSpace,
  to_event : String,
) -> String {
  for rule in self.rules {
    if rule.on_event == to_event {
      return rule.from_state
    }
  }
  self.initial_state
}

///|
/// LoopBack 事件合成：to_event 的 payload 字段按名取 ctx，缺键
/// 缺省 Text("")（v1 规则；携带策略扩展待裁 spec.md A4）
pub fn EffectSpace::make_loopback(
  self : EffectSpace,
  router : FeedbackRouter,
  ctx : Map[String, CtxValue],
) -> LoopEvent {
  let payload : Map[String, CtxValue] = Map([])
  match self.event_spec(router.to_event) {
    Some(spec) =>
      for field in spec.payload_fields {
        let value : CtxValue = match ctx.get(field) {
          Some(v) => v
          None => Text("")
        }
        payload.set(field, value)
      }
    None => ()
  }
  { name: router.to_event, payload, }
}

///|
/// 守卫闭合错（moonxllm 评审 A2：运行时 MissingGuard 停摆的前移面）
pub(all) suberror GuardClosureError {
  MissingPredicates(missing~ : Array[String])
} derive(Debug)

///|
pub extend GuardClosureError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 守卫注册闭合核对（评审 A2）：rules 引用的 guard_name 全集 ⊆ 注入
/// 谓词表 key 集——run 入口/装配位调用，缺者报缺失名单（把运行中段
/// 停摆提前成入口拦停，与"构造前重跑三门"哲学同线）
pub fn EffectSpace::check_guards_closed(
  self : EffectSpace,
  guards : Map[String, (Map[String, CtxValue]) -> Bool],
) -> Unit raise {
  let missing : Array[String] = []
  for rule in self.rules {
    match rule.guard_name {
      Some(guard_name) =>
        if !guards.contains(guard_name) && !missing.contains(guard_name) {
          missing.push(guard_name)
        }
      None => ()
    }
  }
  if missing.length() > 0 {
    raise MissingPredicates(missing~)
  }
}

///|
/// 规则图环检测（moonxllm 评审 A3）：节点 = 状态，边 = 转移规则
/// from→to；三色 DFS（白/灰/黑），灰遇灰 = 环，自环天然覆盖。
/// loopback 运行环不属此图（feedback 守卫另有 R-3 门管）
pub fn EffectSpace::has_transition_cycle(self : EffectSpace) -> Bool {
  let edges : Map[String, Array[String]] = Map([])
  for rule in self.rules {
    match edges.get(rule.from_state) {
      Some(outgoing) => outgoing.push(rule.to_state)
      None => edges.set(rule.from_state, [rule.to_state])
    }
  }
  let color : Map[String, Int32] = Map([])
  fn visit(state : String) -> Bool {
    match color.get(state) {
      Some(1) => true
      Some(_) => false
      None => {
        color.set(state, 1)
        let mut found = false
        match edges.get(state) {
          Some(outgoing) =>
            for next in outgoing {
              if !found {
                found = visit(next)
              }
            }
          None => ()
        }
        color.set(state, 2)
        found
      }
    }
  }
  let mut cyclic = false
  for state, _ in edges {
    if !cyclic {
      cyclic = visit(state)
    }
  }
  cyclic
}
