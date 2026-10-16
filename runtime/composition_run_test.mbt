// ===== moonspace/runtime —— 组合 runner 集成门（黑盒）=====
// series 串继（桥接相变 + 两相轮径累加 + 无桥收口）+ parallel
// FIFO 公平轮转（双成员自积跑通 + 双 done Completed）。合同面吃
// sample fixture（真实文件漂移由 gen 对照门钉）。

///|
struct SeriesMockHandler {
  tag : Int32
}

///|
impl EffectHandler for SeriesMockHandler with fn handle(
  self : SeriesMockHandler,
  effect : @space.LoopEffect,
) -> @space.LoopEvent raise {
  ignore(self.tag)
  match effect.name {
    "BM25Search" =>
      { name: "BM25Done", payload: Map([("hits", Texts(["doc1"]))]), }
    "VectorSearch" =>
      { name: "VectorDone", payload: Map([("hits", Texts(["doc1"]))]), }
    "LLMCall" =>
      { name: "ThinkDone", payload: Map([("text", Text("series-answer"))]), }
    other => fail("unexpected effect \{other}")
  }
}

///|
async test "series 串继：Done 桥接 ContextReady——两相贯通 rounds=5" {
  let source = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  let target = @gen.space_from_contract(
    @gen.sample_reasoning_base(),
    @gen.sample_reasoning_domain(),
    [],
  )
  let form : @space.SeriesForm = {
    name: "DemoSeries",
    source,
    target,
    bridges: [{ from_state: "Done", to_event: "ContextReady", }],
  }
  let tick : Array[Int64] = [0L]
  let report = @runtime.run_series(
    form,
    SeriesMockHandler::{ tag: 1, },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    Map([("has_hits", @verify.has_hits)]),
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
  )
  assert_eq(report.final_state, "Answered")
  assert_eq(report.rounds, 5) // 源相 3 + 目标相 2
  assert_eq(report.audit.length(), 3) // 源相 2 效应 + 目标相 1 效应
  assert_true(report.bridge_fired)
  assert_true(report.terminated_by is Completed)
}

///|
async test "series 无桥：源相终态收口（bridge_fired=false 非红）" {
  let source = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  let target = @gen.space_from_contract(
    @gen.sample_reasoning_base(),
    @gen.sample_reasoning_domain(),
    [],
  )
  let form : @space.SeriesForm = {
    name: "NoBridgeSeries",
    source,
    target,
    bridges: [],
  }
  let tick : Array[Int64] = [0L]
  let report = @runtime.run_series(
    form,
    SeriesMockHandler::{ tag: 1, },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    Map([("has_hits", @verify.has_hits)]),
    { name: "Query", payload: Map([("text", Text("moonbit"))]), },
  )
  assert_eq(report.final_state, "Done")
  assert_eq(report.rounds, 3)
  assert_true(report.bridge_fired is false)
}

///|
async test "parallel 轮转：双 retrieval 自积 interleaving——双 done Completed rounds=6" {
  let space_member = @gen.space_from_contract(
    @gen.sample_retrieval_base(),
    @gen.sample_retrieval_domain(),
    [],
  )
  let form : @space.ParallelForm = {
    name: "DemoParallel",
    member0: space_member,
    member1: space_member,
    sync: [],
    reachable: [],
  }
  let tick : Array[Int64] = [0L]
  let report = @runtime.run_parallel(
    form,
    MockRetrievalHandler::{ hits: ["doc1"], },
    { max_rounds: 0, timeout_ms: 0, effect_timeout_ms: 0, max_retries: 0, },
    fixed_clock(tick),
    Map([("has_hits", @verify.has_hits)]),
    { name: "Query", payload: Map([("text", Text("left"))]), },
    { name: "Query", payload: Map([("text", Text("right"))]), },
  )
  assert_eq(report.state0, "Done")
  assert_eq(report.state1, "Done")
  assert_eq(report.rounds, 6) // 每成员 3 步，公平轮转累加
  assert_eq(report.audit.length(), 4) // 每成员 2 效应
  assert_true(report.terminated_by is Completed)
}
