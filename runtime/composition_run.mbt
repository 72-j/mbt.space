// ===== moonspace/runtime —— 组合 runner（series 串继 + parallel
// interleaving；役4 单空间 run 的组合面兄弟件）=====
// 形态裁定（装配役四钉）：数据驱动——形是 gen 构造的数据（SeriesForm/
// ParallelForm），本包只解释。面界不动（R-7）：只向下依赖 space。
//
// series 口径（钉①补）：源相跑完（Completed）→ 桥行按 from_state 命
// 中 → 合成目标 boot（to_event payload ← 源相 final_ctx 同名投影，
// 缺键缺省空文本——LoopBack v1 同款）→ 目标相起步；桥未命中 = 以源
// 相报告收口（bridge_fired=false，非红）。handler 同实例跨相（轨迹
// 连续）；预算两相各自生效（rounds 累加）。
//
// parallel 口径（钉②补）：源标记 = 成员序（Left=0/Right=1）；调度 =
// FIFO 公平轮转——boot 双发入队，效应结果事件回排队尾，每步只进一
// 个成员；done 成员（吸收态到达）的排队事件静默排空；队列空 + 双
// done = Completed，单 done = DeadEnd(stall)。守卫拒否/无规则（非
// done 成员）= 整体 DeadEnd 收口（不静默吞判否，与单空间口径一致）。

///|
/// series 终报（bridge_fired = 桥接是否发生；rounds = 两相累加）
pub struct SeriesReport {
  final_state : String
  rounds : Int32
  terminated_by : Termination
  audit : Array[AuditRecord]
  bridge_fired : Bool
}

///|
/// series 串继：run(源) → 桥 → run(目标)。守卫面/预算面/时钟两相
/// 同参（装配位裁定面）。
pub async fn[T : EffectHandler] run_series(
  form : @space.SeriesForm,
  handler : T,
  limits : ResourceLimit,
  clock : () -> Int64,
  guards : Map[String, (Map[String, @space.CtxValue]) -> Bool],
  boot : @space.LoopEvent,
) -> SeriesReport {
  let report_source = run(form.source, handler, limits, clock, guards, boot)
  if report_source.terminated_by is Completed {
    let mut bridge_found : @space.BridgeSpec? = None
    for bridge in form.bridges {
      if bridge.from_state == report_source.final_state {
        bridge_found = Some(bridge)
      }
    }
    match bridge_found {
      Some(bridge) => {
        let boot_target = form.target.event_boot(
          bridge.to_event,
          report_source.final_ctx,
        )
        let report_target = run(
          form.target,
          handler,
          limits,
          clock,
          guards,
          boot_target,
        )
        let audit_all : Array[AuditRecord] = []
        for record in report_source.audit {
          audit_all.push(record)
        }
        for record in report_target.audit {
          audit_all.push(record)
        }
        {
          final_state: report_target.final_state,
          rounds: report_source.rounds + report_target.rounds,
          terminated_by: report_target.terminated_by,
          audit: audit_all,
          bridge_fired: true,
        }
      }
      None =>
        {
          final_state: report_source.final_state,
          rounds: report_source.rounds,
          terminated_by: report_source.terminated_by,
          audit: report_source.audit,
          bridge_fired: false,
        }
    }
  } else {
    {
      final_state: report_source.final_state,
      rounds: report_source.rounds,
      terminated_by: report_source.terminated_by,
      audit: report_source.audit,
      bridge_fired: false,
    }
  }
}

///|
/// 单成员一步的结局：Advanced = 组合继续（回调用方排队/轮转）；
/// Fatal = 组合面收口（该成员判否/无规则/效应逃逸——不静默吞）。
priv enum MemberOutcome {
  Advanced(
    String, // next_state
    Map[String, @space.CtxValue], // next_ctx
    Int32, // next_rounds
    Bool, // member_done（落吸收态）
    @space.LoopEvent?
  ) // 效应结果事件（回排队尾）
  Fatal(Termination)
}

///|
/// parallel 终报（state0/state1 = 两成员终态；rounds = 全成员累加）
pub struct ParallelReport {
  state0 : String
  state1 : String
  rounds : Int32
  terminated_by : Termination
  audit : Array[AuditRecord]
}

///|
/// parallel interleaving：FIFO 公平轮转。一步 = 一个成员的一次步进
/// （效应步的解释+结果回排队尾 = 成员续轮；纯装填步落吸收态 = 该
/// 成员 done）。
pub async fn[T : EffectHandler] run_parallel(
  form : @space.ParallelForm,
  handler : T,
  limits : ResourceLimit,
  clock : () -> Int64,
  guards : Map[String, (Map[String, @space.CtxValue]) -> Bool],
  boot0 : @space.LoopEvent,
  boot1 : @space.LoopEvent,
) -> ParallelReport {
  let audit : Array[AuditRecord] = []
  let outcome : Array[ParallelReport] = []
  let started_ms = clock()
  let queue : Array[@space.ParallelEvent] = [
    { side: Left, event: boot0, },
    { side: Right, event: boot1, },
  ]
  let mut head = 0
  let budget_ms = limits.timeout_ms
  fn finish(
    s0 : String,
    s1 : String,
    rounds : Int32,
    why : Termination,
  ) -> Unit {
    outcome.push({ state0: s0, state1: s1, rounds, terminated_by: why, audit, })
  }
  fn budget_hit(rounds : Int32) -> Termination? {
    let rounds_exhausted = limits.max_rounds > 0 && rounds >= limits.max_rounds
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
  // 单成员一步（当前态入参；结局返回，排队权在 pump）
  async fn exec_member(
    space : @space.EffectSpace,
    state : String,
    event : @space.LoopEvent,
    ctx : Map[String, @space.CtxValue],
    rounds : Int32,
  ) -> MemberOutcome {
    match space.step(state, event, ctx, guards) {
      NoRule => Fatal(DeadEnd(NoRule(state~, event=event.name)))
      GuardRejected(guard_name) =>
        Fatal(DeadEnd(GuardRejected(name=guard_name)))
      MissingGuard(guard_name) => Fatal(DeadEnd(MissingGuard(name=guard_name)))
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
        let next_state = step_result.next_state
        let member_done = space.is_absorbing(next_state)
        match step_result.effect {
          Some(effect) => {
            let semantics = space.effect_semantics_of(effect.name)
            let effect_started = clock()
            let mut failure : String? = None
            let mut result_event : @space.LoopEvent? = None
            try {
              let completed = handler.handle(effect)
              result_event = Some(completed)
            } catch {
              err => failure = Some("\{err}")
            }
            match failure {
              Some(detail) => {
                audit.push({
                  round: next_rounds,
                  effect_name: effect.name,
                  semantics,
                  started_ms: effect_started,
                  finished_ms: clock(),
                  attempt: 1,
                  result_event: "",
                  outcome: "failed",
                })
                Fatal(HandlerError(detail))
              }
              None => {
                audit.push({
                  round: next_rounds,
                  effect_name: effect.name,
                  semantics,
                  started_ms: effect_started,
                  finished_ms: clock(),
                  attempt: 1,
                  result_event: match result_event {
                    Some(ev) => ev.name
                    None => ""
                  },
                  outcome: "completed",
                })
                Advanced(
                  next_state, next_ctx, next_rounds, member_done, result_event,
                )
              }
            }
          }
          None => Advanced(next_state, next_ctx, next_rounds, member_done, None)
        }
      }
    }
  }
  // 主轮转：FIFO 队列驱动的单层递归
  async fn pump(
    s0 : String,
    s1 : String,
    done0 : Bool,
    done1 : Bool,
    ctx : Map[String, @space.CtxValue],
    rounds : Int32,
  ) -> Unit {
    match budget_hit(rounds) {
      Some(why) => finish(s0, s1, rounds, why)
      None =>
        if head >= queue.length() {
          if done0 && done1 {
            finish(s0, s1, rounds, Completed)
          } else {
            let waiting = if done0 { "right" } else { "left" }
            finish(s0, s1, rounds, DeadEnd(Stall(state=waiting)))
          }
        } else {
          let item = queue[head]
          head = head + 1
          match item.side {
            Left =>
              if done0 {
                pump(s0, s1, done0, done1, ctx, rounds)
              } else {
                let outcome_member = exec_member(
                  form.member0,
                  s0,
                  item.event,
                  ctx,
                  rounds,
                )
                match outcome_member {
                  Fatal(why) => finish(s0, s1, rounds, why)
                  Advanced(
                    next_state,
                    next_ctx,
                    next_rounds,
                    member_done,
                    feedback
                  ) => {
                    match feedback {
                      Some(feedback_event) =>
                        queue.push({ side: Left, event: feedback_event, })
                      None => ()
                    }
                    pump(
                      next_state, s1, member_done, done1, next_ctx, next_rounds,
                    )
                  }
                }
              }
            Right =>
              if done1 {
                pump(s0, s1, done0, done1, ctx, rounds)
              } else {
                let outcome_member = exec_member(
                  form.member1,
                  s1,
                  item.event,
                  ctx,
                  rounds,
                )
                match outcome_member {
                  Fatal(why) => finish(s0, s1, rounds, why)
                  Advanced(
                    next_state,
                    next_ctx,
                    next_rounds,
                    member_done,
                    feedback
                  ) => {
                    match feedback {
                      Some(feedback_event) =>
                        queue.push({ side: Right, event: feedback_event, })
                      None => ()
                    }
                    pump(
                      s0, next_state, done0, member_done, next_ctx, next_rounds,
                    )
                  }
                }
              }
          }
        }
    }
  }
  pump(
    form.member0.initial_state,
    form.member1.initial_state,
    false,
    false,
    Map([]),
    0,
  )
  outcome[0]
}
