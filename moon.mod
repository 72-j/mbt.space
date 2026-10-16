// MoonBit module manifest — moonspace
// 定位：Agent 解空间基础设施独立模块（三沙箱 + 一生成器；端口中立）
// 架构思想档案见 spec.md / const.md；发布元数据变更须经发布前评审
// （moonxr/release_review.mbtx）。

name = "thy1016/moonspace"

version = "0.1.0"

repository = "https://www.gitlink.org.cn/thy7/mbt.space"

license = "MulanPSL-2.0"

keywords = [ "agent", "sandbox", "state-machine", "effect", "fsm" ]

description = "Deterministic agent space kernel for MoonBit: TOML space contracts, gate-enforced code generation, Mealy-pure transitions, effect-interpreter runtime, and verification sandbox."

readme = "README.md"

preferred_target = "native"

import {
  "moonbitlang/async@0.22.4",
  "moonbit-community/toml@0.5.0",
}
