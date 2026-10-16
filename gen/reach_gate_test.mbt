// ===== E 门（可达性）钉：初态断 / 死角态 / 良机通过（格3a）=====
// 内联合同走 parse_space_base/parse_space_domain + check_space 全链
// （构造期正门——E 门随 cells 门同位在册）。

///|
fn reach_base() -> String {
  (
    #|[meta]
    #|schema_version = "2.0"
    #|name = "reach_space"
    #|dialect = "moonspace"
    #|prefix = "Reach"
    #|
    #|[space]
    #|strategy = "Mealy"
    #|interpretation = "cps"
    #|
    #|[[space.context]]
    #|name = "task"
    #|type = "String?"
    #|semantics = "slot"
    #|doc = "任务槽"
    #|
    #|[[space.events]]
    #|name = "Kick"
    #|payload = [{ name = "text", type = "String" }]
    #|
    #|[[space.events]]
    #|name = "WorkDone"
    #|payload = [{ name = "note", type = "String" }]
    #|
    #|[[space.events]]
    #|name = "Fail"
    #|payload = [{ name = "reason", type = "String" }]
    #|
    #|[[space.effects]]
    #|name = "DoIt"
    #|semantics = "command"
    #|payload = [{ name = "text", type = "String" }]
    #|
    #|[[space.states]]
    #|name = "Idle"
    #|is_initial = true
    #|
    #|[[space.states]]
    #|name = "Working"
    #|
    #|[[space.states]]
    #|name = "Done"
    #|
    #|[[space.states]]
    #|name = "Dead"
  )
}

///|
test "E 门：良机通过（初态可达吸收终局，无死角）" {
  let base = @gen.parse_space_base(reach_base())
  let domain = @gen.parse_space_domain(
    (
      #|[meta]
      #|schema_version = "2.0"
      #|name = "reach_space"
      #|dialect = "moonspace"
      #|prefix = "Reach"
      #|
      #|[[space.transitions]]
      #|from = "Idle"
      #|on = "Kick"
      #|to = "Working"
      #|effect = "DoIt"
      #|args = ["text"]
      #|
      #|[[space.transitions]]
      #|from = "Working"
      #|on = "WorkDone"
      #|to = "Done"
      #|
      #|[[space.transitions]]
      #|from = "Working"
      #|on = "Fail"
      #|to = "Idle"
    ),
  )
  let mut raised = ""
  @gen.check_space(base, domain) catch {
    @gen.ContractError::ValueErr(msg) => raised = msg
    _ => raised = "other"
  }
  assert_eq(raised, "")
}

///|
test "E 门：初态无路径到吸收终局 → ValueErr" {
  let base = @gen.parse_space_base(reach_base())
  let domain = @gen.parse_space_domain(
    (
      #|[meta]
      #|schema_version = "2.0"
      #|name = "reach_space"
      #|dialect = "moonspace"
      #|prefix = "Reach"
      #|
      #|[[space.transitions]]
      #|from = "Idle"
      #|on = "Kick"
      #|to = "Working"
      #|effect = "DoIt"
      #|args = ["text"]
      #|
      #|[[space.transitions]]
      #|from = "Working"
      #|on = "Fail"
      #|to = "Idle"
    ),
  )
  let mut raised = ""
  @gen.check_space(base, domain) catch {
    @gen.ContractError::ValueErr(msg) => raised = msg
    _ => raised = "other"
  }
  // Done 声明在册但无入边不可达 → 判一（初态无结构可达路径）
  assert_true(raised.contains("E 门"))
}

///|
test "E 门：可达非吸收死角态 → ValueErr" {
  let base = @gen.parse_space_base(reach_base())
  let domain = @gen.parse_space_domain(
    (
      #|[meta]
      #|schema_version = "2.0"
      #|name = "reach_space"
      #|dialect = "moonspace"
      #|prefix = "Reach"
      #|
      #|[[space.transitions]]
      #|from = "Idle"
      #|on = "Kick"
      #|to = "Working"
      #|effect = "DoIt"
      #|args = ["text"]
      #|
      #|[[space.transitions]]
      #|from = "Working"
      #|on = "WorkDone"
      #|to = "Done"
      #|
      #|[[space.transitions]]
      #|from = "Working"
      #|on = "Fail"
      #|to = "Dead"
      #|
      #|[[space.transitions]]
      #|from = "Dead"
      #|on = "Fail"
      #|to = "Dead"
    ),
  )
  let mut raised = ""
  @gen.check_space(base, domain) catch {
    @gen.ContractError::ValueErr(msg) => raised = msg
    _ => raised = "other"
  }
  // Dead = 可达非吸收态（有出边）且只自环 → 判二（死角态）
  assert_true(raised.contains("死角态"))
}
