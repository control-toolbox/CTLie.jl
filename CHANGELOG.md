# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to CTLie.jl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.3-beta] - 2026-07-13

### 🔧 Changed

- **CTBase compat bumped to `0.28`** in `Project.toml` and `docs/Project.toml`.
  CTLie is compatible with the CTBase 0.28 strategy parameter contract
  (`parameter` / `default_parameter`); no source change required.

### 🧪 Testing

- **Test system reworked**: `test/Project.toml` removed. Test dependencies
  (Aqua, DifferentiationInterface, ForwardDiff, Test) are now declared in the
  main `Project.toml` as `[extras]` and `[targets]`, following the pattern used
  across the control-toolbox ecosystem (CTBase, CTModels, CTSolvers). This
  simplifies the test environment setup and avoids a separate test project file.

### 📚 Documentation

- **`docs/Project.toml`**: CTLie removed from `[deps]` (it is resolved via the
  package itself); CTBase compat bumped to `0.28`.

---

## [0.1.2-beta] - 2026-07-09

### 🔧 Changed

- **CTBase compat widened to `0.25, 0.26, 0.27`** in `Project.toml`.
  No source change; CTLie is compatible with CTBase 0.27 (Plotting engine,
  strategy parameter contract preparations).

---

## [0.1.1-beta] - 2026-06-28

### 🔧 Changed

- **CTBase compat widened to `0.25, 0.26`** in `Project.toml`.
  CTBase 0.26 adds the `ControlDependence` trait family (purely additive);
  CTLie has no source change and is compatible with both 0.25 and 0.26.

---

## [0.1.0-beta] - 2026-06-26

### ✨ New Features

#### **Differential-geometry layer**

- **Ported from CTFlows into CTLie**: the differential-geometry operators
  (`ad`, `Lift`, `Poisson`, `∂ₜ`, `@Lie`) formerly in `CTFlows.DifferentialGeometry`
  are now in the top-level `CTLie` module (no submodule).
  - **`ad`**: adjoint operator for vector fields and Hamiltonians.
  - **`Lift`**: lift of a function to a vector field / Hamiltonian vector field.
  - **`Poisson`**: Poisson bracket for Hamiltonians.
  - **`∂ₜ`**: partial time derivative.
  - **`@Lie`**: macro for Lie derivative computation.
  - Internal sentinel re-rooted to `CTBase.Core.NotProvidedType` / `NotProvided`.
  - `@Lie` macro's generated calls re-rooted to `CTLie._lie_mac` / `_poisson_mac`
    / `__dg_ad_backend`.
  - All docstrings re-rooted to `CTLie` (CTBase symbols via `@extref`).

### 📚 Documentation

- **Migrated to DocumenterVitepress**: guide pages ported from CTFlows,
  re-rooted to CTLie. Seven guide pages covering the differential-geometry
  operators. Build with DocumenterVitepress mirroring CTBase's docs setup
  (`.vitepress` scaffolding, components, `api_reference.jl`, `InterLinks` to
  CTBase).

### 🧪 Testing

- **Test suite migrated**: six differential-geometry unit-test files under
  `test/suite/differential_geometry/`, Aqua check under `test/suite/meta/`.
  Driven by `CTBase.run_tests` (TestRunner extension). 374 tests pass.

### 📦 Dependencies

- **CTBase** pinned to `"0.25"` (`Core.NotProvided` lives there).
- **ADTypes**, **DocStringExtensions**, **MacroTools** as hard dependencies.
- **DifferentiationInterface**, **ForwardDiff** as test-only dependencies
  (to activate the `CTBaseDifferentiationInterface` extension).

---

## [0.0.1] - 2026-06-25

### 📦 Initial setup

- Repository created and configured with CI workflows, auto-assign,
  JuliaFormatter, typos check, and ct-registry integration.
