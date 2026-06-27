# The `@Lie` macro

```@meta
CurrentModule = CTLie
```

The macro [`@Lie`](@ref CTLie.@Lie) is a thin, readable front end
over [`ad`](@ref CTLie.ad) and [`Poisson`](@ref
CTLie.Poisson). It uses bracket notation that mirrors the
mathematics:

- **square brackets** `[X, Y]` denote a **Lie bracket** of vector fields;
- **curly braces** `{H, G}` denote a **Poisson bracket** of Hamiltonians.

Brackets may be nested and combined with ordinary arithmetic. Operands may be plain
`Function`s or typed objects. Evaluation points — including 2-element vector literals such
as `[1.0, 2.0]` — may appear directly inside the macro expression.

```@setup liemacro
using CTLie
import CTBase            # @Lie expands to CTBase.Traits.* — CTBase must be in scope
using CTBase.Data
using CTBase.Traits
import DifferentiationInterface
```

## Lie and Poisson brackets

```@example liemacro
X = VectorField(x -> [x[2], 2x[1]]; is_autonomous=true)
Y = VectorField(x -> [3x[2], -x[1]]; is_autonomous=true)
(@Lie [X, Y])([1.0, 2.0])
```

```@example liemacro
F = Hamiltonian((x, p) -> p[1]^2 / 2 + x[1]^2; is_autonomous=true)
G = Hamiltonian((x, p) -> x[1] * p[1]; is_autonomous=true)
(@Lie {F, G})([1.0, 2.0], [0.5, 1.0])
```

The macro returns exactly what the underlying function returns — a typed
[`VectorField`](@extref CTBase CTBase.Data.VectorField) for `[…]`, a typed
[`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) for `{…}`:

```@example liemacro
(@Lie [X, Y]) isa VectorField, (@Lie {F, G}) isa Hamiltonian
```

## Nested brackets

```@example liemacro
(@Lie [[X, Y], Y])([1.0, 2.0])
```

```@example liemacro
(@Lie {{F, G}, G})([1.0, 2.0], [0.5, 1.0])
```

## Evaluation at literal points

Vector literals can appear directly as arguments inside a `@Lie` expression. The macro
resolves the ambiguity at **runtime** through dispatch: if the two elements of a `[a, b]`
are not field-like objects, the macro reconstructs the vector as data and applies it.

```@example liemacro
@Lie [X, Y]([1.0, 2.0])
```

```@example liemacro
H0 = Hamiltonian((x, p) -> 0.5*(2x[1]^2 + x[2]^2 + p[1]^2); is_autonomous=true)
H1 = Hamiltonian((x, p) -> 0.5*(3x[1]^2 + x[2]^2 + p[2]^2); is_autonomous=true)
@Lie {H0, H1}([1.0, 2.0], [2.0, 1.0])
```

## Arithmetic on bracket values

Brackets can be evaluated and combined inside a single `@Lie` expression. With the
Bloch-equation fields

```@example liemacro
F0 = VectorField(x -> [-2x[1], -2x[2], 1 - x[3]]; is_autonomous=true)
F1 = VectorField(x -> [0.0, -x[3], x[2]];         is_autonomous=true)
F2 = VectorField(x -> [x[3], 0.0, -x[1]];         is_autonomous=true)
x3 = [1.0, 2.0, 3.0]
nothing # hide
```

we have ``[F_0,F_1](x_3) = (0,-4,-2)`` and ``[F_1,F_2](x_3) = (2,-1,0)``, so

```@example liemacro
@Lie [F0, F1](x3) + 4 * [F1, F2](x3)
```

The same works for Poisson brackets:

```@example liemacro
H2 = Hamiltonian((x, p) -> 0.5*(4x[1]^2 + x[2]^2 + p[1]^3 + p[2]^2); is_autonomous=true)
@Lie {H0, H1}([1.0, 2.0], [2.0, 1.0]) - {H1, H2}([1.0, 2.0], [2.0, 1.0])
```

!!! warning "Trailing keywords bind to `@Lie`"

    A macro greedily consumes the `keyword=value` arguments that follow it. So in
    `@Lie [F, G](x) ≈ v atol=1e-6`, the `atol=1e-6` is handed to `@Lie` (and rejected),
    not to `≈`. Wrap the bracket expression in parentheses to scope the macro:

    ```julia
    (@Lie [F, G](x)) ≈ v atol=1e-6   # atol now belongs to the comparison
    ```

## Plain functions and trait keywords

The operands may be plain `Function`s. As elsewhere, a bare function is assumed
autonomous and fixed; use the keyword flags `is_autonomous` and `is_variable` to say
otherwise. They are passed **after** the bracket expression:

```@example liemacro
f = x -> [x[2], 2x[1]]
g = x -> [3x[2], -x[1]]
(@Lie [f, g])([1.0, 2.0])             # autonomous by default
```

```@example liemacro
ft = (t, x) -> [t + x[2], -2x[1]]
gt = (t, x) -> [t + 3x[2], -x[1]]
(@Lie [ft, gt] is_autonomous=false)(1.0, [1.0, 2.0])
```

```@example liemacro
fv = (x, v) -> [x[2] + v, 2x[1]]
gv = (x, v) -> [3x[2], v - x[1]]
(@Lie [fv, gv] is_variable=true)([1.0, 2.0], 1.0)
```

A third keyword, `ad_backend`, selects the AD backend for this call only (see
[Limitations & configuration](limitations.md)).

When operands are **typed**, their traits are read directly and no keyword is needed —
indeed, a keyword that contradicts the operands' traits is an error (next section).

## Error cases

The macro validates its input and raises
[`CTBase.Exceptions.IncorrectArgument`](@extref CTBase) in the following situations. These
snippets are **not executed** (they would throw):

**Wrong bracket kind for a typed operand.** Using a
[`Hamiltonian`](@extref CTBase CTBase.Data.Hamiltonian) inside `[...]` (Lie bracket) or a
[`VectorField`](@extref CTBase CTBase.Data.VectorField) inside `{...}` (Poisson bracket) is
detected at runtime and raises an error:

```julia
H = Hamiltonian((x, p) -> p[1]*x[1])
F = VectorField(x -> [x[2], -x[1]])

@Lie [H, F]    # ❌ Hamiltonian is not a valid Lie bracket operand
@Lie [F, H]    # ❌ same
@Lie {F, H}    # ❌ VectorField is not a valid Poisson bracket operand
@Lie {H, F}    # ❌ same
```

**An unknown keyword argument:**

```julia
@Lie [F, G] invalid_arg=true   # ❌ unknown @Lie argument
```

**A keyword that conflicts with typed operands, or operands whose traits disagree:**

```julia
Xa = VectorField(x -> [x[2], -x[1]];      is_autonomous=true)
Xt = VectorField((t, x) -> [x[2], -x[1]]; is_autonomous=false)

@Lie [Xa, Xt]                        # ❌ time-dependence mismatch between operands
@Lie [Xa, Xa] is_autonomous=false    # ❌ flag conflicts with operand traits
```

## How the macro works

`@Lie` is a macro-time rewrite: every `[a, b]` in the expression is replaced by a call to
the runtime worker `_lie_mac(a, b, …)`, and every `{c, d}` by `_poisson_mac(c, d, …)`.
The bracket kind and the trait arguments are baked in at expansion time. Whether `[a, b]`
is a genuine Lie bracket or a data vector is resolved at **runtime** through multiple
dispatch:

- Both operands are field-like (`Function` or `AbstractVectorField`) → Lie bracket.
- Either operand is an `AbstractHamiltonian` → `IncorrectArgument`.
- Otherwise → the two values are reassembled as `[a, b]` (data vector).

This means the macro is **not type-stable** when it encounters a data vector `[a, b]`:
the return type depends on the runtime values of `a` and `b`. When both operands are
known to be field-like (e.g. typed `VectorField` objects), the macro is type-stable.

## See also

- [`@Lie`](@ref CTLie.@Lie) — full docstring.
- [`ad`](@ref CTLie.ad) and [`Poisson`](@ref
  CTLie.Poisson) — the functions the macro expands to.
- [Limitations & configuration](limitations.md) — trait matching, backends, prefixes.
