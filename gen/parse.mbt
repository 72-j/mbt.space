// ===== moonspace/gen —— 域合同解析器（@toml 0.5 → contract 结构体）=====
// 持久合同规则（宪法）：必填键缺失即红（ContractError 路径跟随）；
// 可选键缺省（is_initial=false / semantics="command" / merge_effects=
// "union" / guard 两值 0 / payload·args·assign·sync·adapter·router 空）；
// 未知键忽略（只按名取已知键，Map 直查不过根）。
// 保留字避让：TOML 键名 "type"/"guard" 原样取用，落 type_/guard_name。

///|
/// 骨架文件（*_base.toml）：[meta] + [space] 策略 + 词表声明
pub fn parse_space_base(text : String) -> SpaceBase raise {
  let root = root_table(@toml.parse(text))
  let meta = parse_meta(sub_table(root, "meta", "root"), "meta")
  let space = sub_table(root, "space", "root")
  let policy = {
    strategy: req_str(space, "strategy", "space"),
    effects_trait_open: opt_bool_or(space, "effects_trait_open", "space", false),
    interpretation: req_str(space, "interpretation", "space"),
  }
  let context : Array[CtxField] = []
  for index, row in table_array_or_empty(space, "context", "space") {
    let here = "space.context[\{index}]"
    context.push({
      name: req_str(row, "name", here),
      type_: req_str(row, "type", here),
      semantics: opt_str(row, "semantics", here),
      doc: opt_str(row, "doc", here),
    })
  }
  let events : Array[EventDecl] = []
  for index, row in table_array_or_empty(space, "events", "space") {
    let here = "space.events[\{index}]"
    events.push({
      name: req_str(row, "name", here),
      payload: parse_payload(row, here),
    })
  }
  let effects : Array[EffectDecl] = []
  for index, row in table_array_or_empty(space, "effects", "space") {
    let here = "space.effects[\{index}]"
    effects.push({
      name: req_str(row, "name", here),
      semantics: opt_str_or(row, "semantics", here, "command"),
      payload: parse_payload(row, here),
    })
  }
  let guards : Array[GuardDecl] = []
  for index, row in table_array_or_empty(space, "guards", "space") {
    let here = "space.guards[\{index}]"
    guards.push({
      name: req_str(row, "name", here),
      doc: opt_str(row, "doc", here),
    })
  }
  let states : Array[StateDecl] = []
  for index, row in table_array_or_empty(space, "states", "space") {
    let here = "space.states[\{index}]"
    states.push({
      name: req_str(row, "name", here),
      is_initial: opt_bool_or(row, "is_initial", here, false),
      doc: opt_str(row, "doc", here),
    })
  }
  { meta, policy, context, events, effects, guards, states, }
}

///|
/// 行为文件（*_domain.toml）：[meta] + [[space.transitions]] +
/// [[space.invariants]]（[space] 表由 [[space.*]] 行隐式创建）
pub fn parse_space_domain(text : String) -> SpaceDomain raise {
  let root = root_table(@toml.parse(text))
  let meta = parse_meta(sub_table(root, "meta", "root"), "meta")
  let space = sub_table(root, "space", "root")
  let transitions : Array[TransitionDecl] = []
  for index, row in table_array_or_empty(space, "transitions", "space") {
    let here = "space.transitions[\{index}]"
    transitions.push({
      from_state: req_str(row, "from", here),
      on_event: req_str(row, "on", here),
      to_state: req_str(row, "to", here),
      effect: opt_str(row, "effect", here),
      args: str_array_or_empty(row, "args", here),
      assign: str_array_or_empty(row, "assign", here),
      assign_from: parse_assign_from(row, here),
      guard_name: opt_str(row, "guard", here),
      doc: opt_str(row, "doc", here),
    })
  }
  let invariants : Array[InvariantDecl] = []
  for index, row in table_array_or_empty(space, "invariants", "space") {
    let here = "space.invariants[\{index}]"
    invariants.push({
      name: req_str(row, "name", here),
      doc: opt_str(row, "doc", here),
    })
  }
  // [[space.cell]]：USA 方言注册（格1；USA §8）——缺席 = 空数组
  // （持久合同：未知键容忍的反面，本键自 v2.x 起在册）
  let cells : Array[CellDecl] = []
  for index, row in table_array_or_empty(space, "cell", "space") {
    let here = "space.cell[\{index}]"
    cells.push({
      name: req_str(row, "name", here),
      effect: req_str(row, "effect", here),
      form: req_str(row, "form", here),
      fields: str_array_or_empty(row, "fields", here),
      error_event: req_str(row, "error_event", here),
      doc: opt_str(row, "doc", here),
    })
  }
  { meta, transitions, invariants, cells, }
}

///|
/// 组合文件（composition.toml）：[[parallel]] / [[series]]（含
/// [[series.adapter]]）/ [[feedback]]（含 [feedback.guard]）
pub fn parse_composition(text : String) -> Composition raise {
  let root = root_table(@toml.parse(text))
  let meta = parse_meta(sub_table(root, "meta", "root"), "meta")
  let parallels : Array[ParallelDecl] = []
  for index, row in table_array_or_empty(root, "parallel", "root") {
    let here = "parallel[\{index}]"
    parallels.push({
      name: req_str(row, "name", here),
      spaces: str_array_or_empty(row, "spaces", here),
      sync: str_array_or_empty(row, "sync", here),
      merge_effects: opt_str_or(row, "merge_effects", here, "union"),
    })
  }
  let series_rows : Array[SeriesDecl] = []
  for index, row in table_array_or_empty(root, "series", "root") {
    let here = "series[\{index}]"
    series_rows.push({
      name: req_str(row, "name", here),
      source: req_str(row, "source", here),
      target: req_str(row, "target", here),
      adapter: parse_bridge_rows(
        table_array_or_empty(row, "adapter", here),
        "\{here}.adapter",
      ),
    })
  }
  let feedbacks : Array[FeedbackDecl] = []
  for index, row in table_array_or_empty(root, "feedback", "root") {
    let here = "feedback[\{index}]"
    let loop_guard : FeedbackGuard? = match opt_sub_table(row, "guard", here) {
      Some(guard_table) =>
        Some({
          max_rounds: opt_int_or(guard_table, "max_rounds", "\{here}.guard", 0),
          timeout_ms: opt_int_or(guard_table, "timeout_ms", "\{here}.guard", 0),
        })
      None => None
    }
    feedbacks.push({
      name: req_str(row, "name", here),
      space: req_str(row, "space", here),
      router: parse_bridge_rows(
        table_array_or_empty(row, "router", here),
        "\{here}.router",
      ),
      loop_guard,
    })
  }
  { meta, parallels, series: series_rows, feedbacks, }
}

///|
/// [meta] 面提取（五文件共有）
fn parse_meta(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ContractMeta raise {
  {
    schema_version: req_str(table, "schema_version", path),
    space_version: opt_str(table, "space_version", path),
    name: req_str(table, "name", path),
    dialect: opt_str(table, "dialect", path),
    prefix: req_str(table, "prefix", path),
  }
}

///|
/// payload 字段行提取（事件/效应共用）
fn parse_payload(
  row : Map[String, @toml.TomlValue],
  path : String,
) -> Array[PayloadField] raise {
  let payload : Array[PayloadField] = []
  for index, field_row in table_array_or_empty(row, "payload", path) {
    let here = "\{path}.payload[\{index}]"
    payload.push({
      name: req_str(field_row, "name", here),
      type_: req_str(field_row, "type", here),
    })
  }
  payload
}

///|
/// assign 异名显式映射行提取（同名省略，异名显式）
fn parse_assign_from(
  row : Map[String, @toml.TomlValue],
  path : String,
) -> Array[AssignFrom] raise {
  let mappings : Array[AssignFrom] = []
  for index, mapping_row in table_array_or_empty(row, "assign_from", path) {
    let here = "\{path}.assign_from[\{index}]"
    mappings.push({
      slot: req_str(mapping_row, "slot", here),
      from_field: req_str(mapping_row, "from_field", here),
    })
  }
  mappings
}

///|
/// 桥行提取（series.adapter / feedback.router 共用形）
fn parse_bridge_rows(
  rows : Array[Map[String, @toml.TomlValue]],
  path : String,
) -> Array[StateEventBridge] raise {
  let bridges : Array[StateEventBridge] = []
  for index, row in rows {
    let here = "\{path}[\{index}]"
    bridges.push({
      from_state: req_str(row, "from_state", here),
      to_event: req_str(row, "to_event", here),
    })
  }
  bridges
}

///|
fn root_table(value : @toml.TomlValue) -> Map[String, @toml.TomlValue] raise {
  match value {
    TomlTable(table) => table
    other => raise TypeErr("root: expected table, got \{other.type_name()}")
  }
}

///|
fn sub_table(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
) -> Map[String, @toml.TomlValue] raise {
  match opt_sub_table(table, key, path) {
    Some(inner) => inner
    None => raise MissingKeyErr("\{path}.\{key}")
  }
}

///|
fn opt_sub_table(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
) -> Map[String, @toml.TomlValue]? raise {
  match table.get(key) {
    Some(TomlTable(inner)) => Some(inner)
    Some(other) =>
      raise TypeErr("\{path}.\{key}: expected table, got \{other.type_name()}")
    None => None
  }
}

///|
fn req_str(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
) -> String raise {
  match opt_str(table, key, path) {
    Some(value) => value
    None => raise MissingKeyErr("\{path}.\{key}")
  }
}

///|
fn opt_str(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
) -> String? raise {
  match table.get(key) {
    Some(TomlString(value)) => Some(value)
    Some(other) =>
      raise TypeErr("\{path}.\{key}: expected string, got \{other.type_name()}")
    None => None
  }
}

///|
fn opt_str_or(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
  default : String,
) -> String raise {
  match opt_str(table, key, path) {
    Some(value) => value
    None => default
  }
}

///|
fn opt_bool_or(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
  default : Bool,
) -> Bool raise {
  match table.get(key) {
    Some(TomlBoolean(value)) => value
    Some(other) =>
      raise TypeErr(
        "\{path}.\{key}: expected boolean, got \{other.type_name()}",
      )
    None => default
  }
}

///|
fn opt_int_or(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
  default : Int32,
) -> Int32 raise {
  match table.get(key) {
    Some(TomlInteger(value)) => value.to_int()
    Some(other) =>
      raise TypeErr(
        "\{path}.\{key}: expected integer, got \{other.type_name()}",
      )
    None => default
  }
}

///|
fn str_array_or_empty(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
) -> Array[String] raise {
  let values : Array[String] = []
  match table.get(key) {
    Some(TomlArray(items)) =>
      for index, item in items {
        match item {
          TomlString(value) => values.push(value)
          other =>
            raise TypeErr(
              "\{path}.\{key}[\{index}]: expected string, got \{other.type_name()}",
            )
        }
      }
    Some(other) =>
      raise TypeErr("\{path}.\{key}: expected array, got \{other.type_name()}")
    None => ()
  }
  values
}

///|
fn table_array_or_empty(
  table : Map[String, @toml.TomlValue],
  key : String,
  path : String,
) -> Array[Map[String, @toml.TomlValue]] raise {
  let rows : Array[Map[String, @toml.TomlValue]] = []
  match table.get(key) {
    Some(TomlArray(items)) =>
      for index, item in items {
        match item {
          TomlTable(row) => rows.push(row)
          other =>
            raise TypeErr(
              "\{path}.\{key}[\{index}]: expected table, got \{other.type_name()}",
            )
        }
      }
    Some(other) =>
      raise TypeErr(
        "\{path}.\{key}: expected array of tables, got \{other.type_name()}",
      )
    None => ()
  }
  rows
}
