# CHANGELOG

## 0.1.0 (2026-10-16)

首次发布。三沙箱 + 一生成器：

- `space/` EffectSpace Sandbox——Mealy 纯转移解空间（词表/机器件/effect 封闭语义词表）
- `runtime/` Runtime Sandbox——副作用执行边界（Port 权限/超时/取消/观测流/审计）
- `verify/` Verification Sandbox——纯函数模型 + 属性 + 不变量（零真实 Port）
- `gen/` 解空间生成器——读 `domain/*.toml` 合同，产表驱动状态机 + CPS 单层 dispatch（门判强制：parse + 阳集闭合 + E 可达）
- `out/` typed 产物面（黄金门逐字节对拍 + parity 门）；`cmd/` 再生入口；`examples/` 示例 loop 全栈自证
- 组合三算子：parallel（张量积）/ series（串联）/ feedback（显式 LoopBack，守卫必填）
