// ===== moonspace/runtime —— Runtime Sandbox（运行空间沙箱）=====
// 职责：约束副作用执行——Port 权限/资源限制/超时/重试/审计，防
// effect 逃逸到生产数据（.mingspace/sandbox.md 划界）。
//
// 形态裁定（役4，勘 moonagentic 消费面后拍）：
//   ① async 化——EffectHandler 直返形（async 对位 CPS 单层：每效应
//     恰一次解释、结果事件立返喂回；禁嵌套/禁捕获语义不变，R-2）。
//     对位 moonagentic LLMProvider.chat async 面。
//   ③ 执行错哨兵回执（moonagentic dispatch_one 先例）：handler 域内错
//     **应自转哨兵事件回灌**（正道）；逃逸错 ⇒ Runner HandlerError
//     拦停上报（审计 outcome="failed"），与合同面停摆（DeadEnd）
//     分列（R-8）。
//   ④ 端口中立：moonagentic 适配（SpaceHandler/PolicyEngine 翻译）落
//     对方 cmd/X3 装配位，本包不见业务词（R-4）。
//
// v1 口径（A4 在册）：LoopBack 仅纯装填步到达 router 源态触发；
// LoopBack payload = to_event payload 字段按名取 ctx，缺键缺省空文本；
// handler 同步完成语义由 async 直返天然保证。
// 预算：max_rounds/timeout_ms/effect_timeout_ms/max_retries 皆 0 =
// 不启用该项——空间有环且全零 = 入口门拦停（moonagentic 评审 A3，
// UnboundedCycle；原"自担"口径升级为机械钉）。
//
// R-2 补全役（2026-10-11，六件一次拍掉）：
//   B1 取消面——should_cancel 注入，每步进边界查（协作式：调用中的
//     handler 请求不可中断，下一效应边界生效——MoonBit async 单线程
//     协程模型下 zerostack 真 abort 的诚实对位）；触发 ⇒ Cancelled。
//   B2 效应级超时——effect_timeout_ms 事后判（handler await 中不可
//     抢占，返回后查 elapsed；超时即 Timeout 终止，audit outcome=
//     "timeout"）——R-2 裁定"回调面带超时"的现役兑现。
//   B3 观测流——observer 可选回调（StepStarted/EffectFinished/
//     Finished 三观测点）；A1 上报通道以此兑现（观测+审计即上报）。
//   C1 DeadEnd 分型——DeadEndKind 子变体（NoRule/GuardRejected/
//     MissingGuard/Stall），替代前缀字符串解析（"Error Show variant-only
//     丢载荷"同病治理）。
//   C2 AuditRecord 加宽——round/result_event/attempt 三字段（回放价值，
//     R-1 "回放不可信"防线的兑现位）。
//   重试面——max_retries：handler raise 后重试 N 次（attempt 入账），
//     全败才 HandlerError 逃逸。

///|
/// 效应解释 port（跨包 Port 实现面，pub(open)）——直返结果事件；
/// 域内错自转哨兵事件（moonagentic 哨兵回执先例），禁随意 raise 逃逸。
pub(open) trait EffectHandler {
  async fn handle(self : Self, effect : @space.LoopEffect) -> @space.LoopEvent
}

///|
/// 资源限制（0 = 不启用该项）
pub(all) struct ResourceLimit {
  max_rounds : Int32
  timeout_ms : Int32
  effect_timeout_ms : Int32 // B2：单效应墙钟上限（事后判）
  max_retries : Int32 // 重试面：handler raise 后追加尝试次数
}

///|
/// 审计记录（每效应一条；round = 步进序号；attempt = 重试序号 1 起；
/// result_event = 结果事件名，失败/超时为空串）
pub struct AuditRecord {
  round : Int32
  effect_name : String
  semantics : String
  started_ms : Int64
  finished_ms : Int64
  attempt : Int32
  result_event : String
  outcome : String // "completed" / "failed" / "timeout"
}

///|
/// 合同面停摆分型（C1——替代前缀字符串，消费方 match 穷尽分诊）
pub(all) enum DeadEndKind {
  NoRule(state~ : String, event~ : String)
  GuardRejected(name~ : String)
  MissingGuard(name~ : String)
  Stall(state~ : String)
}

///|
/// 终结形态：Completed = 吸收态到达；MaxRounds/Timeout = 预算拦停；
/// Cancelled = 取消令牌触发（B1，效应边界协作式）；DeadEnd = 合同面
/// 停摆（分型见 DeadEndKind）；HandlerError = 执行错逃逸（重试全败后）。
pub(all) enum Termination {
  Completed
  MaxRounds
  Timeout
  Cancelled
  DeadEnd(DeadEndKind)
  HandlerError(String)
}

///|
/// 观测流事件（B3——实时轨迹；A1 上报通道的兑现位）
pub(all) enum Observation {
  StepStarted(round~ : Int32, state~ : String, event~ : String)
  EffectFinished(
    round~ : Int32,
    effect~ : String,
    outcome~ : String,
    result_event~ : String
  )
  Finished(round~ : Int32, state~ : String, termination~ : Termination)
}

///|
/// loop 终报（rounds = 实际进入的步进次数；audit = 效应执行轨迹；
/// final_ctx = 终局 ctx——series 桥接 boot 投影的数据源）
pub struct LoopReport {
  final_state : String
  rounds : Int32
  terminated_by : Termination
  audit : Array[AuditRecord]
  final_ctx : Map[String, @space.CtxValue]
}

///|
/// run 入口门错（moonagentic 评审 A3：环 × 双零预算组合拦停）
pub(all) suberror RunGateError {
  UnboundedCycle(space~ : String)
} derive(Debug)

///|
pub extend RunGateError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// 沙箱大 loop（单空间 EffectSpace + feedback 回送 + 四预算 + 审计 +
/// 取消 + 观测）。CPS 单层 async 对位：boot 事件起步 → step → 有效应
/// 则 handler 解释（失败重试）→ 结果事件喂回续步 → 纯装填步到达 router
/// 源态则显式 LoopBack → 吸收态完成 / 预算拦停 / 取消 / 停摆上报。
/// 入口双门（moonagentic 评审 A2/A3）：守卫闭合核对（缺谓词入口拦停，
/// 不等运行中 MissingGuard 停摆）+ 环×双零预算组合门（规则图有环且
/// 轮径/墙钟双零 = 无界自担，UnboundedCycle 拦停）。
pub async fn[T : EffectHandler] run(
  space : @space.EffectSpace,
  handler : T,
  limits : ResourceLimit,
  clock : () -> Int64,
  guards : Map[String, (Map[String, @space.CtxValue]) -> Bool],
  boot : @space.LoopEvent,
  observer~ : ((Observation) -> Unit)? = None,
  should_cancel~ : (() -> Bool)? = None,
) -> LoopReport {
  space.check_guards_closed(guards)
  if space.has_transition_cycle() &&
    limits.max_rounds <= 0 &&
    limits.timeout_ms <= 0 {
    raise UnboundedCycle(space=space.name)
  }
  let audit : Array[AuditRecord] = []
  let outcome : Array[LoopReport] = []
  let started_ms = clock()
  fn observe(obs : Observation) -> Unit {
    match observer {
      Some(observe_fn) => observe_fn(obs)
      None => ()
    }
  }
  fn finish(
    state : String,
    rounds : Int32,
    why : Termination,
    ctx : Map[String, @space.CtxValue],
  ) -> Unit {
    observe(Finished(round=rounds, state~, termination=why))
    outcome.push({
      final_state: state,
      rounds,
      terminated_by: why,
      audit,
      final_ctx: ctx,
    })
  }
  fn budget_hit(rounds : Int32) -> Termination? {
    // B1 取消令牌：效应边界协作式查（先于预算——用户意志优先于预算）
    match should_cancel {
      Some(check) => if check() { return Some(Cancelled) }
      None => ()
    }
    let rounds_exhausted = limits.max_rounds > 0 && rounds >= limits.max_rounds
    let budget_ms = limits.timeout_ms
    let time_exhausted = budget_ms > 0 &&
      clock() - started_ms > budget_ms.to_int64()
    if rounds_exhausted {
      Some(MaxRounds)
    } else if time_exhausted {
      Some(Timeout)
    } else {
      None
    }
  }
  async fn loop_step(
    state : String,
    ctx : Map[String, @space.CtxValue],
    event : @space.LoopEvent,
    rounds : Int32,
  ) -> Unit {
    observe(StepStarted(round=rounds, state~, event=event.name))
    match budget_hit(rounds) {
      Some(why) => finish(state, rounds, why, ctx)
      None =>
        match space.step(state, event, ctx, guards) {
          NoRule => {
            // 吸收态优雅吞事件：终局态收到多余事件 = 优雅完成而非死角
            // （格3b 真网首演实录：LLM 出的机进 Answered 后多余
            //   CheckGreen → no_rule DeadEnd；结构合法但语义应视为完成）
            let is_abs = {
              let mut has_out = false
              for rule in space.rules {
                if rule.from_state == state {
                  has_out = true
                  break
                }
              }
              !has_out
            }
            if is_abs {
              finish(state, rounds, Completed, ctx)
            } else {
              finish(
                state,
                rounds,
                DeadEnd(NoRule(state~, event=event.name)),
                ctx,
              )
            }
          }
          GuardRejected(guard_name) =>
            finish(state, rounds, DeadEnd(GuardRejected(name=guard_name)), ctx)
          MissingGuard(guard_name) =>
            finish(state, rounds, DeadEnd(MissingGuard(name=guard_name)), ctx)
          Stepped(step_result) => {
            let next_ctx : Map[String, @space.CtxValue] = Map([])
            for key, value in ctx {
              next_ctx.set(key, value)
            }
            for assign in step_result.assigns {
              let (slot, value) = assign
              next_ctx.set(slot, value)
            }
            let next_rounds = rounds + 1
            match step_result.effect {
              Some(effect) => {
                let semantics = space.effect_semantics_of(effect.name)
                let next_state = step_result.next_state
                // 重试面：attempt 1..=1+max_retries，全败才逃逸
                let max_attempts = 1 +
                  (if limits.max_retries > 0 { limits.max_retries } else { 0 })
                let mut failure : String? = None
                let mut result_event : @space.LoopEvent? = None
                let mut audit_row : AuditRecord? = None
                for attempt in 1..<=max_attempts {
                  let effect_started = clock()
                  let mut attempt_failure : String? = None
                  let mut attempt_event : @space.LoopEvent? = None
                  try {
                    let completed = handler.handle(effect)
                    attempt_event = Some(completed)
                  } catch {
                    err => attempt_failure = Some("\{err}")
                  }
                  let finished_ms = clock()
                  let outcome = match attempt_failure {
                    Some(_) => "failed"
                    None =>
                      // B2 效应级超时（事后判——await 中不可抢占）
                      if limits.effect_timeout_ms > 0 &&
                        finished_ms - effect_started >
                        limits.effect_timeout_ms.to_int64() {
                        "timeout"
                      } else {
                        "completed"
                      }
                  }
                  audit_row = Some({
                    round: next_rounds,
                    effect_name: effect.name,
                    semantics,
                    started_ms: effect_started,
                    finished_ms,
                    attempt,
                    result_event: match attempt_event {
                      Some(ev) => ev.name
                      None => ""
                    },
                    outcome,
                  })
                  failure = attempt_failure
                  result_event = attempt_event
                  if outcome == "completed" {
                    break
                  }
                }
                let row = audit_row.unwrap()
                observe(
                  EffectFinished(
                    round=next_rounds,
                    effect=row.effect_name,
                    outcome=row.outcome,
                    result_event=row.result_event,
                  ),
                )
                audit.push(row)
                match failure {
                  Some(_) => {
                    // 重试全败：超时走 Timeout，其余走 HandlerError
                    let why = if row.outcome == "timeout" {
                      Timeout
                    } else {
                      HandlerError(failure.unwrap())
                    }
                    finish(next_state, next_rounds, why, next_ctx)
                  }
                  None =>
                    if row.outcome == "timeout" {
                      // 效应完成但超预算——预算面拦停（Timeout 终止）
                      finish(next_state, next_rounds, Timeout, next_ctx)
                    } else {
                      match result_event {
                        Some(result) =>
                          loop_step(next_state, next_ctx, result, next_rounds)
                        None => ()
                      }
                    }
                }
              }
              None =>
                match space.router_for(step_result.next_state) {
                  Some(router) => {
                    let loopback = space.make_loopback(router, next_ctx)
                    let target = space.loopback_target(router.to_event)
                    loop_step(target, next_ctx, loopback, next_rounds)
                  }
                  None =>
                    if space.is_absorbing(step_result.next_state) {
                      finish(
                        step_result.next_state,
                        next_rounds,
                        Completed,
                        next_ctx,
                      )
                    } else {
                      finish(
                        step_result.next_state,
                        next_rounds,
                        DeadEnd(Stall(state~)),
                        next_ctx,
                      )
                    }
                }
            }
          }
        }
    }
  }
  loop_step(space.initial_state, Map([]), boot, 0)
  outcome[0]
}
