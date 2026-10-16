# moonspace —— 解空间沙箱 + 运行空间沙箱

MoonBit 生态的 Agent 解空间基础设施独立模块（`thy1016/moonspace`，
端口中立）。**合同先行，门判强制**——空间合同（TOML）可以由人写，
也可以由 LLM 出稿；无论谁出，过门才执行。架构思想档案见
`spec.md` / `const.md`；茗空间工作卷（`.mingspace/`）与工作账
（`ctx.md` / `todo.md`）本地不入仓。

## 三沙箱边界

| 包 | 沙箱 | 约束对象 | 依赖 |
|---|---|---|---|
| `space/` | EffectSpace Sandbox | 解空间：合法状态/事件/effect（Mealy 纯转移） | 无 |
| `runtime/` | Runtime Sandbox | 副作用执行：Port 权限/资源/超时/审计 | （随实现接 space） |
| `verify/` | Verification Sandbox | 可验证性：纯函数模型 + 属性 + 不变量 | 零真实 Port |

`gen/` 是第四件：解空间生成器——读 `domain/*.toml` 产合同门
（parse + 阳集闭合 + E 可达）+ §15 意图装填（`assign_from` 糖收归
系统）→ `space_from_contract` 构造态。

外圈三件：`out/` typed 产物面（黄金门逐字节对拍 + parity 门）；
`cmd/` 再生入口（`moon run cmd --target native`）；`examples/`
示例 loop 全栈自证一跑（`moon run examples --target native`）。

## TOML 合同（domain/，手写人维面）

- `retrieval_base.toml` / `retrieval_domain.toml` —— 演示空间一
  （骨架/行为切，对齐 ADR-1）
- `reasoning_base.toml` / `reasoning_domain.toml` —— 演示空间二
- `composition.toml` —— 组合面：parallel（张量积）/ series（串联）/
  feedback（反馈，守卫必填）

宿主装配词表（agent_space / vibe_space 等）住宿主自己的仓库
`domain/`，不入本仓产物面——本仓只携带演示合同对与组合面；新
消费者 = 自带 TOML 对 + stub 填空。

阳面 = base 词表（态/事件/效应/槽位，只选不发明）；阴面 = 转移表
（`from/on/to/effect/args` + `assign_from` 糖——效应回执字段落
ctx 槽位）。

## 30 秒上手

```sh
cd moonspace
moon run examples --target native   # 示例 loop（合同 → 门 → 大 loop，零 LLM）
moon test gen runtime space out verify --target native   # 本模块门（按包过滤+显式 native——缺省 wasm 计划会静默跳过 native 门件）
moon run cmd --target native        # 合同再生（改 domain/*.toml 后）
```

示例 loop 输出：

```
合同 hello_loop_space 过门：态 3 / 事件 3 / 效应 1 / 转移 3
终局: Done / Completed / rounds=2
  r1: DoIt → WorkDone (completed)
槽位 result_summary = did it
```

## 持久合同规则

- 新键可选（解析器缺省，不因缺席报错）；未知键忽略（旧文件保持
  可读）；删键/改义同笔迁移手写文件。
- 字段契约的可执行镜像 = `gen/contract.mbt`；typed 产物与手写合同
  的漂移 = 红测试（对照门）。

## 纪律红线

- 转移纯函数；effect 由 handler 解释；持久化/权限/审计留 Port 层
- CPS 单层 continuation；handler 幂等或可重试；回调带超时与取消
- feedback 回送 = 显式 LoopBack 事件，禁任意 continuation 捕获
- 生成器零业务词：semantics 封闭词表（query/command/commit/rollback/stop）
  是唯一可硬编码面

## 跑法备注

- `moon run` / `moon test` 缺省 **wasm** 计划——native 门件会**静默
  跳过**（非 verbose 不提示），native 跑法必带 `--target native`。
- **wasm 面（2026-10-16 勘定）**：库面 `space/` `gen/` 主面、
  `runtime/` `verify/` `out/` 主面后端中立，wasm-gc check 全绿——
  浏览器嵌入形 = 库面编 wasm 产物 + 宿主 JS 实现 EffectHandler
  （真效应在宿主，正是三沙箱边界的用武之地）。fs 吃用面（gen/out
  对照门测试件、cmd 再生入口）按文件/包钉 native（分件先例）；`examples/` 可执行面暂 native——async main 依赖
  async 库 wasm 入口 `run_async_main`，现版（0.22.4）wasm-gc 面缺，
  入口齐后撤钉。
- 本模块在宿主仓 bitbang 的 `moon.work` 中为 workspace member：
  成员目录内裸跑 `moon test` 会跑全 workspace，按包过滤才是本模块
  自己的门。

## 宿主集合（引擎论）

moonspace 是被嵌的确定性内核，宿主集合开放——不是宿主跑在
moonspace 里，而是 moonspace 作为引擎库跑在宿主里（同一二进制静
态链接，loop 骨架在 moonspace、效应回调宿主 handler）：

- **agent 宿主**（在役）：LLM 出机 → 五门 → 大 loop 真网；装配
  词表（agent_space / vibe_space）住宿主仓；
- **数据管线宿主**（合同已备未接）：domain 的 retrieval/reasoning
  合同对（`BM25Search`/`VectorSearch`/`LLMCall` 词表）即检索管线
  速写，缺 handler 真身与预算面；
- **浏览器**（人闸 UI 宿主，挂账）：见下方 wasm 面条目。

嵌入身份 = **编排面非存储面**——数据访问仍走宿主自己的 port，
moonspace 不当 DAO。

## 相关

- 本仓：<https://gitlink.org.cn/thy7/mbt.space>
