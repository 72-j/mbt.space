// ===== moonspace/gen —— R-7 依赖面界机械门（黑盒）=====
// 口径（const.md R-7）：依赖单向不回穿——space 仅 core/debug
//（A2 守卫闭合门错面 derive(Debug) 显式 extend）；runtime 向下
// space + core/debug（A3 门错面）；verify 只吃 space；gen 向下
// toml+debug+space。白名单全等断言（多即红少亦红）；test 授权面
// 同钉。业务词（宿主/数据管线/LLM 供方）随白名单结构性排除。路径双
// 上下文自适应：workspace 根（./moonspace/…）与模块根（./…）——
// moon test 两处皆可跑。

///|
async fn gate_pkg_text(rel : String) -> String {
  let primary = @fs.read_file("./moonspace/\{rel}") catch {
    _ => @fs.read_file("./\{rel}")
  }
  @utf8.decode(primary.binary())
}

///|
/// 行内引号对逐对提取（split 奇数位 = 引号内段）
fn quoted_tokens(line : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut index = 0
  for part in line.split("\"") {
    if index % 2 == 1 && part != "" {
      tokens.push(part.to_owned())
    }
    index = index + 1
  }
  tokens
}

///|
/// moon.pkg 文本 → import 词表（want_test = 取 `} for "test"` 块）
fn pkg_imports(text : String, want_test : Bool) -> Array[String] {
  let imports : Array[String] = []
  let buffer : Array[String] = []
  let mut inside = false
  let mut block_test = false
  for line in text.split("\n") {
    if !inside {
      if line.contains("import {") {
        inside = true
        block_test = false
      }
    } else {
      if line.contains("for \"test\"") {
        block_test = true
      }
      for token in quoted_tokens(line.to_owned()) {
        if token != "test" {
          buffer.push(token)
        }
      }
      if line.contains("}") {
        if block_test == want_test {
          for dep in buffer {
            imports.push(dep)
          }
        }
        buffer.clear()
        inside = false
      }
    }
  }
  imports
}

///|
/// 无序全等（长度相等 + 逐员在册）
fn same_set(actual : Array[String], expected : Array[String]) -> Bool {
  for item in expected {
    if !actual.contains(item) {
      return false
    }
  }
  actual.length() == expected.length()
}

///|
async test "dep gate：R-7 依赖面界（四包 import 白名单全等）" {
  // 主面
  assert_true(
    same_set(pkg_imports(gate_pkg_text("space/moon.pkg"), false), [
      "moonbitlang/core/debug",
    ]),
  )
  assert_true(
    same_set(pkg_imports(gate_pkg_text("verify/moon.pkg"), false), [
      "thy1016/moonspace/space",
    ]),
  )
  assert_true(
    same_set(pkg_imports(gate_pkg_text("runtime/moon.pkg"), false), [
      "moonbitlang/core/debug", "thy1016/moonspace/space",
    ]),
  )
  assert_true(
    same_set(pkg_imports(gate_pkg_text("gen/moon.pkg"), false), [
      "moonbit-community/toml", "moonbitlang/core/debug", "thy1016/moonspace/space",
    ]),
  )
  // test 授权面
  assert_true(same_set(pkg_imports(gate_pkg_text("space/moon.pkg"), true), []))
  assert_true(
    same_set(pkg_imports(gate_pkg_text("verify/moon.pkg"), true), [
      "moonbitlang/core/quickcheck", "thy1016/moonspace/space",
    ]),
  )
  assert_true(
    same_set(pkg_imports(gate_pkg_text("runtime/moon.pkg"), true), [
      "moonbitlang/async", "thy1016/moonspace/gen", "thy1016/moonspace/space", "thy1016/moonspace/verify",
    ]),
  )
  assert_true(
    same_set(pkg_imports(gate_pkg_text("gen/moon.pkg"), true), [
      "moonbitlang/async", "moonbitlang/async/fs", "moonbitlang/core/encoding/utf8",
      "thy1016/moonspace/space",
    ]),
  )
}
