# moonspace —— 解空间沙箱 + 运行空间沙箱

MoonBit 生态的 Agent 解空间基础设施包（端口中立；MoonRDB 是第一个
参考实现，不是绑定依赖）。架构思想档案见 `.mingspace/`（评审访谈
八篇，`gen.md` 留空待写）。

## 三沙箱边界

| 包 | 沙箱 | 约束对象 | 依赖 |
|---|---|---|---|
| `space/` | EffectSpace Sandbox | 解空间：合法状态/事件/effect（Mealy 纯转移） | 无 |
| `runtime/` | Runtime Sandbox | 副作用执行：Port 权限/资源/超时/审计 | （随实现接 space） |
| `verify/` | Verification Sandbox | 可验证性：纯函数模型 + 属性 + 不变量 | 零真实 Port |

`gen/` 是第四件：解空间生成器——读 `domain/*.toml` 产表驱动状态机
+ CPS 单层 dispatch + 属性测试骨架。

## TOML 合同（domain/，手写人维面）

- `retrieval_base.toml` / `retrieval_domain.toml` —— 演示空间一
  （骨架/行为切，对齐 ADR-1）
- `reasoning_base.toml` / `reasoning_domain.toml` —— 演示空间二
- `composition.toml` —— 组合面：parallel（张量积）/ series（串联）/
  feedback（反馈，守卫必填）

持久合同规则：新键可选（解析器缺省）；未知键忽略；删键/改义同笔
迁移。字段契约的可执行镜像 = `gen/contract.mbt`。

## 纪律红线

- 转移纯函数；effect 由 handler 解释；持久化/权限/审计留 Port 层
- CPS 单层 continuation；handler 幂等或可重试；回调带超时与取消
- feedback 回送 = 显式 LoopBack 事件，禁任意 continuation 捕获
- 生成器零业务词：semantics 封闭词表（query/command/commit/rollback/stop）
  是唯一可硬编码面
