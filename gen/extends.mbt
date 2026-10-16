// ===== moonspace/gen —— 显式 pub extend 声明（W18 标准动作）=====
// 编译器建议的显式晋升：derive(Eq, Debug) 产出的 equal/not_equal/
// to_repr 不走隐式方法晋升（[0079] 弃用面）。jelly v1 extends_gen
// 同款先例。

///|
pub extend ContractMeta with Eq::{not_equal, equal}

///|
pub extend ContractMeta with @debug.Debug::{to_repr}

///|
pub extend SpacePolicy with Eq::{not_equal, equal}

///|
pub extend SpacePolicy with @debug.Debug::{to_repr}

///|
pub extend CtxField with Eq::{not_equal, equal}

///|
pub extend CtxField with @debug.Debug::{to_repr}

///|
pub extend PayloadField with Eq::{not_equal, equal}

///|
pub extend PayloadField with @debug.Debug::{to_repr}

///|
pub extend EventDecl with Eq::{not_equal, equal}

///|
pub extend EventDecl with @debug.Debug::{to_repr}

///|
pub extend EffectDecl with Eq::{not_equal, equal}

///|
pub extend EffectDecl with @debug.Debug::{to_repr}

///|
pub extend GuardDecl with Eq::{not_equal, equal}

///|
pub extend GuardDecl with @debug.Debug::{to_repr}

///|
pub extend StateDecl with Eq::{not_equal, equal}

///|
pub extend StateDecl with @debug.Debug::{to_repr}

///|
pub extend TransitionDecl with Eq::{not_equal, equal}

///|
pub extend TransitionDecl with @debug.Debug::{to_repr}

///|
pub extend InvariantDecl with Eq::{not_equal, equal}

///|
pub extend InvariantDecl with @debug.Debug::{to_repr}

///|
pub extend SpaceBase with Eq::{not_equal, equal}

///|
pub extend SpaceBase with @debug.Debug::{to_repr}

///|
pub extend CellDecl with Eq::{not_equal, equal}

///|
pub extend CellDecl with @debug.Debug::{to_repr}

///|
pub extend SpaceDomain with Eq::{not_equal, equal}

///|
pub extend SpaceDomain with @debug.Debug::{to_repr}

///|
pub extend StateEventBridge with Eq::{not_equal, equal}

///|
pub extend StateEventBridge with @debug.Debug::{to_repr}

///|
pub extend ParallelDecl with Eq::{not_equal, equal}

///|
pub extend ParallelDecl with @debug.Debug::{to_repr}

///|
pub extend SeriesDecl with Eq::{not_equal, equal}

///|
pub extend SeriesDecl with @debug.Debug::{to_repr}

///|
pub extend FeedbackGuard with Eq::{not_equal, equal}

///|
pub extend FeedbackGuard with @debug.Debug::{to_repr}

///|
pub extend FeedbackDecl with Eq::{not_equal, equal}

///|
pub extend FeedbackDecl with @debug.Debug::{to_repr}

///|
pub extend Composition with Eq::{not_equal, equal}

///|
pub extend Composition with @debug.Debug::{to_repr}

///|
pub extend ContractError with @debug.Debug::{to_repr}

///|
pub extend AssignFrom with Eq::{not_equal, equal}

///|
pub extend AssignFrom with @debug.Debug::{to_repr}
