// ===== moonspace/gen —— typed codegen 发射面（A2 定案产物形）=====
// 纯函数 String 出口（落盘面在 cmd——A2 分离裁定）。产物 = out 包
// typed 词表：State/Event/Effect 枚举（positional）+ Ctx struct +
// typed step（守卫 (String, Ctx) -> Bool 注入、guard 拒 = None、
// assign 结构体更新式拷贝、catch-all None）。
// 类型直通约定：TOML type 字段即 MoonBit 型字面（String / String? /
// Array[String] / Json …）。行为对拍门（typed step ≡ 解释器 step）
// = typed codegen 次格。

///|
/// 合同核对 + typed 面收紧（effect 形参数 == args 位数——生成代码
/// 可编译性前提；数据驱动面不受此限）
fn emit_check(base : SpaceBase, domain : SpaceDomain) -> Unit raise {
  check_space_base(base)
  check_space(base, domain)
  let effect_arity : Map[String, Int32] = Map([])
  for effect in base.effects {
    effect_arity.set(effect.name, effect.payload.length())
  }
  for transition in domain.transitions {
    match transition.effect {
      Some(effect_name) =>
        match effect_arity.get(effect_name) {
          Some(count) =>
            if count != transition.args.length() {
              raise ValueErr(
                "typed \{base.meta.name}: \{transition.from_state}+\{transition.on_event} effect \"\{effect_name}\" 形参 \{count} ≠ args \{transition.args.length()}",
              )
            }
          None => ()
        }
      None => ()
    }
  }
}

///|
fn initial_state_name(base : SpaceBase) -> String raise {
  for state in base.states {
    if state.is_initial {
      return state.name
    }
  }
  raise ValueErr("\{base.meta.name}: 初始态缺失（恰一门后不达）")
}

///|
/// typed 标识符门：词表名须为合法构造器（首字母大写，余字母/数字/下划线）
fn ident_guard(kind : String, name : String) -> Unit raise {
  let mut first = true
  for ch in name {
    if first {
      first = false
      if ch < 'A' || ch > 'Z' {
        raise ValueErr(
          "typed \{kind} \"\{name}\" 非合法构造器（首字母须大写）",
        )
      }
    } else if !((ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_') {
      raise ValueErr("typed \{kind} \"\{name}\" 含非法字符")
    }
  }
  if first {
    raise ValueErr("typed \{kind}: 空名")
  }
}

///|
/// typed 字段门：Ctx 槽位为小写驼峰字段（首字母小写）
fn field_guard(name : String) -> Unit raise {
  let mut first = true
  for ch in name {
    if first {
      first = false
      if ch < 'a' || ch > 'z' {
        raise ValueErr(
          "typed ctx 槽位 \"\{name}\" 非合法字段（首字母须小写）",
        )
      }
    } else if !((ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_') {
      raise ValueErr("typed ctx 槽位 \"\{name}\" 含非法字符")
    }
  }
  if first {
    raise ValueErr("typed ctx 槽位: 空名")
  }
}

///|
/// typed 产物发射：合同核对 → 标识符门 → MoonBit 源文本
pub fn emit_space_typed(base : SpaceBase, domain : SpaceDomain) -> String raise {
  emit_check(base, domain)
  let prefix = base.meta.prefix
  ident_guard("prefix", prefix)
  for state in base.states {
    ident_guard("state", state.name)
  }
  for event in base.events {
    ident_guard("event", event.name)
  }
  for effect in base.effects {
    ident_guard("effect", effect.name)
  }
  for field in base.context {
    field_guard(field.name)
  }
  let initial = initial_state_name(base)
  let b = StringBuilder()
  b.write_string("// ===== ")
  b.write_string(base.meta.name)
  b.write_string(
    " typed 产物（gen emit_space_typed 生成；禁手写）=====\n\n",
  )
  // 以下各顶级项前置 ///|（fmt 稳定形——moon fmt 块分隔不再生漂移）
  b.write_string("///|\n")
  b.write_string("pub(all) enum " + prefix + "State {\n")
  for state in base.states {
    b.write_string("  " + state.name + "\n")
  }
  b.write_string("}\n\n")
  b.write_string("///|\n")
  b.write_string(
    "pub fn " +
    prefix +
    "State::initial() -> " +
    prefix +
    "State {\n  " +
    initial +
    "\n}\n\n",
  )
  b.write_string("///|\n")
  b.write_string("pub(all) enum " + prefix + "Event {\n")
  for event in base.events {
    if event.payload.length() == 0 {
      b.write_string("  " + event.name + "\n")
    } else {
      let types = event.payload.map(fn(field) { field.type_ })
      b.write_string("  " + event.name + "(" + types.join(", ") + ")\n")
    }
  }
  b.write_string("}\n\n")
  b.write_string("///|\n")
  b.write_string("pub(all) enum " + prefix + "Effect {\n")
  for effect in base.effects {
    if effect.payload.length() == 0 {
      b.write_string("  " + effect.name + "\n")
    } else {
      let types = effect.payload.map(fn(field) { field.type_ })
      b.write_string("  " + effect.name + "(" + types.join(", ") + ")\n")
    }
  }
  b.write_string("}\n\n")
  b.write_string("///|\n")
  b.write_string("pub(all) struct " + prefix + "Ctx {\n")
  for field in base.context {
    b.write_string("  " + field.name + " : " + field.type_ + "\n")
  }
  b.write_string("}\n\n")
  b.write_string("///|\n")
  b.write_string("pub fn " + prefix + "State::step(\n")
  b.write_string("  self : " + prefix + "State,\n")
  b.write_string("  ctx : " + prefix + "Ctx,\n")
  b.write_string("  event : " + prefix + "Event,\n")
  b.write_string("  guards : (String, " + prefix + "Ctx) -> Bool,\n")
  b.write_string(
    ") -> (" + prefix + "State, " + prefix + "Ctx, " + prefix + "Effect?)? {\n",
  )
  // 无守卫行空间：参数消用（fmt 稳定：ignore 首行）
  let mut has_guard = false
  for transition in domain.transitions {
    match transition.guard_name {
      Some(_) => has_guard = true
      None => ()
    }
  }
  if has_guard == false {
    b.write_string("  ignore(guards)\n")
  }
  b.write_string("  match (self, event) {\n")
  let event_fields : Map[String, Array[String]] = Map([])
  for event in base.events {
    event_fields.set(event.name, event.payload.map(fn(field) { field.name }))
  }
  let ctx_types : Map[String, String] = Map([])
  for field in base.context {
    ctx_types.set(field.name, field.type_)
  }
  for transition in domain.transitions {
    let fields : Array[String] = match event_fields.get(transition.on_event) {
      Some(names) => names
      None => []
    }
    let used : Map[String, Bool] = Map([])
    for arg in transition.args {
      used.set(arg, true)
    }
    for mapping in resolve_assigns(transition) {
      used.set(mapping.from_field, true)
    }
    let pattern = if fields.length() == 0 {
      transition.on_event
    } else {
      // 未被臂体引用的 payload 绑定发 `_`（unused 告警零渗入产物）
      let bound = fields.map(fn(field) {
        if used.contains(field) {
          field
        } else {
          "_"
        }
      })
      transition.on_event + "(" + bound.join(", ") + ")"
    }
    let arm = "(" + transition.from_state + ", " + pattern + ")"
    let effect_expr = match transition.effect {
      Some(effect_name) =>
        // 无参 effect 发裸构造器（`E()` 常量构造器不可应用——typed
        // 编译器第三咬：agent_space 首跑实锤）
        if transition.args.length() == 0 {
          "Some(" + effect_name + ")"
        } else {
          "Some(" + effect_name + "(" + transition.args.join(", ") + "))"
        }
      None => "None"
    }
    let has_statements = transition.guard_name is Some(_) ||
      transition.assign.length() > 0
    if has_statements == false {
      // fmt 形：单表达式臂去括号；一行 ≤ 80 直排，超宽 => 换行续进
      let body = "Some((" + transition.to_state + ", ctx, " + effect_expr + "))"
      let one_line = "    " + arm + " => " + body
      if one_line.length() <= 80 {
        b.write_string(one_line + "\n")
      } else {
        b.write_string("    " + arm + " =>\n      " + body + "\n")
      }
    } else {
      b.write_string("    " + arm + " => {\n")
      match transition.guard_name {
        Some(guard_name) =>
          b.write_string(
            "      if !guards(\"" +
            guard_name +
            "\", ctx) {\n        return None\n      }\n",
          )
        None => ()
      }
      if transition.assign.length() > 0 {
        let assigns = resolve_assigns(transition)
        // fmt 形：同名简写 `slot,`；异名 Option 包 `slot: Some(v),`；
        // 异名直投 `slot: v,`；尾逗号恒在
        let updates = assigns.map(fn(a) {
          let slot_type = match ctx_types.get(a.slot) {
            Some(t) => t
            None => ""
          }
          if a.slot == a.from_field && slot_type.contains("?") == false {
            a.slot + ","
          } else if slot_type.contains("?") {
            a.slot + ": Some(" + a.from_field + "),"
          } else {
            a.slot + ": " + a.from_field + ","
          }
        })
        b.write_string(
          "      let next_ctx : " +
          prefix +
          "Ctx = { ..ctx, " +
          updates.join(" ") +
          " }\n",
        )
        b.write_string(
          "      Some((" +
          transition.to_state +
          ", next_ctx, " +
          effect_expr +
          "))\n",
        )
      } else {
        b.write_string(
          "      Some((" +
          transition.to_state +
          ", ctx, " +
          effect_expr +
          "))\n",
        )
      }
      b.write_string("    }\n")
    }
  }
  b.write_string("    (_, _) => None\n")
  b.write_string("  }\n}\n")
  // cells（USA §8 方言注册声明面——构造期合同门已核；无格 = 不产段）
  if domain.cells.length() > 0 {
    b.write_string("\n///|\n")
    b.write_string(
      "/// cells（USA §8 方言注册；构造期合同门已核 error_event/effect ∈ 阳集）\n",
    )
    b.write_string("pub(all) struct " + prefix + "Cell {\n")
    b.write_string("  name : String\n")
    b.write_string("  effect : String\n")
    b.write_string("  form : String\n")
    b.write_string("  fields : Array[String]\n")
    b.write_string("  error_event : String\n")
    b.write_string("}\n\n")
    b.write_string("///|\n")
    b.write_string(
      "pub fn " +
      prefix.to_lower() +
      "_cells() -> Array[" +
      prefix +
      "Cell] {\n",
    )
    b.write_string("  [\n")
    for cell in domain.cells {
      let fields_json : Array[String] = cell.fields.map(fn(f) { "\"\{f}\"" })
      b.write_string(
        "    { name: \"" +
        cell.name +
        "\", effect: \"" +
        cell.effect +
        "\", form: \"" +
        cell.form +
        "\", fields: [" +
        fields_json.join(", ") +
        "], error_event: \"" +
        cell.error_event +
        "\" },\n",
      )
    }
    b.write_string("  ]\n}\n")
  }
  b.to_string()
}
