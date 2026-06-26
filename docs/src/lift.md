# Hamiltonian lift

```@meta
CurrentModule = CTLie
```

The **Hamiltonian lift** of a vector field ``X`` is the scalar function on the cotangent
bundle obtained by pairing the costate ``p`` with ``X``:

```math
H(x, p) = \langle p, X(x)\rangle = p^\top X(x).
```

This is a purely algebraic operation — it uses **no automatic differentiation**. The lift
is the bridge from the *velocity* picture (vector fields) to the *Hamiltonian* picture
(scalar functions on phase space), and it is the building block of the Pontryagin
maximum principle: the pseudo-Hamiltonian is a sum of lifts of the drift and control
vector fields.

When ``X`` depends on time ``t`` and/or a variable ``v``, the lift carries the same
dependence:

```math
H(t, x, p) = p^\top X(t, x), \qquad
H(x, p, v) = p^\top X(x, v), \qquad
H(t, x, p, v) = p^\top X(t, x, v).
```

The relevant method is [`Lift`](@ref CTLie.Lift).

```@setup lift
using CTLie
using CTBase.Data
using CTBase.Traits
import DifferentiationInterface
```

## On plain functions

Given a Julia `Function`, [`Lift`](@ref CTLie.Lift) returns a
`Function` with the matching call signature. The traits are read from the
`is_autonomous` and `is_variable` keyword arguments (both default to autonomous/fixed).

### Autonomous, fixed — `X(x)`

```@example lift
X = x -> [x[2], -x[1]]
H = Lift(X)
H([1.0, 2.0], [0.5, 1.0])      # p' * X(x) = 0.5*2 + 1.0*(-1)
```

### Non-autonomous — `X(t, x)`

```@example lift
Xt = (t, x) -> [t * x[2], -x[1]]
Ht = Lift(Xt; is_autonomous=false)
Ht(2.0, [1.0, 2.0], [0.5, 1.0])   # p' * X(t, x)
```

### Variable-dependent — `X(x, v)`

```@example lift
Xv = (x, v) -> [x[2], -v * x[1]]
Hv = Lift(Xv; is_variable=true)
Hv([1.0, 2.0], [0.5, 1.0], 3.0)   # p' * X(x, v)
```

### Non-autonomous and variable-dependent — `X(t, x, v)`

```@example lift
Xtv = (t, x, v) -> [t * x[2], -v * x[1]]
Htv = Lift(Xtv; is_autonomous=false, is_variable=true)
Htv(2.0, [1.0, 2.0], [0.5, 1.0], 3.0)
```

## On typed vector fields

When the argument is a typed [`VectorField`](@extref CTBase CTBase.Data.VectorField), `Lift`
returns a typed [`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) whose traits are inherited
from the vector field — no keyword arguments are needed.

```@example lift
Xt = VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
H  = Lift(Xt)
```

```@example lift
H([1.0, 2.0], [0.5, 1.0])
```

The same works for every trait combination; here a non-autonomous, variable-dependent
field:

```@example lift
Xtv = VectorField((t, x, v) -> [t * x[2], -v * x[1]];
                  is_autonomous=false, is_variable=true)
Htv = Lift(Xtv)
Htv(2.0, [1.0, 2.0], [0.5, 1.0], 3.0)
```

!!! note "Not for Hamiltonian vector fields"

    `Lift` accepts a plain [`VectorField`](@extref CTBase CTBase.Data.VectorField), not a
    [`HamiltonianVectorField`](@extref CTBase CTBase.Data.HamiltonianVectorField): the latter
    already lives on phase space with signature `(x, p)`. Lifting one raises a
    `NotImplemented` error — see [Limitations & configuration](limitations.md).

## See also

- [`Lift`](@ref CTLie.Lift) — full docstring and method list.
- [Poisson bracket](poisson.md) — the lift connects Lie brackets of vector fields to
  Poisson brackets of their lifts (see the correspondence verified there).
