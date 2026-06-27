# Lie derivative and Lie bracket

```@meta
CurrentModule = CTLie
```

The single function [`ad`](@ref CTLie.ad) ("adjoint action")
computes two related objects, **dispatching on the output of its second argument**:

- if the second argument is **scalar-valued**, `ad` returns the **Lie derivative**;
- if it is **vector-valued**, `ad` returns the **Lie bracket**.

Both are computed by automatic differentiation, so the AD backend extension must be
loaded.

## Lie derivative

The Lie derivative of a scalar function ``f`` along a vector field ``X`` is the
directional derivative of ``f`` in the direction ``X``:

```math
(X \cdot f)(x) = \nabla f(x)^\top X(x).
```

It measures the infinitesimal rate of change of ``f`` along the flow of ``X``.

## Lie bracket

The Lie bracket of two vector fields ``X`` and ``Y`` is itself a vector field. With the
convention used here,

```math
[X, Y](x) = J_Y(x)\, X(x) - J_X(x)\, Y(x),
```

where ``J_X`` and ``J_Y`` are the Jacobian matrices. The bracket is **antisymmetric**,
``[X, Y] = -[Y, X]``, and it vanishes when the flows of ``X`` and ``Y`` commute. Iterated
brackets ``[[X, Y], Y]`` appear throughout geometric control (e.g. in the analysis of
singular extremals).

```@setup ad
using CTLie
using CTBase.Data
using CTBase.Traits
import DifferentiationInterface
```

## On plain functions

For Julia `Function`s the traits come from the `is_autonomous` / `is_variable` keywords.

### Lie derivative — energy along a rotation

The rotation field ``X(x) = (x_2, -x_1)`` preserves the squared norm
``f(x) = x_1^2 + x_2^2``, so ``X \cdot f \equiv 0``:

```@example ad
X = x -> [x[2], -x[1]]
f = x -> x[1]^2 + x[2]^2
L = ad(X, f)
L([1.0, 2.0])
```

### Lie bracket — two autonomous fields

```@example ad
F = x -> [x[2], 2x[1]]
G = x -> [3x[2], -x[1]]
B = ad(F, G)
B([1.0, 2.0])
```

### Non-autonomous — `(t, x)`

```@example ad
Ft = (t, x) -> [t + x[2], -2x[1]]
Gt = (t, x) -> [t + 3x[2], -x[1]]
Bt = ad(Ft, Gt; is_autonomous=false)
Bt(1.0, [1.0, 2.0])
```

### Variable-dependent — `(x, v)`

```@example ad
Fv = (x, v) -> [x[2] + v, 2x[1]]
Gv = (x, v) -> [3x[2], v - x[1]]
Bv = ad(Fv, Gv; is_variable=true)
Bv([1.0, 2.0], 1.0)
```

### Non-autonomous and variable-dependent — `(t, x, v)`

```@example ad
Ftv = (t, x, v) -> [t + x[2] + v, -2x[1] - v]
Gtv = (t, x, v) -> [t + 3x[2] + v, -x[1] - v]
Btv = ad(Ftv, Gtv; is_autonomous=false, is_variable=true)
Btv(1.0, [1.0, 2.0], 1.0)
```

## On typed vector fields

When both arguments are typed [`VectorField`](@extref CTBase CTBase.Data.VectorField)s, `ad`
returns a **typed `VectorField`** whose traits are inherited from the operands. The two
fields must share the same time- and variable-dependence (see
[Limitations & configuration](limitations.md)).

```@example ad
X = VectorField(x -> [x[2], 2x[1]]; is_autonomous=true, is_variable=false)
Y = VectorField(x -> [3x[2], -x[1]]; is_autonomous=true, is_variable=false)
Z = ad(X, Y)
```

```@example ad
Z([1.0, 2.0])
```

The result being itself a `VectorField`, brackets nest naturally:

```@example ad
Z2 = ad(ad(X, Y), Y)
Z2([1.0, 2.0])
```

### Lie derivative with a typed field

A typed `VectorField` against a scalar `Function` gives the Lie derivative, returned as a
plain `Function`:

```@example ad
X = VectorField(x -> [x[2], -x[1]]; is_autonomous=true)
g = x -> x[1]^2 + x[2]^2
ad(X, g)([1.0, 2.0])
```

## Antisymmetry, numerically

```@example ad
F = VectorField(x -> [x[2]^2, -2x[1]*x[2]]; is_autonomous=true)
G = VectorField(x -> [x[1]*(1 + x[2]), 3x[2]^3]; is_autonomous=true)
x0 = [1.0, 2.0]
ad(F, G)(x0) ≈ -ad(G, F)(x0)
```

## See also

- [`ad`](@ref CTLie.ad) — full docstring and method list.
- [The `@Lie` macro](lie_macro.md) — write `@Lie [X, Y]` instead of `ad(X, Y)`, with
  nesting and arithmetic.
- [Limitations & configuration](limitations.md) — no Lie operations on a
  [`HamiltonianVectorField`](@extref CTBase CTBase.Data.HamiltonianVectorField), no in-place fields,
  matching traits.
