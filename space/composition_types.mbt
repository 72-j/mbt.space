// ===== moonspace/space —— 组合运行形机型（series/parallel；feedback
// 已在 EffectSpace.loop_guard/router 面）=====
// 形态：数据驱动（役4 同款）——组合形是数据（gen 构造），解释在
// runtime。边界（装配役四钉③）：sync 非空 v1 不做；typed 生成物
// 不做；本包零业务词（R-4）。
//
// 源标记口径（钉②补）：ParallelEvent.side = 成员序语义（Left=成员
// 0 / Right=成员 1，构造序）；调度 = FIFO 公平轮转——boot 双发入
// 队，效应结果事件回排队尾，每步只进一个成员（tensor.md
// interleaving 的可执行化）；done 成员的排队事件静默排空。

///|
/// series 桥行（源相终态 → 目标相起步事件；与 feedback router/
/// 合同 StateEventBridge 三者同构异role——命名随role不随形）
pub(all) struct BridgeSpec {
  from_state : String
  to_event : String
}

///|
/// series 运行形：两相串继（源相跑完 → 桥行命中则合成 boot 进目标
/// 相；未命中 = 以源相报告收口，非红）
pub(all) struct SeriesForm {
  name : String
  source : EffectSpace
  target : EffectSpace
  bridges : Array[BridgeSpec]
}

///|
/// parallel 源标记（成员序语义：Left = 成员 0 / Right = 成员 1）
pub(all) enum ParallelSide {
  Left
  Right
}

///|
/// parallel 事件（源标记 + 成员事件）
pub(all) struct ParallelEvent {
  side : ParallelSide
  event : LoopEvent
}

///|
/// parallel 运行形：双成员 interleaving。reachable = 构造期 BFS 剪枝
/// 后可达状态对（数学：interleaving 积可达集 = Π 成员可达集——剪枝
/// 咬合点 = 成员声明态 ⊋ 可达态；independent 推进下声明全可达时无
/// 剪效，机制照样在册）
pub(all) struct ParallelForm {
  name : String
  member0 : EffectSpace
  member1 : EffectSpace
  sync : Array[String]
  reachable : Array[(String, String)]
}

///|
/// boot 事件合成（任意目标事件名）：payload 字段按名取 ctx，缺键
/// 缺省 Text("")——series 桥接 boot 与 feedback LoopBack 同款投影
/// （v1 规则，携带策略扩展待裁 spec.md A4）
pub fn EffectSpace::event_boot(
  self : EffectSpace,
  event_name : String,
  ctx : Map[String, CtxValue],
) -> LoopEvent {
  let payload : Map[String, CtxValue] = Map([])
  match self.event_spec(event_name) {
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
  { name: event_name, payload, }
}
