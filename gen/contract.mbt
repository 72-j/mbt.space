// ===== moonspace/gen —— 域合同结构体（TOML 字段配置的可执行镜像）=====
// moonspace/domain/*.toml 的字段契约钉在这里；解析器（@toml 0.5）
// 随解析役落。持久合同规则（宪法）：新键可选（解析器缺省）；
// 未知键忽略；删键/改义须同笔迁移手写 TOML。
// 保留字避让两处：type -> type_，guard -> guard_name / loop_guard。
// derive(Eq, Debug)：对照门逐字段全等断言 + 失败输出（解析役）。

///|
/// [meta] 面（五文件共有）
pub struct ContractMeta {
  schema_version : String
  space_version : String?
  name : String
  dialect : String?
  prefix : String
} derive(Eq, Debug)

///|
/// [space] 策略面（*_base.toml）
pub struct SpacePolicy {
  strategy : String
  effects_trait_open : Bool
  interpretation : String
} derive(Eq, Debug)

///|
/// [[space.context]] 槽位声明；semantics 现役值域 = slot
pub struct CtxField {
  name : String
  type_ : String
  semantics : String?
  doc : String?
} derive(Eq, Debug)

///|
/// payload 字段（事件/效应共用；TOML 形 { name, type }）
pub struct PayloadField {
  name : String
  type_ : String
} derive(Eq, Debug)

///|
/// [[space.events]]：声明序即枚举序；payload 可省
pub struct EventDecl {
  name : String
  payload : Array[PayloadField]
} derive(Eq, Debug)

///|
/// [[space.effects]]：semantics 封闭词表（值域见 space 包
/// effect_semantics）；缺省 = command（保守面）
pub struct EffectDecl {
  name : String
  semantics : String
  payload : Array[PayloadField]
} derive(Eq, Debug)

///|
/// [[space.guards]]：具名守卫声明（C-21 白盒面）
pub struct GuardDecl {
  name : String
  doc : String?
} derive(Eq, Debug)

///|
/// [[space.states]]：声明序即枚举序；is_initial 全表恰一
pub struct StateDecl {
  name : String
  is_initial : Bool
  doc : String?
} derive(Eq, Debug)

///|
/// [[space.transitions]]：守卫转移四行属性 guard/assign/args/effect。
/// args = effect 实参投影（按位取事件 payload 字段名）；assign =
/// 落槽投影（槽位名默认取 payload 同名字段；异名经 assign_from
/// 显式映射——同名省略，异名显式，2026-10-11 拍）；guard 判转移前 ctx。
pub struct TransitionDecl {
  from_state : String
  on_event : String
  to_state : String
  effect : String?
  args : Array[String]
  assign : Array[String]
  assign_from : Array[AssignFrom]
  guard_name : String?
  doc : String?
} derive(Eq, Debug)

///|
/// assign 异名显式映射行：slot ∈ assign 列表；from_field ∈ 事件
/// payload 字段（同名字段不存在时的落槽来源）
pub struct AssignFrom {
  slot : String
  from_field : String
} derive(Eq, Debug)

///|
/// [[space.invariants]]：名字面（谓词本体在 verify 包手写）
pub struct InvariantDecl {
  name : String
  doc : String?
} derive(Eq, Debug)

///|
/// 骨架文件（*_base.toml）整体
pub struct SpaceBase {
  meta : ContractMeta
  policy : SpacePolicy
  context : Array[CtxField]
  events : Array[EventDecl]
  effects : Array[EffectDecl]
  guards : Array[GuardDecl]
  states : Array[StateDecl]
} derive(Eq, Debug)

///|
/// [[space.cell]]：USA 方言注册声明（格1，USA §8）。构造期合同门 =
/// effect/error_event ∈ 阳集 + form ∈ v1 闭合集 + fields 非空（D拍）。
pub(all) struct CellDecl {
  name : String
  effect : String
  form : String
  fields : Array[String]
  error_event : String
  doc : String?
} derive(Eq, Debug)

///|
/// 行为文件（*_domain.toml）整体；meta.name 与配对 base 一致
pub struct SpaceDomain {
  meta : ContractMeta
  transitions : Array[TransitionDecl]
  invariants : Array[InvariantDecl]
  cells : Array[CellDecl]
} derive(Eq, Debug)

///|
/// 状态到事件的桥（series 桥接行与 feedback 回送行共用形）
pub struct StateEventBridge {
  from_state : String
  to_event : String
} derive(Eq, Debug)

///|
/// [[parallel]]：张量积（笛卡尔积 + interleaving；gen 必做可达性剪枝）
pub struct ParallelDecl {
  name : String
  spaces : Array[String]
  sync : Array[String]
  merge_effects : String
} derive(Eq, Debug)

///|
/// [[series]]：串联（源终止态经 adapter 触发目标起始事件）
pub struct SeriesDecl {
  name : String
  source : String
  target : String
  adapter : Array[StateEventBridge]
} derive(Eq, Debug)

///|
/// [feedback.guard]：守卫必填（两值至少启用其一；0 = 不启用）
pub struct FeedbackGuard {
  max_rounds : Int32
  timeout_ms : Int32
} derive(Eq, Debug)

///|
/// [[feedback]]：反馈（显式 LoopBack 事件回送；禁任意 continuation 捕获）
pub struct FeedbackDecl {
  name : String
  space : String
  router : Array[StateEventBridge]
  loop_guard : FeedbackGuard?
} derive(Eq, Debug)

///|
/// 组合文件（composition.toml）整体；space 名须闭合到已声明文件对
pub struct Composition {
  meta : ContractMeta
  parallels : Array[ParallelDecl]
  series : Array[SeriesDecl]
  feedbacks : Array[FeedbackDecl]
} derive(Eq, Debug)
