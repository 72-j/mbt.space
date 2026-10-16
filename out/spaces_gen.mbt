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
