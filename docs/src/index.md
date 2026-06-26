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

This guide is aimed at advanced users and developers. Each operator is presented first
with its mathematical definition, then with runnable examples — both on plain Julia
`Function`s and on the typed objects ([`VectorField`](@extref CTBase),
[`Hamiltonian`](@extref CTBase)) — across the various trait combinations
(autonomous or not, fixed or not).

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
extra arguments appear is encoded by the trait system below.

## Installation and access

CTLie exports its operators directly: a single `using CTLie` brings [`Lift`](@ref CTLie.Lift),
[`ad`](@ref CTLie.ad), [`Poisson`](@ref CTLie.Poisson), [`∂ₜ`](@ref CTLie.∂ₜ) and
[`@Lie`](@ref CTLie.@Lie) into scope:

```@example dg
using CTLie   # Lift, ad, Poisson, ∂ₜ, @Lie
nothing # hide
```

Automatic differentiation is provided by a pluggable backend. The default relies on
`DifferentiationInterface.jl`, which must be loaded for [`ad`](@ref CTLie.ad),
[`Poisson`](@ref CTLie.Poisson) and [`∂ₜ`](@ref CTLie.∂ₜ) to compute gradients and
derivatives:

```@example dg
import DifferentiationInterface   # activates the AD backend extension
nothing # hide
```

See [Limitations & configuration](limitations.md) for how to select another backend.

## Notation summary

| Mathematics | Julia |
|---|---|
| Hamiltonian lift ``H = \langle p, X\rangle`` | [`Lift(X)`](@ref CTLie.Lift) |
| Lie derivative ``X\cdot f = \nabla f \cdot X`` | [`ad(X, f)`](@ref CTLie.ad) |
| Lie bracket ``[X, Y]`` | [`ad(X, Y)`](@ref CTLie.ad), `@Lie [X, Y]` |
| Poisson bracket ``\{H, G\}`` | [`Poisson(H, G)`](@ref CTLie.Poisson), `@Lie {H, G}` |
| Partial time derivative ``\partial_t`` | [`∂ₜ(·)`](@ref CTLie.∂ₜ) |
