# moonspace 红线裁定簿（const）

> 定位：**模块级裁定簿**——收 moonspace 红线（判据：约束 ≥ 两个包，或涉
> 合同/生成边界契约）；包内实现细节在各包 `moon.pkg` 头注自持。
> 每条 = 判级 + 结论 + 一句理由 + 落点；编号 **R-N** 顺排。
> 两卷分工：本卷管**禁止**（红线），`spec.md` 管**事实**（结构决策
> M-N / 待裁 A-N 编号唯一源在彼）；本簿引用 M-N/A-N 不重抄。

## R-1 转移纯函数 [定案](2026-10-11,役3 核)

**Mealy 转移禁副作用**：`transition(state, event) -> (state, effect)?` 是纯
函数——禁 IO、禁可变全局、禁时间读取；effect 只**产出**不**执行**，执行在
handler（runtime 面），持久化/权限/审计留 Port 层不漂进 handler。
理由：转移不纯 = 解空间不可枚举、属性测试失效、回放不可信
（`.mingspace/effect.md` 定案；spec.md M3）。
落点：`space/effect_space.mbt` 接缝注释（transition / allowed_effects /
invariants_hold 三件签名）；codegen 役产物同款约束。

## R-2 CPS 单层 [定案](.mingspace/effect.md 定案;役4 async 对位拍①)

**禁任意 continuation 捕获**：解释形态现役 = **async 直返形**（役4 拍①：
`EffectHandler.handle(effect) -> LoopEvent raise`，每效应恰一次解释、
结果事件立返喂回——CPS 单层的 async 对位，k 恰一次施加语义不变）；
禁多层嵌套、禁 resume 重入、禁 continuation 存储逃逸步进面；回调面
带超时与取消（预算面 runner 持有，超时=Timeout 拦停）。
理由：深层嵌套难调试；任意捕获使回滚边界不清、可验证性崩（effect.md
风险点四条）。
落点：`runtime/runtime_sandbox.mbt`（EffectHandler trait + run runner）。

## R-3 feedback 显式回送 [定案](.mingspace/tensor.md 定案,役3 核)

**回送 = 显式 LoopBack 事件**：禁 continuation 捕获重入；router 行
`from_state → to_event` 声明式回灌；守卫必填（max_rounds / timeout_ms
至少启用其一，0 = 不启用），守卫触发 ⇒ 终止并上报（上报面形态待裁
spec.md A1）。
理由：任意重入 = 有界终止性丢失；声明式回送才可验证可达与终止。
落点：`domain/composition.toml` [[feedback]] 合同；
`gen/check.mbt::check_composition` 守卫必填门。

## R-4 生成器零业务词 [定案](宪法:生成器 evolvability)

**gen 代码禁业务词汇**：BM25 / 向量 / 图谱 / LLM 等词只住
`domain/*.toml` 数据文件；生成器唯一可硬编码面 = semantics 封闭词表
（query/command/commit/rollback/stop）与 MoonBit 内建保留名。
理由：换空间 = 换数据不换代码；新方言是新数据不是新代码。
落点：`gen/*.mbt` 全部（现役 parse/check 零业务词，对照
`@space.effect_semantics` 唯一词表引用）；codegen 役评审门。

## R-5 合同持久演化 [定案](仓规宪法)

**TOML 合同三规则**：新键可选（解析器缺省，缺键不报错）；未知键忽略；
删键/改义**同笔迁移**全部手写 TOML。
理由：TOML 是持久契约——新 generator 必须读旧文件，旧文件不被静默改义。
落点：`gen/parse.mbt`（缺省表见 spec.md §4）；改合同的役次必跑对照门
（R-6）。

## R-6 真源跟随与漂移门 [定案](役3 立门)

**手写 `domain/*.toml` = 真源；`sample.mbt` 跟随不反向**；对照门
（`gen/contract_gate_test.mbt`）**读真实文件**与 sample 逐字段全等 +
三门闭合全绿——漂移即红；禁用内嵌字符串替身文件（门必须吃真文件，
scope_gate 先例）。
理由：镜像测试吃替身 = 漂移不红，真源失去守卫；合同↔文件冲突先判
落后方向再动（spec.md M9 合同优先——役3 `[meta]` 补齐先例）。
落点：`gen/contract_gate_test.mbt`；改 `domain/*.toml` 或 `sample.mbt`
的同笔必跑。

## R-7 三沙箱依赖面界 [定案](.mingspace/sandbox.md+verify.md 划界)

**依赖单向不回穿**：`space` 零依赖（纯类型面；`Json` 为内建型不引包，
役4 注）；`runtime` 只向下依赖 space；`verify` 只吃 State/Event/Effect/
Transition/Invariant——**零真实 Port**（RocksDB / LLM / Git 一概不见）；
`gen` 向下依赖 space（词表核对唯一去向）。沙箱间禁平级互依；业务词随
R-4 同族禁进 space / verify；宿主适配只落宿主 cmd 装配位
（役4 拍④，moonspace 不进 agent 包白名单）。
理由：面界由依赖门钉死，拆完不许长回去（②层分文件 D-17
同族纪律）。
落点：各包 `moon.pkg` import 面；机械化 scope 门件随 codegen 役补
（hex-gate 同款，todo.md R-4 台账）。

## R-8 错误面不穿透 [定案](役3 立,R-1/D-18 同族)

**ContractError 是合同面唯一错误型**：解析/核对错
（MissingKeyErr / TypeErr / ValueErr）不与将来 runtime 的执行错
（超时/权限/审计）、verify 的断言错混型；跨面传播必须门上翻译。
理由：政策/合同/执行/断言四类错各归其位——混型 = 换装或排查时语义崩。
落点：`gen/contract_error.mbt`；runtime / verify 立错误面时同款分判。

## R-9 守卫面分判 [定案](2026-10-11 装配役钉②补)

**guards 只判解空间数据条件**：守卫谓词入参 = ctx 槽位（C-21 白盒面，
`has_hits` 形）；**带外部语义的门禁塞守卫**——工具许可（Json 参数 +
policy 引擎语义）留 handler 域内哨兵面（policy 判否 → 哨兵事件回灌，
宿主 dispatch 先例），判否走 `ToolDenied` 事件回灌续轮而非
GuardRejected。
理由：守卫判「解空间数据条件成立否」，许可判「外部世界允否」——两类
谓词的输入面/失败语义/审计去向全不同，混装 = 面混（R-8 同族）。
落点：装配位 SpaceHandler（宿主 cmd）；`agent_space_*.toml` 守卫
零声明即本条实证；verify 守卫谓词面。
