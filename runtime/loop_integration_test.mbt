// ===== moonspace/runtime —— 沙箱大 loop 集成门（黑盒）=====
// 口径：合同面吃 sample fixture（真实文件漂移由 gen 对照门钉，R-6）。
// 四环演示：线性闭环（args/assign/守卫/吸收态）/ feedback 有界闭环
// （max_rounds）/ 超时闭环（注入时钟跳变）/ 执行错逃逸拦停（拍③——
// 哨兵回执是正道，逃逸即 HandlerError 上报）。handler 直返形（拍①
// async 对位 CPS 单层）；时钟注入形 = Array 单元闭包（役R3 先例）。

///|
fn fixed_clock(tick : Array[Int64]) -> () -> Int64 {
  fn() { tick[0] }
}

///|
struct MockRetrievalHandler {
  hits : Array[String]
}

///|
impl EffectHandler for MockRetrievalHandler with fn handle(
  self : MockRetrievalHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  match effect.name {
    "BM25Search" =>
      { name: "BM25Done", payload: Map([("hits", Texts(self.hits))]), }
    "VectorSearch" =>
      { name: "VectorDone", payload: Map([("hits", Texts(self.hits))]), }
    other => fail("unexpected effect \{other}")
  }
}

///|
struct MockLLMHandler {
  tick : Array[Int64]
  advance_ms : Int64
}

///|
impl EffectHandler for MockLLMHandler with fn handle(
  self : MockLLMHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  self.tick[0] = self.tick[0] + self.advance_ms
  match effect.name {
    "LLMCall" =>
      { name: "ThinkDone", payload: Map([("text", Text("demo-answer"))]), }
    other => fail("unexpected effect \{other}")
  }
}

///|
struct MockFailingHandler {
  marker : Int32
}

///|
suberror MockBoomErr {
  Boom(String)
} derive(Debug)

///|
impl EffectHandler for MockFailingHandler with fn handle(
  self : MockFailingHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  ignore(self.marker)
  ignore(effect)
  raise Boom("执行错逃逸演示")
}

///|
fn reasoning_space() -> @space.EffectSpace raise {
  @gen.space_from_contract(
    @gen.sample_reasoning_base(),
    @gen.sample_reasoning_domain(),
    @gen.sample_composition().feedbacks,
  )
}

///|
fn no_guards() -> Map[String, (Map[String, @space.CtxValue]) -> Bool] {
  Map([])
}

///|
async test "线性闭环：Query→BM25→Vector→Done（args/assign/守卫/吸收态）" {
  let space = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  let tick : Array[Int64] = [0L]
  let guards : Map[String, (Map[String, @space.CtxValue]) -> Bool] = Map([
    ("has_hits", @verify.has_hits),
  ])
  let report = @runtime.run(
    space,
    MockRetrievalHandler::{ hits: ["doc1", "doc2"], },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    guards,
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
  )
  assert_eq(report.final_state, "Done")
  assert_eq(report.rounds, 3)
  assert_eq(report.audit.length(), 2)
  assert_eq(report.audit[0].effect_name, "BM25Search")
  assert_eq(report.audit[0].semantics, "query")
  assert_true(report.terminated_by is Completed)
}

///|
async test "守卫判否：hits 空 ⇒ DeadEnd(guard:has_hits)，无状态推进" {
  let space = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  let tick : Array[Int64] = [0L]
  let guards : Map[String, (Map[String, @space.CtxValue]) -> Bool] = Map([
    ("has_hits", @verify.has_hits),
  ])
  let report = @runtime.run(
    space,
    MockRetrievalHandler::{ hits: [], },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    guards,
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
  )
  assert_eq(report.final_state, "SearchingVector")
  assert_eq(report.rounds, 2)
  assert_eq(report.audit.length(), 2)
  assert_true(report.terminated_by is DeadEnd(_))
}

///|
async test "feedback 有界闭环：ReasoningLoop max_rounds=5 ⇒ MaxRounds，5 次 LLMCall" {
  let space = reasoning_space()
  let limits : @runtime.ResourceLimit = match space.loop_guard {
    Some(loop_guard) =>
      {
        max_rounds: loop_guard.max_rounds,
        timeout_ms: loop_guard.timeout_ms,
        effect_timeout_ms: 0,
        max_retries: 0,
      }
    None =>
      { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, }
  }
  assert_true(limits.max_rounds == 5)
  let tick : Array[Int64] = [0L]
  let report = @runtime.run(
    space,
    MockLLMHandler::{ tick, advance_ms: 0L, },
    limits,
    fixed_clock(tick),
    no_guards(),
    { name: "ContextReady", payload: Map([("context", Text("goal"))]), },
  )
  assert_eq(report.rounds, 5)
  assert_eq(report.audit.length(), 3) // 5 步 = 3 效应步 + 2 纯装填步(v1 轮径 = 步进次数)
  assert_eq(report.audit[0].effect_name, "LLMCall")
  assert_eq(report.audit[0].semantics, "command")
  assert_true(report.terminated_by is MaxRounds)
}

///|
async test "超时闭环：注入时钟跳变 ⇒ Timeout（预算面先于步进）" {
  let space = reasoning_space()
  let tick : Array[Int64] = [0L]
  let report = @runtime.run(
    space,
    MockLLMHandler::{ tick, advance_ms: 40000L, },
    { max_rounds: 0, timeout_ms: 30000, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    no_guards(),
    { name: "ContextReady", payload: Map([("context", Text("goal"))]), },
  )
  assert_eq(report.rounds, 1)
  assert_eq(report.audit.length(), 1)
  assert_true(report.terminated_by is Timeout)
}

///|
async test "执行错逃逸：handler raise ⇒ HandlerError 拦停（哨兵回执是正道，逃逸即上报）" {
  let space = reasoning_space()
  let tick : Array[Int64] = [0L]
  let report = @runtime.run(
    space,
    MockFailingHandler::{ marker: 1, },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    no_guards(),
    { name: "ContextReady", payload: Map([("context", Text("goal"))]), },
  )
  assert_eq(report.rounds, 1)
  assert_eq(report.audit.length(), 1)
  assert_eq(report.audit[0].outcome, "failed")
  assert_true(report.terminated_by is HandlerError(_))
}

// ===== R-2 补全役判据钉（2026-10-11）——B1 取消 / B2 效应超时 / 重试面 /
// B3 观测流 / C1 DeadEnd 分型。替身本地重定义（测试件三手病③）。

///|
/// 可编程失败替身：fail_first 次数内对全部效应 raise，其后放行；
/// sleep_ms 每效应先睡（B2 事后判的墙钟推进）。
struct FlakyRetrievalHandler {
  hits : Array[String]
  mut fail_first : Int32
  sleep_ms : Int32
}

///|
impl EffectHandler for FlakyRetrievalHandler with fn handle(
  self : FlakyRetrievalHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  if self.sleep_ms > 0 {
    @async.sleep(self.sleep_ms)
  }
  if self.fail_first > 0 {
    self.fail_first = self.fail_first - 1
    raise Boom("flaky by script")
  }
  match effect.name {
    "BM25Search" =>
      { name: "BM25Done", payload: Map([("hits", Texts(self.hits))]), }
    "VectorSearch" =>
      { name: "VectorDone", payload: Map([("hits", Texts(self.hits))]), }
    other => fail("unexpected effect \{other}")
  }
}

///|
fn retrieval_pair() -> (
  @space.EffectSpace,
  Map[String, (Map[String, @space.CtxValue]) -> Bool],
) raise {
  let guards : Map[String, (Map[String, @space.CtxValue]) -> Bool] = Map([
    ("has_hits", @verify.has_hits),
  ])
  (
    @gen.space_from_contract(
      @gen.sample_retrieval_base(),
      @gen.sample_retrieval_domain(),
      [],
    ),
    guards,
  )
}

///|
async test "B1 取消面：should_cancel 恒真 ⇒ Cancelled（效应边界协作式）" {
  let (space, guards) = retrieval_pair()
  let report = @runtime.run(
    space,
    MockRetrievalHandler::{ hits: ["doc1"], },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fn() { 0L },
    guards,
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
    observer=None,
    should_cancel=Some(fn() { true }),
  )
  assert_true(report.terminated_by is Cancelled)
}

///|
async test "C1 DeadEnd 分型：NoRule 臂带 state+event 载荷（替代前缀解析）" {
  let (space, guards) = retrieval_pair()
  let report = @runtime.run(
    space,
    MockRetrievalHandler::{ hits: ["doc1"], },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fn() { 0L },
    guards,
    { name: "Bogus", payload: Map([]), },
    observer=None,
    should_cancel=None,
  )
  match report.terminated_by {
    DeadEnd(NoRule(state~, event~)) => {
      assert_eq(state, "Idle")
      assert_eq(event, "Bogus")
    }
    _ => fail("expect DeadEnd(NoRule)")
  }
}

///|
async test "B2 效应级超时：effect_timeout_ms 事后判 ⇒ Timeout + audit timeout" {
  let (space, guards) = retrieval_pair()
  let report = @runtime.run(
    space,
    FlakyRetrievalHandler::{ hits: ["doc1"], fail_first: 0, sleep_ms: 50, },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 10, max_retries: 0, },
    fn() { @async.now() },
    guards,
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
    observer=None,
    should_cancel=None,
  )
  assert_true(report.terminated_by is Timeout)
  let last = report.audit[report.audit.length() - 1]
  assert_eq(last.outcome, "timeout")
}

///|
async test "重试面：fail_first=1 + max_retries=1 ⇒ 次次放行后成功，attempt=2 在账" {
  let (space, guards) = retrieval_pair()
  let report = @runtime.run(
    space,
    FlakyRetrievalHandler::{ hits: ["doc1"], fail_first: 1, sleep_ms: 0, },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 1, },
    fn() { 0L },
    guards,
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
    observer=None,
    should_cancel=None,
  )
  assert_true(report.terminated_by is Completed)
  let first = report.audit[0]
  assert_eq(first.attempt, 2)
  assert_eq(first.outcome, "completed")
}

///|
async test "B3 观测流：首观测 StepStarted / 末观测 Finished 序列断言" {
  let (space, guards) = retrieval_pair()
  let seen : Array[@runtime.Observation] = []
  let report = @runtime.run(
    space,
    MockRetrievalHandler::{ hits: ["doc1"], },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fn() { 0L },
    guards,
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
    observer=Some(fn(obs) { seen.push(obs) }),
    should_cancel=None,
  )
  assert_true(report.terminated_by is Completed)
  match seen[0] {
    StepStarted(round~, state~, event~) => {
      assert_eq(round, 0)
      assert_eq(state, "Idle")
      assert_eq(event, "Query")
    }
    _ => fail("expect StepStarted first")
  }
  match seen[seen.length() - 1] {
    Finished(round=_, state=_, termination=why) => assert_true(why is Completed)
    _ => fail("expect Finished last")
  }
}
