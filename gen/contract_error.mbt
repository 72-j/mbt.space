// ===== moonspace/gen —— 域合同解析/核对错误 =====
// 路径跟随报错（meta.name / space.transitions[2].guard …）；解析期
// 结构错（MissingKeyErr/TypeErr）与核对期语义错（ValueErr）共用面。

///|
pub(all) suberror ContractError {
  MissingKeyErr(String) // 必填键缺失
  TypeErr(String) // 键在而型不符（期望表/串/布尔/整数/数组）
  ValueErr(String) // 语义约束违背（闭合失败/词表越界/恰一失败）
} derive(Debug)
