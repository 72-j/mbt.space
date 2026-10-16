// ===== moonspace/gen —— 组合运行形构造器（装配役 R-6 组合格）=====
// 口径：series 双文件对 + 桥行闭合核对（from_state ∈ 源状态词表 /
// to_event ∈ 目标事件词表）；parallel 双成员 + sync 非空 v1 拒收
// （边界③）+ **构造期 BFS 可达性剪枝**——interleaving 积可达集 =
// Π 成员可达集（数学事实：独立推进下声明态未必可达，剪枝咬合点 =
// 成员声明态 ⊋ 可达态）。成员空间不挂 feedback（组合正交：feedback
// 是独立组合件，役4 已证）。

///|
/// series 运行形构造：源/目标文件对 + 桥行闭合核对
pub fn series_from_contract(
  source_base : SpaceBase,
  source_domain : SpaceDomain,
  target_base : SpaceBase,
  target_domain : SpaceDomain,
  series : SeriesDecl,
) -> @space.SeriesForm raise {
  if series.source != source_base.meta.name {
    raise ValueErr(
      "series \{series.name}: source \"\{series.source}\" 与源文件对 \"\{source_base.meta.name}\" 不一致",
    )
  }
  if series.target != target_base.meta.name {
    raise ValueErr(
      "series \{series.name}: target \"\{series.target}\" 与目标文件对 \"\{target_base.meta.name}\" 不一致",
    )
  }
  let source = space_from_contract(source_base, source_domain, [])
  let target = space_from_contract(target_base, target_domain, [])
  let state_names = name_set(source.states)
  let event_names = name_set(target.events.map(fn(event) { event.name }))
  let bridges : Array[@space.BridgeSpec] = []
  for bridge in series.adapter {
    if !state_names.contains(bridge.from_state) {
      raise ValueErr(
        "series \{series.name}: adapter from_state \"\{bridge.from_state}\" 不在源状态词表",
      )
    }
    if !event_names.contains(bridge.to_event) {
      raise ValueErr(
        "series \{series.name}: adapter to_event \"\{bridge.to_event}\" 不在目标事件词表",
      )
    }
    bridges.push({ from_state: bridge.from_state, to_event: bridge.to_event, })
  }
  { name: series.name, source, target, bridges, }
}

///|
/// parallel 运行形构造：双成员（构造序 = 源标记 Left/Right）+ sync
/// v1 拒收 + BFS 可达剪枝
pub fn parallel_from_contract(
  base0 : SpaceBase,
  domain0 : SpaceDomain,
  base1 : SpaceBase,
  domain1 : SpaceDomain,
  parallel : ParallelDecl,
) -> @space.ParallelForm raise {
  if parallel.spaces.length() != 2 {
    raise ValueErr(
      "parallel \{parallel.name}: v1 成员数钉二（实得 \{parallel.spaces.length()}；N>2 挂余项）",
    )
  }
  if parallel.spaces[0] != base0.meta.name ||
    parallel.spaces[1] != base1.meta.name {
    raise ValueErr(
      "parallel \{parallel.name}: spaces \"\{parallel.spaces[0]}/\{parallel.spaces[1]}\" 与文件对 \"\{base0.meta.name}/\{base1.meta.name}\" 不一致",
    )
  }
  if parallel.sync.length() > 0 {
    raise ValueErr(
      "parallel \{parallel.name}: sync 非空 v1 不做（边界③；现役仅纯 interleaving）",
    )
  }
  let member0 = space_from_contract(base0, domain0, [])
  let member1 = space_from_contract(base1, domain1, [])
  {
    name: parallel.name,
    member0,
    member1,
    sync: parallel.sync,
    reachable: bfs_reachable(member0, member1),
  }
}

///|
/// BFS 可达状态对（成员自身规则集独立推进；起点 = 双初始态；含守卫
/// 出边——守卫拒否是运行时面，构造面过近似保守 sound）
fn bfs_reachable(
  member0 : @space.EffectSpace,
  member1 : @space.EffectSpace,
) -> Array[(String, String)] {
  let seen : Map[String, Bool] = Map([])
  let order : Array[(String, String)] = []
  let queue : Array[(String, String)] = [
    (member0.initial_state, member1.initial_state),
  ]
  let mut head = 0
  while head < queue.length() {
    let pair = queue[head]
    head = head + 1
    let (state0, state1) = pair
    let key = "\{state0}|\{state1}"
    if seen.contains(key) {
      continue
    }
    seen.set(key, true)
    order.push((state0, state1))
    for rule in member0.rules {
      if rule.from_state == state0 {
        queue.push((rule.to_state, state1))
      }
    }
    for rule in member1.rules {
      if rule.from_state == state1 {
        queue.push((state0, rule.to_state))
      }
    }
  }
  order
}

///|
/// 声明积对数（剪枝率分母：Π 成员声明态数；v1 双成员）
pub fn parallel_declared_pairs(form : @space.ParallelForm) -> Int32 {
  form.member0.states.length() * form.member1.states.length()
}
