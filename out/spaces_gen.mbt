// ===== moonspace/out · typed 产物（再生：moon run moonspace/cmd；黄金门 out/gen_gate_test.mbt 逐字节对拍；禁手写）=====

// ===== retrieval_space typed 产物（gen emit_space_typed 生成；禁手写）=====

///|
pub(all) enum RetrievalState {
  Idle
  SearchingBM25
  SearchingVector
  Done
}

///|
pub fn RetrievalState::initial() -> RetrievalState {
  Idle
}

///|
pub(all) enum RetrievalEvent {
  Query(String)
  BM25Done(Array[String])
  VectorDone(Array[String])
}

///|
pub(all) enum RetrievalEffect {
  BM25Search(String)
  VectorSearch(Array[String])
}

///|
pub(all) struct RetrievalCtx {
  query_text : String?
  hits : Array[String]
}

///|
pub fn RetrievalState::step(
  self : RetrievalState,
  ctx : RetrievalCtx,
  event : RetrievalEvent,
  guards : (String, RetrievalCtx) -> Bool,
) -> (RetrievalState, RetrievalCtx, RetrievalEffect?)? {
  match (self, event) {
    (Idle, Query(text)) => {
      let next_ctx : RetrievalCtx = { ..ctx, query_text: Some(text), }
      Some((SearchingBM25, next_ctx, Some(BM25Search(text))))
    }
    (SearchingBM25, BM25Done(hits)) => {
      let next_ctx : RetrievalCtx = { ..ctx, hits, }
      Some((SearchingVector, next_ctx, Some(VectorSearch(hits))))
    }
    (SearchingVector, VectorDone(hits)) => {
      if !guards("has_hits", ctx) {
        return None
      }
      let next_ctx : RetrievalCtx = { ..ctx, hits, }
      Some((Done, next_ctx, None))
    }
    (_, _) => None
  }
}

// ===== reasoning_space typed 产物（gen emit_space_typed 生成；禁手写）=====

///|
pub(all) enum ReasoningState {
  Waiting
  Thinking
  Answered
}

///|
pub fn ReasoningState::initial() -> ReasoningState {
  Waiting
}

///|
pub(all) enum ReasoningEvent {
  ContextReady(String)
  ThinkDone(String)
}

///|
pub(all) enum ReasoningEffect {
  LLMCall(String)
}

///|
pub(all) struct ReasoningCtx {
  prompt : String?
  answer : String?
  context : String?
}

///|
pub fn ReasoningState::step(
  self : ReasoningState,
  ctx : ReasoningCtx,
  event : ReasoningEvent,
  guards : (String, ReasoningCtx) -> Bool,
) -> (ReasoningState, ReasoningCtx, ReasoningEffect?)? {
  ignore(guards)
  match (self, event) {
    (Waiting, ContextReady(context)) => {
      let next_ctx : ReasoningCtx = { ..ctx, context: Some(context), prompt: Some(context), }
      Some((Thinking, next_ctx, Some(LLMCall(context))))
    }
    (Thinking, ThinkDone(text)) => {
      let next_ctx : ReasoningCtx = { ..ctx, answer: Some(text), }
      Some((Answered, next_ctx, None))
    }
    (_, _) => None
  }
}

// ===== agent_space typed 产物（gen emit_space_typed 生成；禁手写）=====

///|
pub(all) enum AgentState {
  Idle
  Thinking
  ToolCalling
  Answered
}

///|
pub fn AgentState::initial() -> AgentState {
  Idle
}

///|
pub(all) enum AgentEvent {
  GoalReady(String)
  LLMFinal(String)
  LLMToolCalls(Json)
  ToolDone(String, String)
  ToolDenied(String)
}

///|
pub(all) enum AgentEffect {
  LLMCall
  ToolExec(Json)
}

///|
pub(all) struct AgentCtx {
  goal : String?
  last_answer : String?
  last_tool : String?
}

///|
pub fn AgentState::step(
  self : AgentState,
  ctx : AgentCtx,
  event : AgentEvent,
  guards : (String, AgentCtx) -> Bool,
) -> (AgentState, AgentCtx, AgentEffect?)? {
  ignore(guards)
  match (self, event) {
    (Idle, GoalReady(goal)) => {
      let next_ctx : AgentCtx = { ..ctx, goal: Some(goal), }
      Some((Thinking, next_ctx, Some(LLMCall)))
    }
    (Thinking, LLMToolCalls(calls)) =>
      Some((ToolCalling, ctx, Some(ToolExec(calls))))
    (ToolCalling, ToolDone(tool, _)) => {
      let next_ctx : AgentCtx = { ..ctx, last_tool: Some(tool), }
      Some((Thinking, next_ctx, Some(LLMCall)))
    }
    (ToolCalling, ToolDenied(_)) => Some((Thinking, ctx, Some(LLMCall)))
    (Thinking, LLMFinal(answer)) => {
      let next_ctx : AgentCtx = { ..ctx, last_answer: Some(answer), }
      Some((Answered, next_ctx, None))
    }
    (_, _) => None
  }
}

// ===== vibe_space typed 产物（gen emit_space_typed 生成；禁手写）=====

///|
pub(all) enum VibeState {
  Idle
  Drafting
  Checking
  Fixing
  Answered
}

///|
pub fn VibeState::initial() -> VibeState {
  Idle
}

///|
pub(all) enum VibeEvent {
  TaskReady(String)
  ActDone(String)
  CheckGreen(String)
  CheckFailed(String)
}

///|
pub(all) enum VibeEffect {
  LLMAct(String)
  ShellCheck
}

///|
pub(all) struct VibeCtx {
  goal : String?
  check_reason : String?
  result_summary : String?
}

///|
pub fn VibeState::step(
  self : VibeState,
  ctx : VibeCtx,
  event : VibeEvent,
  guards : (String, VibeCtx) -> Bool,
) -> (VibeState, VibeCtx, VibeEffect?)? {
  ignore(guards)
  match (self, event) {
    (Idle, TaskReady(goal)) => {
      let next_ctx : VibeCtx = { ..ctx, goal: Some(goal), }
      Some((Drafting, next_ctx, Some(LLMAct(goal))))
    }
    (Drafting, ActDone(_)) => Some((Checking, ctx, Some(ShellCheck)))
    (Checking, CheckFailed(reason)) => {
      let next_ctx : VibeCtx = { ..ctx, check_reason: Some(reason), }
      Some((Fixing, next_ctx, Some(LLMAct(reason))))
    }
    (Fixing, ActDone(_)) => Some((Checking, ctx, Some(ShellCheck)))
    (Checking, CheckGreen(note)) => {
      let next_ctx : VibeCtx = { ..ctx, result_summary: Some(note), }
      Some((Answered, next_ctx, None))
    }
    (_, _) => None
  }
}

///|
/// cells（USA §8 方言注册；构造期合同门已核 error_event/effect ∈ 阳集）
pub(all) struct VibeCell {
  name : String
  effect : String
  form : String
  fields : Array[String]
  error_event : String
}

///|
pub fn vibe_cells() -> Array[VibeCell] {
  [
    { name: "shell_check_summary", effect: "ShellCheck", form: "jsonl", fields: ["exit_code", "error_count", "first_error"], error_event: "CheckFailed" },
  ]
}
