# moonspace 规格基本形态（project spec）

版本：v0.1.0（2026-10-11 解析役后立档）

> **定位**：本卷是 moonspace 的**项目级决策锚点**——访谈面 `.mingspace/`
> （评审访谈八篇 + 涌现材料，**git 忽略**，本地查阅用）里的关键裁决，
> 落回本卷作仓内唯一持久记录。访谈面只管涌现，不进库；本卷只管定案。
> 状态标记：`[定案]` = 已定形（出处可查）；`[待裁]` = 需裁定后才可落
> （编号见 §6，编号唯一源）。

---

## 1 定位与缘起

| # | 决策 | 出处 |
|---|---|---|
| M1 | **定位**：MoonBit 生态的 Agent 解空间基础设施包——端口中立；MoonRDB 是第一个参考实现，不是绑定依赖 | `README.mbt.md` + `.mingspace/sandbox.md` `[定案]` |
| M2 | **缘起**：为 moonxllm 的 agent 写沙箱 loop（2026-10-11 用户令）——agent loop 代数化：LLM 是纯函数，工具是效应，handler 是解释器，守卫是不变量，观测流是轨迹 | `.mingspace/agent.md` `[定案]` |
| M3 | **内核形态**：Mealy 纯转移 `State × Event → (State × Effect)`；effect 由 handler 解释；CPS **单层** continuation；禁任意 continuation 捕获；持久化/权限/审计留 Port 层 | `.mingspace/effect.md` `[定案]` |

## 2 三沙箱 + 一生成器

| 包 | 沙箱 | 职责 | 依赖 |
|---|---|---|---|
| `space/` | EffectSpace Sandbox（解空间） | 合法状态/事件/effect 词表与机器件；`effect_semantics` 封闭词表住此 | 无 |
| `runtime/` | Runtime Sandbox（运行空间） | 副作用执行边界：Port 权限/资源/超时/重试/审计，防 effect 逃逸 | （随实现役接 space） |
| `verify/` | Verification Sandbox（验证环境） | 纯函数模型+属性+不变量；隔离**验证环境**与**生产执行环境**，零真实 Port | 零 Port |
| `gen/` | 解空间生成器（第四件） | 读 `domain/*.toml` 产表驱动状态机 + CPS 单层 dispatch + 属性测试骨架 | 合同解析（役3 已落） |

三沙箱划界出处：`.mingspace/sandbox.md`（EffectSpace 命名定案 + Runtime 划界）、
`.mingspace/verify.md`（验证沙箱独立：不混进 EffectSpace/Runtime）。

## 3 合同与生成器纪律（宪法面）

| # | 决策 | 出处 |
|---|---|---|
| M4 | **semantics 封闭词表**（query/command/commit/rollback/stop）= 生成器唯一可硬编码业务无关面；缺省 = command（保守面） | `domain/retrieval_base.toml` §effects `[定案]` |
| M5 | **TOML 持久合同规则**：新键可选（解析器缺省，缺键不报错）；未知键忽略；删键/改义同笔迁移手写 TOML | 仓规宪法 `[定案]` |
| M6 | **骨架/行为切**（对齐 ADR-1）：`*_base.toml` = 词表骨架（[meta]+[space]+五声明节）；`*_domain.toml` = 转移行为（[meta]+transitions+invariants）；文件对按 `meta.name` 配对 | `domain/*.toml` 头注 `[定案]` |
| M7 | **组合三算子**：parallel = 张量积（笛卡尔积 + interleaving，gen 必做可达性剪枝）；series = 串联（adapter 桥接行）；feedback = 反馈（**显式 LoopBack 事件**回送，守卫必填——两值至少启用其一） | `.mingspace/tensor.md` + `composition.toml` `[定案]` |
| M8 | **真源跟随范式**：手写 `domain/*.toml` 是人维维护面 = 真源；`gen/sample.mbt` 是可执行镜像（样值 fixture），**sample 跟随 TOML 迁移，不反向**；对照门读真实文件钉漂移（漂移即红） | 役3 `[定案]` |
| M9 | **合同优先**：合同（`contract.mbt` + sample）与手写 TOML 冲突时，先判**落后方向**——TOML 落后于合同则补 TOML（役3 `[meta]` 配对面同笔迁移先例），非改义 | 役3 `[定案]` |

## 4 解析役定案（2026-10-11，役3，提交 53c2e11）

- **三入口**（分文件三形）：`parse_space_base`（骨架文件）/
  `parse_space_domain`（行为文件）/ `parse_composition`（组合文件）；
  `@toml 0.5` 直解析，错误面 `ContractError{MissingKeyErr/TypeErr/ValueErr}`
  路径跟随。
- **验收口径三门**（`gen/check.mbt` 头注为执行细节真源）：
  ① **骨架恰一门** `check_space_base`——is_initial 全表恰一；semantics
  落封闭词表。
  ② **行为闭合门** `check_space`——meta.name 配对一致；from+on 组合
  唯一；to/effect/guard 引用闭合；args ⊆ on_event payload；
  assign 三查（槽位∈ctx 词表、同名缺省、异名必经 assign_from）。
  ③ **组合闭合门** `check_composition`——spaces ≥2 且闭合到已声明
  文件对；sync 事件在每个参与空间声明；merge_effects 现役仅 union；
  adapter/router 桥行闭合；feedback 守卫必填。
- **assign 投影口径 `[定案]`（2026-10-11 拍②）**：槽位默认同名投影
  （**同名省略**）；异名经 `assign_from = [{ slot, from_field }]`
  **显式映射**。同名强制检查当场逮住 `answer ← ThinkDone.payload.text`
  漏网（口径有牙的实证）。
- **可选键缺省表**：`is_initial=false`；`semantics="command"`；
  `merge_effects="union"`；guard 两值 `0`（= 不启用）；payload/args/
  assign/assign_from/sync/adapter/router 缺省空。

## 4.5 役4 定案（2026-10-11，沙箱大 loop；勘 moonxllm 消费面后拍）

**缘起勘验**（T-5/R-6 收账）：moonxllm `agent/` ToolLoop = "裸 loop"
现实版——policy 门/哨兵回执/EpisodeLog 散装自命，**无解空间**（无合法
状态/事件/effect 词表约束）；尾递归 turn ↔ CPS 单层形一致。四拍：

| # | 拍板 | 落点 |
|---|---|---|
| ① | **async 化**：`EffectHandler` 直返形（async 对位 CPS 单层——每效应恰一次解释、结果立返喂回；禁嵌套/捕获语义不变），runner = `async fn run[T : EffectHandler]` | `runtime/runtime_sandbox.mbt` |
| ② | **CtxValue 加 `JsonVal(Json)` 臂**（工具参数 Json 载荷对位；`Json` 为内建型，space 仍零引包） | `space/loop_types.mbt` |
| ③ | **执行错哨兵回执**（moonxllm `dispatch_one` 先例）：handler 域内错自转哨兵事件回灌；逃逸错 ⇒ runner `Termination::HandlerError` 拦停（audit outcome="failed"），与合同面 `DeadEnd` 分列（R-8） | `runtime/` |
| ④ | **端口中立**：moonspace 不进 moonxllm agent 包白名单，适配（SpaceHandler/PolicyEngine→guards 翻译）落对方 cmd/X3 装配位 | 边界裁定 |

**运行语义 v1 `[定案]`**：
- **LoopBack 落点** = to_event 的**首个规则源态**（回灌落回受理该事件
  的态，tensor.md 回送口径；无规则兜底初始态）。实证：落点若喂回送源
  态（Answered 无出边）即 DeadEnd（集成门逮住）。
- **轮径口径**：`rounds` = 步进次数（效应步+纯装填步同径）；max_rounds=5
  ⇒ 3 效应 + 2 纯步（集成门实测）。预算先于步进（entry 检查）。
- **LoopBack payload** = to_event payload 字段按名取 ctx，缺键缺省空文本。
- **构造器** `gen::space_from_contract(base, domain, feedbacks)`：构造前
  重跑三门；feedback 按 space 名挂载、守卫必填就地核对；assign 投影
  归一（from_field 单形化，step 面零分支）。
- **门**：`gen/space_gate_test.mbt`（构造结构面 3 test）+
  `runtime/loop_integration_test.mbt`（四环集成：线性闭环/守卫判否/
  feedback 有界/超时/逃逸拦停）；`moon check` 零告警 + 10/10 绿。

## 4.6 装配役钉（2026-10-11 三钉三补，用户拍）

**三钉**：
1. **SpaceHandler 适配**：落 moonxllm cmd 装配位；`LLMCall` →
   `LLMProvider.chat(LlmContext)`、`ToolExec` → `ToolRegistry.call`（炸转
   哨兵回执，`dispatch_one` 先例）。
   **词表拆臂 `[定案]`（钉①补）**：供方翻译位把世界翻成**已判定事件**——
   LLM 供方一次响应（LLMResponse）按 stop 值拆臂：`stop=EndTurn →
   LLMFinal{answer}`、`stop=ToolUse → LLMToolCalls{calls}`——Mealy 静态表
   不做值分支，分支判定收进 SpaceHandler，from+on 唯一门不破
   （`agent_space_base.toml` 头注即口径原文）。
2. **PolicyEngine→翻译三路分判**：`ResourceGate.max_steps` →
   `ResourceLimit.max_rounds`（轮径换算，A4 在册）；`allow_tool` 不进
   guards（**R-9 入册**：guards 只判解空间数据条件，带外部语义的门留
   handler 域内哨兵面）；guards 面留给词表数据条件谓词。
3. **与 X3 同窗口**：并的实体 = `moonxllm/cmd/main.mbt` + `cmd/moon.pkg`
   装配面；顺序 = X3 先立 cmd 骨架、装配役随后插。
   **不互碰判据 `[定案]`（钉③补）= 符号级，非行区间**：X3 拥有
   provider/registry/experience 装配符号 + ExperienceStore 实现；装配役
   拥有 SpaceHandler 类型 + 词表加载 + `run` 接线符号 + agent 词表
   TOML；共享文件（cmd/main.mbt、cmd/moon.pkg）只**追加各自符号**，
   禁改写对方符号；moon.pkg import 面各自追加——冲突即后插方对齐
   先插方骨架。

**开工序**：词表合同对先行（✅ 本节同笔：`domain/agent_space_*.toml`，
拆臂/自环回灌/异名映射实装；构造门扩展 11/11 绿——同名强制检查第三咬
`last_answer ← answer` 漏网即逮）→ X3 cmd 骨架 → SpaceHandler 插装
（✅ 2026-10-11：workspace 立 + `cmd/space_assembly.mbt`）→ 真网贯通
（✅ 2026-10-11：`Answered rounds=2 audit=1 term=Completed` + GLM 原话
入经验回灌——缘起闭环，moonxllm agent 沙箱 loop 真跑）。

**真网贯通实证（装配役收口）**：`AGENT_GOAL="…" moon run moonxllm/cmd`
→ GLM 真网 → 沙箱大 loop → Answered 吸收。三修链（诊断靠 term= 渲染
逐层剥）：① 供方对钉正（`glm-coding` + `glm-5.3-flash`，X2 实证链；
`glm` 供方模型表无 flash → 开仓第三门 EndpointError 如实拦）；
② **HttpTransport url 空投实锤**（用户钉）：transport POST 自己构造时
的 url 字段，`RegistryProvider::open` 内部解析端点不回填 transport——
必须先 `@wire.endpoint_for` 拆包再构造 transport；③ 逃逸面 Failure 载
文案（Error Show variant-only 限制，见 §7 坑账）。secrets 目录面同笔
迁移：key 行 providers 漏记 glm-coding（X1 入表漂移），再生链重跑
黄金门 ✓。

## 4.7 大gen思想落实盘点（2026-10-11 回灌，用户令）

**总判**：大gen思想落实形态 = **解释器派先落**（役4 拍①裁定：词表/
转移表是运行时数据非生成代码）——gen 的**读面/核面/构造面完整**
（解析器三门 + 对照门 + 运行形构造器 + dep gate，1615 行 70 导出），
**发射面（typed codegen）零行**（T-2/A2 在册）。"gen 骨架是否完整"的
答：**按役4 裁定形态完整，按 2026-10-09 大gen原文（effect.md 六件）
欠四件**——欠的都是生成物形态，被数据驱动形替代或未开。

**effect.md 大gen六件对照**：

| # | 大gen 应生成 | 状态 | 落地形态 |
|---|---|---|---|
| 1 | 枚举（State/Event/Effect） | ◐ 替代形 | 词表进 EffectSpace 运行形（`space_from_contract` 构造）；typed 枚举未生成（T-2/A2） |
| 2 | state_table 转移函数 | ◐ 替代形 | TransitionRule 表 + 通用 `step` 解释器（space 一件全空间共用，R-1 纯函数）；typed 每空间转移函数未生成 |
| 3 | CPS dispatch 模板 | ◐ 替代形 | `runtime.run` 通用单层环（async 直返形，拍①）；typed per-space dispatch 未生成 |
| 4 | 状态可达性图 | ✗ 未落 | T-4（含 parallel 笛卡尔积剪枝——组合运行形未落） |
| 5 | 属性测试用例骨架 | ✗ 未落 | R-3 verify 役联动未开 |
| 6 | Port stub / mock | ✗ 未落 | 装配役手写 SpaceHandler 先例（92 行）——stub 生成战训新格 |

**tensor.md 组合产物八件**：feedback 三件 ✓（router/桥行/守卫必填，
役4 运行形）；series/parallel 五件 ✗（桥接状态/并集枚举/适配器/剪枝/
组合属性——T-4）。

**不生成负清单核对**（effect.md 纪律红线）：Port 实现 / DB 写入 /
LLM 细节 / 错误恢复 / 审计权限——✓ 零渗入（dep gate 白名单机械钉，
R-4）。

**超出原文的既有件**（读面，原文只有"读 domain/*.toml"一句）：契约
镜像 17 struct + 解析器三入口 + 验收三门 + 对照门 + 构造器 + 构造门
+ dep gate——役3/役4 落成，**新消费者经济学已实证**：agent_space 入
场 = 两份 TOML + 装配位手写 handler，零 gen 代码改动（R-4 宪法全过）。

**战训新格（装配役长出的 gen 候选，原文未列）**：
1. **handler stub 生成**——per-space `match effect.name` 翻译门骨架
   （SpaceHandler 手写形可产：拆臂/哨兵回执/fail 逃逸三段式）
   **[落形 2026-10-12，§4.9]**
2. **sample fixture 生成**——sample.mbt 手写镜像可从 TOML emit 骨架
   （对照门样值面减负，役3 三咬手工对齐成本归零）
3. **组合运行形**——series 桥接 / parallel 剪枝（T-4 正身）

**残余排序（todo R 台账同步）**：typed codegen（A2 先行）> 组合运行
形+剪枝 > 属性骨架（R-3 联动）> stub 生成 > sample 生成。

## 4.8 合同门三颗牙定案（2026-10-12，moonxllm 评审 A 组收编）

> 出处：`moonxllm/.mingspace/moonspace_review.md` A 组（"合同门再补三颗牙"），
> 整合推进役（moonxllm 进度参照）一次拍掉。B/C 组已随 R-2 收（§4.5
> 联动，提交 11fc0ab）。

- **A1 回灌投影闭合**：`check_composition` + `attach_feedback` 双位
  钉——feedback router 的 to_event payload 字段须 ⊆ 宿主 ctx 槽位
  （`make_loopback` 按字段名取 ctx 缺键静默空文回灌，指错字段名的
  router 每轮空转无门能红）。**同笔迁移**：reasoning_base.toml 增
  `context` 槽 + Waiting+ContextReady 行 `assign = ["context",
  "prompt"]`（ReasoningLoop 回灌数据源落底）——旧配置正是评审诊断
  的空文回灌实例，门咬住后当场修。typed 面 ReasoningCtx 增
  `context : String?`（regen 同笔，黄金门自洽）。
- **A2 守卫注册闭合前移**：space 新件 `EffectSpace::check_guards_closed`
  （rules 引用的 guard_name 全集 ⊆ 注入谓词表 key 集，缺者
  `GuardClosureError.MissingPredicates`）；runtime `run` 入口自动
  查——运行中段 MissingGuard 停摆前移成入口拦停（step 面
  MissingGuard 臂保留作白盒防御纵深）。
- **A3 环×双零预算组合门**：space 新件 `EffectSpace::
  has_transition_cycle`（规则图三色 DFS，自环覆盖；loopback 运行环
  不属此图——feedback 守卫另有 R-3 门）；`run` 入口环 ∧ 轮径/墙钟
  双零 ⇒ `RunGateError.UnboundedCycle` 拦停（头注"有环且全零自担"
  口径升级为机械钉）。现役装配链路全非双零（10/12 轮），门不咬。
- **随笔**：发射器 pattern 绑定按引用面发射（未用 payload 字段发
  `_`）——既有 unused 告警零渗入产物；dep gate 白名单同笔收
  space/runtime 的 `core/debug`（门错面 derive(Debug) 显式 extend，
  [0079] 治理）。

## 4.9 handler stub 生成定案（2026-10-12，R-7 收编）

> 出处：spec §4.7 战训新格（装配役盘点遗留）；token.md 顺序口径复核
> 后开工——tokgen S3 在途不涉本域，moonspace 面 EffectHandler 形不动。

- **产物落点 = 非编译文本区 `out/stub_out/<name>_handler_stub.mbt`**：
  消费者**拷贝填空**（宪法：生成物与手写区两区永不拼接——stub 是新
  消费者起点，不是 out/stubs.mbt 的拼接件）；目录无 moon.pkg 不入
  编译面，fmt 不扫（产物禁手写亦禁 fmt 口径延续，黄金门逐字节）。
- **发射面 = `gen.emit_handler_stub(base) : String` 纯函数**：只见
  词表数据（effects/events/prefix——宪法业务词零渗入）；semantics
  标签填空注记 = 模板指令集（宪法唯一可硬编面：query/command/
  commit/rollback/stop 五标签对位注记）。
- **三段式骨架**（moonxllm cmd/SpaceHandler 手写先例可产形）：match
  臂集（全 effect 词表臂 + 未知效应兜底 fail 逃逸臂）+ semantics 注
  记随臂 + 哨兵回执注记与 LoopEvent 构造型样例（词表首事件发射）+
  事件词表闭合清单 + struct 命名 `<Prefix>HandlerStub`。
- **再生入口同链**：cmd/main 扩写 stub_out（门内装配 ≡ cmd 装配同
  款口径）；黄金门 out/gen_gate_test.mbt 追加逐字节 test（三空间）；
  结构门 gen/stub_gate_test.mbt（臂集闭合/注记/命名——sample 直发
  不读盘）。
- **v1 边界**：stub 可编译性由首次真实消费者验收（结构形与
  SpaceHandler 手写先例逐字段同构）；拆臂判定/哨兵事件选型是装配位
  语义，stub 只注记指路不产活代码（防静默错语义）。

## 5 演进路线（役次）

- 役1–2 立项：合同五件 + 四包骨架 + 收编独立模块（proj_dialect v1.6）。
- 役3 解析役（§4）：解析器三入口 + 三门 + 对照门 + assign_from 拍②。
- 役4 沙箱大 loop（§4.5）：数据驱动运行形 + async runner + 四环集成门
  （勘 moonxllm 消费面后拍四点）。
- 合同门三颗牙（§4.8）：moonxllm 评审 A 组收编——A1 回灌投影闭合
  （gen 双位钉 + reasoning TOML 同笔迁移）/ A2 守卫闭合 run 入口前移 /
  A3 环×双零组合门。
- handler stub 生成（§4.9）：R-7 收编——out/stub_out/ 非编译文本区 +
  emit_handler_stub 纯函数 + 三段式骨架 + 双门（黄金逐字节/结构）。
- **下一役候选**：moonxllm 装配役（cmd/X3 位 SpaceHandler 适配 +
  PolicyEngine→guards 翻译，拍④落点）；typed codegen 役（仍列后续；
  `space` 接缝注释签名三件待生成）；verify 役（A3 探针）。

## 6 待裁（编号唯一源）

| # | 事项 | 背景 |
|---|---|---|
| A1 | `[待裁]` feedback 守卫触发后的**上报面形态**：非法转移域上报如何接 runtime 审计（词表不携带重试策略已定，上报通道未定） | `composition.toml` 头注 |
| A2 | `[收账→定案]`（2026-10-11 用户拍"A2 继续"）：codegen 产物包 = **`moonspace/out/`**——生成物 `*_gen.mbt` 纯生成禁手写 + `stubs.mbt` 手写填空区（宪法：两区永不拼接）；发射通道 = **`moonspace/cmd/` 再生入口**（moonxllm 同款，`moon run moonspace/cmd` 重跑写盘）；黄金门 = **out 内重生成 ≡ 入库产物逐字节**。emit 面纯函数（gen 包，String 出口）与落盘面（cmd）分离。typed 产物 v1 范围：State/Event/Effect 枚举（positional）+ Ctx struct + typed step（守卫 `(String, Ctx) -> Bool` 注入，guard 拒 = None；assign 结构体更新式拷贝）；与数据驱动解释器的行为对拍门 = typed codegen 次格 | 宪法「生成器 evolvability」+ moonxllm gen.mbt 先例 |
| A3 | `[收账→定案]`（2026-10-11 探针实证）：proof_* **关键字面不在现役工具链**（verify.md 断言陈旧，两形皆 [4021]/[3002]）；`moon prove` 真存但 **Why3 系**（.mbtp 模型面 + proof_assert + SMT solver，环境缺 z3/cvc5/alt-ergo）——prove 面挂台账待装机；**现役面 = 轻量霍尔先形 `check_triple`（泛型三元组，空洞真语义）+ core 内建 `@qc.check` 属性双轨**（零依赖，已落 verify 首件：词表闭合属性 + 三元组确定性面） | A3 探针 + `verify/contracts.mbt` + `property_test.mbt` |
| A4 | `[待裁]` LoopBack **携带策略与轮径精化**：payload 投影规则扩展（跨槽改名携带）、轮径是否改效应步径、异步 handler 形扩展（真 Port 中途取消） | 役4 v1 口径见 §4.5 |

## 7 工程坑账（本模块实证，勿再踩）

- **`ErrOut` 已从现版 core 移除**——moonttl `error.mbt` 旧先形
  （`pub impl ErrOut for X with message`）勿再抄；现役错误渲染走
  moon 自身对 raise 的呈现（役3 实证）。
- **Error Show 现役 variant-only**：`"\{err}"` 只渲染
  `包路径.变体名`，**载荷全丢**（真网诊断三跑实证）——需要文案的
  逃逸面抬 core `Failure`（`fail(文案)`，Failure 带 Show 出全文）；
  域内语义保留在文案前缀（llm_error_text 翻译门）。终报诊断面
  （term= 渲染）必须穷尽变体载荷。
- **verify.md 访谈断言陈旧**："`proof_requires/ensures` 是语言
  关键字"**不在现役工具链**（A3 探针实证）——proof 面真形 =
  Why3 系 `moon prove`（.mbtp + SMT solver 环境依赖）。引用访谈
  工具链断言前先探针。
- **qc property 防极值**：core `@qc` Arbitrary 生成 Int 极值含
  MIN——性质体内取反/取模前先位掩码取非负（`seed & 0x7fffffff`），
  否则溢出陷阱即 Error。
- **HttpTransport url 空投**：`@wire.HttpTransport` POST 自己构造时
  的 `url` 字段；`RegistryProvider::open` 内部解析端点**不回填**
  transport——必须先 `@wire.endpoint_for(registry, provider~, model~)`
  拆 `Result` 再构造 transport（用户实锤，2026-10-11 真网首跑）。
- **供方对以实证链为准**：`glm` 供方模型表无 flash（default_model=
  glm-5.3 reasoning 档）；真网冒烟走 `glm-coding` + `glm-5.3-flash`
  （X2 实证）。secrets 目录面 providers 字段随消费方入表同步
  （X1 漏记 glm-coding 漂移已修）。
- **独立模块首建前 `rm -rf _build`**——收编子树残留父模块时代
  `_build` 会令构建静默 no-op（役3 再实证；AGENTS.md 反向变体条目同源）。
- **`[0079]` 显式 extend**：`derive(Eq, Debug)` 的型必配显式
  `pub extend Type with Eq::{not_equal, equal}` +
  `@debug.Debug::{to_repr}`（`gen/extends.mbt`，jelly `extends_gen`
  同款——同标准动作，异处：那份是生成物，这份手写）。
- **保留字 lambda 形参**：`guard` 做 `fn(guard) => ...` 形参即
  [3002] parse error（役3 实证，避名 `guard_decl`）。
- **泛型方法名路径不带型参**：`SpaceHandler::m(self : SpaceHandler[T])`
  正形；`SpaceHandler[T]::m` 即 [4027]/[3002]（役4 实证）。
- **标签实参 `=` 非 `:`**：MoonBit 调用形 `f(label=value)`；写 struct
  字段形 `f(label: value)` 即 [4086] labels required（装配役实证）。
