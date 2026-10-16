// 合同样值：domain/*.toml 演示场景的可执行镜像（解析役对照门
// fixture——parse(*) 与 sample_*() 逐字段对照）。每个合同结构体
// 在此有真构造点。

///|
pub fn sample_retrieval_base() -> SpaceBase {
  let meta = {
    schema_version: "2.0",
    space_version: Some("1.0"),
    name: "retrieval_space",
    dialect: Some("moonspace"),
    prefix: "Retrieval",
  }
  let policy = {
    strategy: "Mealy",
    effects_trait_open: true,
    interpretation: "cps",
  }
  {
    meta,
    policy,
    context: [
      {
        name: "query_text",
        type_: "String?",
        semantics: Some("slot"),
        doc: None,
      },
      {
        name: "hits",
        type_: "Array[String]",
        semantics: Some("slot"),
        doc: Some("上一通道检索命中（跨通道传递）"),
      },
    ],
    events: [
      { name: "Query", payload: [{ name: "text", type_: "String", }], },
      {
        name: "BM25Done",
        payload: [{ name: "hits", type_: "Array[String]", }],
      },
      {
        name: "VectorDone",
        payload: [{ name: "hits", type_: "Array[String]", }],
      },
    ],
    effects: [
      {
        name: "BM25Search",
        semantics: "query",
        payload: [{ name: "query", type_: "String", }],
      },
      {
        name: "VectorSearch",
        semantics: "query",
        payload: [{ name: "query", type_: "Array[String]", }],
      },
    ],
    guards: [{ name: "has_hits", doc: Some("ctx.hits 非空"), }],
    states: [
      { name: "Idle", is_initial: true, doc: None, },
      { name: "SearchingBM25", is_initial: false, doc: None, },
      { name: "SearchingVector", is_initial: false, doc: None, },
      {
        name: "Done",
        is_initial: false,
        doc: Some("终止态（series 源头/组合面可达性终点）"),
      },
    ],
  }
}

///|
pub fn sample_retrieval_domain() -> SpaceDomain {
  {
    meta: {
      schema_version: "2.0",
      space_version: None,
      name: "retrieval_space",
      dialect: Some("moonspace"),
      prefix: "Retrieval",
    },
    transitions: [
      {
        from_state: "Idle",
        on_event: "Query",
        to_state: "SearchingBM25",
        effect: Some("BM25Search"),
        args: ["text"],
        assign: ["query_text"],
        assign_from: [{ slot: "query_text", from_field: "text", }],
        guard_name: None,
        doc: None,
      },
      {
        from_state: "SearchingBM25",
        on_event: "BM25Done",
        to_state: "SearchingVector",
        effect: Some("VectorSearch"),
        args: ["hits"],
        assign: ["hits"],
        assign_from: [],
        guard_name: None,
        doc: None,
      },
      {
        from_state: "SearchingVector",
        on_event: "VectorDone",
        to_state: "Done",
        effect: None,
        args: [],
        assign: ["hits"],
        assign_from: [],
        guard_name: Some("has_hits"),
        doc: None,
      },
    ],
    invariants: [
      {
        name: "done_absorbing",
        doc: Some("Done 是吸收态：出边必须为零"),
      },
      {
        name: "no_effect_after_done",
        doc: Some("Done 后任何事件不产生 effect"),
      },
    ],
    cells: [],
  }
}

///|
pub fn sample_reasoning_base() -> SpaceBase {
  let meta = {
    schema_version: "2.0",
    space_version: Some("1.0"),
    name: "reasoning_space",
    dialect: Some("moonspace"),
    prefix: "Reasoning",
  }
  {
    meta,
    policy: {
      strategy: "Mealy",
      effects_trait_open: true,
      interpretation: "cps",
    },
    context: [
      { name: "prompt", type_: "String?", semantics: Some("slot"), doc: None, },
      { name: "answer", type_: "String?", semantics: Some("slot"), doc: None, },
      {
        name: "context",
        type_: "String?",
        semantics: Some("slot"),
        doc: Some(
          "回灌数据源槽（ContextReady.payload.context 同名落底；ReasoningLoop LoopBack 按名取槽合成回灌事件——评审 A1 投影闭合）",
        ),
      },
    ],
    events: [
      {
        name: "ContextReady",
        payload: [{ name: "context", type_: "String", }],
      },
      { name: "ThinkDone", payload: [{ name: "text", type_: "String", }], },
    ],
    effects: [
      {
        name: "LLMCall",
        semantics: "command",
        payload: [{ name: "prompt", type_: "String", }],
      },
    ],
    guards: [],
    states: [
      { name: "Waiting", is_initial: true, doc: None, },
      { name: "Thinking", is_initial: false, doc: None, },
      {
        name: "Answered",
        is_initial: false,
        doc: Some("终止态（feedback 回送源/series 终点）"),
      },
    ],
  }
}

///|
pub fn sample_reasoning_domain() -> SpaceDomain {
  {
    meta: {
      schema_version: "2.0",
      space_version: None,
      name: "reasoning_space",
      dialect: Some("moonspace"),
      prefix: "Reasoning",
    },
    transitions: [
      {
        from_state: "Waiting",
        on_event: "ContextReady",
        to_state: "Thinking",
        effect: Some("LLMCall"),
        args: ["context"],
        assign: ["context", "prompt"],
        assign_from: [{ slot: "prompt", from_field: "context", }],
        guard_name: None,
        doc: None,
      },
      {
        from_state: "Thinking",
        on_event: "ThinkDone",
        to_state: "Answered",
        effect: None,
        args: [],
        assign: ["answer"],
        assign_from: [{ slot: "answer", from_field: "text", }],
        guard_name: None,
        doc: None,
      },
    ],
    invariants: [
      {
        name: "answered_absorbing",
        doc: Some(
          "Answered 是吸收态：出边必须为零（回送走 feedback LoopBack 事件，不占状态出边）",
        ),
      },
      {
        name: "llm_only_from_waiting",
        doc: Some(
          "LLMCall 只允许从 Waiting 发出（计费效应转移面收窄）",
        ),
      },
    ],
    cells: [],
  }
}

///|
pub fn sample_composition() -> Composition {
  {
    meta: {
      schema_version: "2.0",
      space_version: None,
      name: "demo_composition",
      dialect: Some("moonspace"),
      prefix: "Comp",
    },
    parallels: [
      {
        name: "SearchParallel",
        spaces: ["retrieval_space", "retrieval_space"],
        sync: [],
        merge_effects: "union",
      },
    ],
    series: [
      {
        name: "RetrievalToReasoning",
        source: "retrieval_space",
        target: "reasoning_space",
        adapter: [{ from_state: "Done", to_event: "ContextReady", }],
      },
    ],
    feedbacks: [
      {
        name: "ReasoningLoop",
        space: "reasoning_space",
        router: [{ from_state: "Answered", to_event: "ContextReady", }],
        loop_guard: Some({ max_rounds: 5, timeout_ms: 30000, }),
      },
    ],
  }
}
