# Poisson bracket

```@meta
CurrentModule = CTLie
```

The **Poisson bracket** of two Hamiltonians ``H`` and ``G`` on the cotangent bundle is

```math
\{H, G\} = \nabla_p H^\top \nabla_x G - \nabla_x H^\top \nabla_p G .
```

It is the symplectic counterpart of the Lie bracket and is central to Hamiltonian
mechanics: ``\{H, \cdot\}`` generates the flow of the Hamiltonian system associated with
``H``, and ``\{H, G\} = 0`` means ``G`` is a conserved quantity along that flow.

The relevant method is [`Poisson`](@ref CTLie.Poisson). It is
computed by automatic differentiation, so the AD backend extension must be loaded.

```@setup poisson
using CTLie
using CTBase.Data
using CTBase.Traits
import DifferentiationInterface
```

## Algebraic properties

The Poisson bracket is a Lie bracket on the space of smooth functions: it is bilinear,
antisymmetric, and satisfies the Leibniz rule and the Jacobi identity.

```math
\begin{aligned}
&\text{antisymmetry:} && \{H, G\} = -\{G, H\}, \\
&\text{bilinearity:}  && \{H_1 + H_2, G\} = \{H_1, G\} + \{H_2, G\}, \\
&\text{Leibniz:}      && \{H_1 H_2, G\} = \{H_1, G\}\,H_2 + H_1\,\{H_2, G\}, \\
&\text{Jacobi:}       && \{H, \{G, K\}\} + \{G, \{K, H\}\} + \{K, \{H, G\}\} = 0 .
\end{aligned}
```

All four hold numerically. Take three autonomous Hamiltonians:

```@example poisson
f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
h = (x, p) -> x[2]^2 - 2x[1]^2 + p[1]^2 - 2p[2]^2
x, p = [1.0, 2.0], [2.0, 1.0]
nothing # hide
```

```@example poisson
# antisymmetry
Poisson(f, g)(x, p) ≈ -Poisson(g, f)(x, p)
```

```@example poisson
# bilinearity
fpg = (x, p) -> f(x, p) + g(x, p)
Poisson(fpg, h)(x, p) ≈ Poisson(f, h)(x, p) + Poisson(g, h)(x, p)
```

```@example poisson
# Leibniz rule
fg = (x, p) -> f(x, p) * g(x, p)
Poisson(fg, h)(x, p) ≈ Poisson(f, h)(x, p) * g(x, p) + f(x, p) * Poisson(g, h)(x, p)
```

```@example poisson
# Jacobi identity
Poisson(f, Poisson(g, h))(x, p) +
Poisson(g, Poisson(h, f))(x, p) +
Poisson(h, Poisson(f, g))(x, p) ≈ 0.0
```

## On plain functions

The traits come from the `is_autonomous` / `is_variable` keywords.

### Autonomous — `H(x, p)`

```@example poisson
H = (x, p) -> p[1]^2 / 2 + x[1]^2
G = (x, p) -> x[1] * p[1]
Poisson(H, G)([1.0, 2.0], [0.5, 1.0])
```

### Non-autonomous — `H(t, x, p)`

```@example poisson
Ht = (t, x, p) -> t * x[2]^2 + 2x[1]^2 + p[1]^2 + t
Gt = (t, x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] - t
Poisson(Ht, Gt; is_autonomous=false)(2.0, [1.0, 2.0], [2.0, 1.0])
```

### Variable-dependent — `H(x, p, v)`

```@example poisson
Hv = (x, p, v) -> v[1] * x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
Gv = (x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] - v[2]
Poisson(Hv, Gv; is_variable=true)([1.0, 2.0], [2.0, 1.0], [4.0, 4.0])
```

### Non-autonomous and variable-dependent — `H(t, x, p, v)`

```@example poisson
Htv = (t, x, p, v) -> t * v[1] * x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
Gtv = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] + t - v[2]
Poisson(Htv, Gtv; is_autonomous=false, is_variable=true)(2.0, [1.0, 2.0], [2.0, 1.0], [4.0, 4.0])
```

## On typed Hamiltonians

When both arguments are typed [`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian)s, `Poisson`
returns a **typed `Hamiltonian`** whose traits are inherited from the operands. Both must
share the same time- and variable-dependence (see
[Limitations & configuration](limitations.md)).

```@example poisson
F = Hamiltonian((x, p) -> p[1]^2 / 2 + x[1]^2; is_autonomous=true)
G = Hamiltonian((x, p) -> x[1] * p[1]; is_autonomous=true)
B = Poisson(F, G)
```

```@example poisson
B([1.0, 2.0], [0.5, 1.0])
```

Because the result is again a `Hamiltonian`, Poisson brackets nest:

```@example poisson
Poisson(Poisson(F, G), G)([1.0, 2.0], [0.5, 1.0])
```

## Connection with the Lie bracket

The Hamiltonian lift (see [Hamiltonian lift](lift.md)) intertwines the Lie bracket of
vector fields with the Poisson bracket of their lifts. With the sign conventions used in
this package,

```math
\{H_X, H_Y\} = H_{[X, Y]}, \qquad H_X(x,p) = p^\top X(x).
```

Verified numerically:

```@example poisson
X = VectorField(x -> [x[2], 2x[1]]; is_autonomous=true)
Y = VectorField(x -> [3x[2], -x[1]]; is_autonomous=true)
x0, p0 = [1.0, 2.0], [0.5, 1.0]

lhs = Poisson(Lift(X), Lift(Y))(x0, p0)   # {H_X, H_Y}
rhs = Lift(ad(X, Y))(x0, p0)              # H_[X,Y]
lhs ≈ rhs
```

## See also

- [`Poisson`](@ref CTLie.Poisson) — full docstring and method list.
- [The `@Lie` macro](lie_macro.md) — write `@Lie {H, G}` instead of `Poisson(H, G)`.
- [Hamiltonian lift](lift.md) and [Lie derivative & bracket](lie_derivative_bracket.md).
