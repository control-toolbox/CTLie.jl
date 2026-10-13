# CTLie

```@meta
CurrentModule = CTLie
```

[CTLie](https://github.com/control-toolbox/CTLie.jl) is a foundational package of the
[control-toolbox](https://control-toolbox.org) ecosystem. It provides the
differential-geometric operators used in geometric optimal control: the Hamiltonian
**lift**, the **Lie derivative** and **Lie bracket** of vector fields, the **Poisson
bracket** of Hamiltonians, and the **partial time derivative**. All of these are also
available through a single convenience macro, [`@Lie`](@ref).

This documentation is aimed at developers and advanced users. End users of optimal
control usually reach these operators through
[OptimalControl.jl](https://control-toolbox.org/OptimalControl.jl), whose documentation
covers their use in solving problems. Here, each operator is presented with its
mathematical definition, then with runnable examples — both on plain Julia `Function`s
and on the typed objects of CTBase
([`VectorField`](@extref CTBase CTBase.Data.VectorField),
[`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian)) — across the trait combinations
(autonomous or not, fixed or variable).

!!! note "Exported operators"
    Unlike most control-toolbox packages, CTLie **exports** its user-facing API —
    [`Lift`](@ref CTLie.Lift), [`ad`](@ref CTLie.ad), [`Poisson`](@ref CTLie.Poisson),
    [`∂ₜ`](@ref CTLie.∂ₜ), [`@Lie`](@ref CTLie.@Lie),
    [`dg_ad_backend`](@ref CTLie.dg_ad_backend) and
    [`dg_ad_backend!`](@ref CTLie.dg_ad_backend!) — so that geometric expressions read
    like the mathematics. Everything else, including the typed objects from CTBase, is
    accessed by qualified path (`Data.VectorField`, `CTLie.LiftedHamiltonianFunction`, …).

!!! tip "[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/control-toolbox/CTLie.jl)"
    DeepWiki offers an interactive, AI-generated overview of this codebase. Answers may be
    inaccurate — use this documentation as the source of truth.

## Quick start

The differential operators need an automatic-differentiation backend: load
`DifferentiationInterface` (which activates CTBase's AD extension) and `ForwardDiff`
(the default AD engine) next to CTLie. Without `ForwardDiff`, the first derivative
evaluation raises a [`CTBase.Exceptions.ExtensionError`](@extref CTBase); see
[Limitations & configuration](limitations.md) to select another backend.

```@example quickstart
using CTLie
using CTBase: Data
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff
nothing # hide
```

Two vector fields, their Lie bracket, and the Poisson bracket of their Hamiltonian lifts:

```@example quickstart
X = Data.VectorField(x -> [x[2], 2x[1]]; is_autonomous=true)
Y = Data.VectorField(x -> [3x[2], -x[1]]; is_autonomous=true)
x0, p0 = [1.0, 2.0], [0.5, 1.0]

Z = @Lie [X, Y]                  # Lie bracket, a VectorField
Z(x0)
```

```@example quickstart
H = @Lie {Lift(X), Lift(Y)}      # Poisson bracket of the lifts
H(x0, p0) ≈ Lift(Z)(x0, p0)      # {H_X, H_Y} = H_[X,Y]
```

## Reading order

| Page | Operator | Mathematical object |
|---|---|---|
| [Hamiltonian lift](lift.md) | [`Lift`](@ref CTLie.Lift) | ``H(x,p) = \langle p, X(x)\rangle`` |
| [Lie derivative & bracket](lie_derivative_bracket.md) | [`ad`](@ref CTLie.ad) | ``X\cdot f`` and ``[X,Y]`` |
| [Poisson bracket](poisson.md) | [`Poisson`](@ref CTLie.Poisson) | ``\{H,G\}`` |
| [Partial time derivative](time_derivative.md) | [`∂ₜ`](@ref CTLie.∂ₜ) | ``\partial_t`` |
| [The `@Lie` macro](lie_macro.md) | [`@Lie`](@ref CTLie.@Lie) | ``[\,\cdot\,]`` and ``\{\,\cdot\,\}`` |
| [Limitations & configuration](limitations.md) | — | constraints, AD backend |

## Mathematical setting

We work on a state space ``\mathcal{X} \subseteq \mathbb{R}^n`` and its cotangent bundle
``T^*\mathcal{X}`` with canonical coordinates ``(x, p) \in \mathbb{R}^n \times \mathbb{R}^n``.

- A **vector field** is a map ``X : \mathcal{X} \to \mathbb{R}^n``.
- A **Hamiltonian** is a scalar map ``H : T^*\mathcal{X} \to \mathbb{R}``, ``(x,p) \mapsto H(x,p)``.

The operators may additionally depend on **time** ``t`` and on a **variable parameter**
``v`` (a decision variable, e.g. a free final time or a design parameter). Which of these
extra arguments appear is encoded by two CTBase traits,
[`TimeDependence`](@extref CTBase CTBase.Traits.TimeDependence) and
[`VariableDependence`](@extref CTBase CTBase.Traits.VariableDependence), set with the
keywords `is_autonomous` and `is_variable`. They fix the call signatures:

| `is_autonomous` | `is_variable` | Vector field | Hamiltonian |
|---|---|---|---|
| `true` (default) | `false` (default) | `X(x)` | `H(x, p)` |
| `false` | `false` | `X(t, x)` | `H(t, x, p)` |
| `true` | `true` | `X(x, v)` | `H(x, p, v)` |
| `false` | `true` | `X(t, x, v)` | `H(t, x, p, v)` |

A one-dimensional state, costate or variable is a scalar (`Number`), not a length-1
vector.

## Notation summary

| Mathematics | Julia |
|---|---|
| Hamiltonian lift ``H = \langle p, X\rangle`` | [`Lift(X)`](@ref CTLie.Lift) |
| Lie derivative ``X\cdot f = \nabla f \cdot X`` | [`ad(X, f)`](@ref CTLie.ad) |
| Lie bracket ``[X, Y]`` | [`ad(X, Y)`](@ref CTLie.ad), `@Lie [X, Y]` |
| Poisson bracket ``\{H, G\}`` | [`Poisson(H, G)`](@ref CTLie.Poisson), `@Lie {H, G}` |
| Partial time derivative ``\partial_t`` | [`∂ₜ(·)`](@ref CTLie.∂ₜ) |
