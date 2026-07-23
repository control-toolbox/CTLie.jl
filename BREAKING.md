# Breaking Changes

<!-- markdownlint-disable MD024 -->

This document describes breaking changes in CTLie.jl releases and how to migrate your code.

---

## [0.1.5-beta] - 2026-07-23

### Breaking Changes: `ad_backend` now takes `Differentiation.AbstractADBackend`

#### What Changed

- `ad`, `Poisson`, `∂ₜ`, and `dg_ad_backend!` no longer accept a raw
  `ADTypes.AbstractADType` for the `ad_backend` keyword; they now require a
  `CTBase.Differentiation.AbstractADBackend` instance.
- `ADTypes` is removed from CTLie's hard dependencies (moved to test-only in
  `Project.toml`).
- This is a side effect of fixing a load-time bug: `Differentiation.build_ad_backend`
  (used internally to build the global default backend) was removed from CTBase in
  `0.28.3-beta`, breaking `using CTLie`.

#### Migration

```julia
# Before
using ADTypes
ad(X, Y; ad_backend=AutoForwardDiff())
dg_ad_backend!(AutoForwardDiff())

# After
import CTBase: Differentiation
import ADTypes

ad(X, Y; ad_backend=Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff()))
dg_ad_backend!(Differentiation.DifferentiationInterface())   # CPU default: AutoForwardDiff

# GPU execution:
dg_ad_backend!(Differentiation.DifferentiationInterface{CTBase.Strategies.GPU}())
```

#### Rationale

CTLie should depend on CTBase's differentiation *abstraction*
(`Differentiation.AbstractADBackend`, parameterized over the CPU/GPU execution
device) rather than on one concrete implementation's underlying `ADTypes` type.
This lets users pick CPU or GPU execution explicitly, and means a future
non-`ADTypes`-based backend can be dropped in without any change to CTLie.

---

## [0.1.4-beta] - 2026-07-15

### No Breaking Changes

This release restores dropped type-parameter bounds in `where` clauses (42 sites)
and adds consistency bounds to `Poisson` and `Lift` entry points. Tightening a
`where`-clause bound cannot invalidate a previously-valid call, so there is no
behavior change.

### Migration

**No action required.** All existing code continues to work without changes.

---

## [0.1.3-beta] - 2026-07-13

### No Breaking Changes

This release bumps CTBase compat to `0.28` and reworks the test system.

#### Dependency Updates

- **CTBase compat widened to `0.28`**: CTLie is compatible with the CTBase 0.28
  strategy parameter contract (`parameter` / `default_parameter` replacing
  `get_parameter_type` / `_default_parameter`). CTLie does not implement
  strategies itself, so no source change is required.
- **No breaking changes**: existing code continues to work unchanged.

#### Test System

- **`test/Project.toml` removed**: test dependencies are now declared in the
  main `Project.toml` as `[extras]` and `[targets]`. This is an internal change
  that does not affect users of the package.

### Migration

**No action required.** All existing code continues to work without changes.

---

## [0.1.2-beta] - 2026-07-09

### No Breaking Changes

This release widens CTBase compat to `0.25, 0.26, 0.27`.

### Migration

**No action required.** All existing code continues to work without changes.

---

## [0.1.1-beta] - 2026-06-28

### No Breaking Changes

This release widens CTBase compat to `0.25, 0.26`.

### Migration

**No action required.** All existing code continues to work without changes.

---

## [0.1.0-beta] - 2026-06-26

### Breaking Changes: Differential-geometry layer moved from CTFlows to CTLie

The differential-geometry operators (`ad`, `Lift`, `Poisson`, `∂ₜ`, `@Lie`)
formerly in `CTFlows.DifferentialGeometry` are now in `CTLie`.

#### What Changed

- **Module path**: `CTFlows.DifferentialGeometry.ad` → `CTLie.ad` (and similarly
  for `Lift`, `Poisson`, `∂ₜ`, `@Lie`).
- **Internal sentinels**: re-rooted to `CTBase.Core.NotProvidedType` /
  `NotProvided` (requires CTBase ≥ 0.25).
- **`@Lie` macro**: generated calls now target `CTLie._lie_mac` /
  `_poisson_mac` / `__dg_ad_backend`.

#### Migration

```julia
# Before (CTFlows)
using CTFlows.DifferentialGeometry
ad(f, g)

# After (CTLie)
using CTLie
CTLie.ad(f, g)
```

```julia
# Before (CTFlows)
using CTFlows.DifferentialGeometry
@Lie ∂ₜ f

# After (CTLie)
using CTLie
@Lie ∂ₜ f
```

#### Rationale

The differential-geometry layer is a standalone mathematical tool that does not
depend on the flow integration machinery. Moving it to its own package (`CTLie`)
clarifies the dependency graph and allows downstream packages to use Lie
derivative calculus without pulling in CTFlows.

### Dependencies

- **CTBase** pinned to `"0.25"` (`Core.NotProvided` lives there).
- **ADTypes**, **DocStringExtensions**, **MacroTools** as hard dependencies.
