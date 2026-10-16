// ===== 探针（用后即删）：MoonBit 泛型抽象能力三问 =====
// Q1: 参数化 trait 能否声明？→ 否（[4032] 型参 trait 不支持）
// Q2: 结构体函数字段泛型形能否成立？
// Q3: 泛型 fn 对泛型结构体的调用能否解析？

///|
struct ProbeSpace {
  transition : (String, String) -> (String, Int32)?
}

///|
struct ProbeBox {
  execute : (Int32) -> String
  audit : (Int32, String) -> Unit
}

///|
fn probe_use_concrete(
  space : ProbeSpace,
  box : ProbeBox,
  state : String,
  event : String,
) -> String {
  let r = (space.transition)(state, event)
  match r {
    Some((next, n)) => {
      (box.audit)(n, next)
      (box.execute)(n)
    }
    None => state
  }
}

///|
test "probe/具体型：结构体函数字段链" {
  let space = ProbeSpace::{
    transition: fn(s : String, e : String) -> (String, Int32)? {
      Some((s + "!", e.length()))
    },
  }
  let box = ProbeBox::{
    execute: fn(f : Int32) -> String { "exec:\{f}" },
    audit: fn(_f : Int32, _r : String) -> Unit { () },
  }
  let r = probe_use_concrete(space, box, "Idle", "go")
  assert_true(r.contains("exec:"))
}
