# progen — Program Synthesis via HVM4 Superpositions

HVM4 gives you non-deterministic search for free. A superposition `&L{a, b}`
represents "either a or b simultaneously." Combined with short-circuit AND
(`.&.`) for pruning and the collapser (`-C`) for enumeration, you get a
zero-overhead program synthesizer where the search engine *is* the evaluator.

## The key insight

Most synthesis frameworks are built in two layers: a **search algorithm**
(backtracking, DPLL, MCMC) layered on top of a **language interpreter**. In
HVM4, these layers collapse into one. A superposition of programs, applied to
a test input, *is* all those programs running simultaneously. The short-circuit
AND prunes branches the moment any constraint fails — no interpretation overhead,
no embedding gap.

## The oracle problem and its fix

The naive approach fails: if two sub-expressions reference the same superposition
`@e`, the collapser forces them to make the **same branch choice** everywhere
`@e` appears. `@e + @e` can only produce `p+p`, never `p+q` for different
programs `p` and `q`.

The fix: assign each **tree slot** its own unique label family. Since HVM4
collapses labels globally, disjoint labels collapse independently. With N leaf
positions you need N distinct terminal sets, each using 4 unique labels for the
5-element `{x, 0, 1, 2, 3}` alphabet.

## Files

| File | What it synthesizes | Target |
|------|---------------------|--------|
| `arith_synth.hvm` | Arithmetic expressions over `x` | `x*(x+1)` from spec `f(0)=0, f(1)=2, f(2)=6` |
| `two_var_synth.hvm` | Arithmetic expressions over `a, b` | `a+b` from 4 I/O examples |
| `nat_synth.hvm` | Predicates over Peano naturals | `IsEven` from 5 positive/negative examples |

## Running

Requires HVM4-official: `~/work/HVM4-official/clang/main`

```bash
# Synthesize arithmetic programs (finds x*(x+1), x*x+x, etc.)
~/work/HVM4-official/clang/main arith_synth.hvm -C30 -s

# Synthesize two-variable programs (finds a+b)
~/work/HVM4-official/clang/main two_var_synth.hvm -C10 -s

# Synthesize Nat predicates (finds IsEven, Not{IsOdd}, etc.)
~/work/HVM4-official/clang/main nat_synth.hvm -C10 -s
```

Flags: `-C N` collapses superpositions, printing up to N results. `-s` shows stats.

## Sample output

```
# arith_synth.hvm -C6
#Add{#Var{},#Mul{#Var{},#Var{}}}     ← x + x²  = x(x+1)
#Add{#Mul{#Var{},#Var{}},#Var{}}     ← x² + x  = x(x+1)
#Mul{#Var{},#Add{#Var{},#Num{1}}}    ← x*(x+1)
#Mul{#Var{},#Add{#Num{1},#Var{}}}    ← x*(1+x)
#Mul{#Add{#Var{},#Num{1}},#Var{}}    ← (x+1)*x
#Mul{#Add{#Num{1},#Var{}},#Var{}}    ← (1+x)*x

# nat_synth.hvm -C4
#IsEven{}
#Not{#IsOdd{}}
#And{#Always{},#IsEven{}}
#And{#IsEven{},#Always{}}
```

## How it works

### The search space

Each synthesizer defines expression trees as ADTs with disjoint label families:

```hvm
// 7 terminal slots, each with unique labels
@v0 = &a0{#Var{}, &a1{#Num{0}, &a2{#Num{1}, &a3{#Num{2}, #Num{3}}}}}
@v1 = &b0{#Var{}, &b1{#Num{0}, &b2{#Num{1}, &b3{#Num{2}, #Num{3}}}}}
// ...

// Depth-1 sub-trees (disjoint: @e1L uses v1/v2/v3, @e1R uses v4/v5/v6)
@e1L = &h0{ @v1, &h1{ #Add{@v2, @v3}, #Mul{@v2, @v3} } }
@e1R = &h2{ @v4, &h3{ #Add{@v5, @v6}, #Mul{@v5, @v6} } }

// Depth-2 top level
@e2  = &h4{ @v0, &h5{ #Add{@e1L, @e1R}, #Mul{@e1L, @e1R} } }
```

### The spec check

Short-circuit AND prunes failing branches the moment any constraint fails.
The dup `!e&Z = @e2` distributes through all internal superpositions via
DUP-SUP commutation, giving `e₀` and `e₁` as independent copies with the
same label structure. When the spec collapses a label in `e₀`, DUP-SUP
annihilation ensures `e₁` returns the corresponding branch.

```hvm
@spec = λe.
  !e1&U = e; !e2&V = e1₁;
  ((@eval(e1₀, 0) == 0) .&.         // prunes ~80% at first check
   ((@eval(e2₀, 1) == 2) .&.        // prunes most survivors
    (@eval(e2₁, 2) == 6)))           // few remain → solutions

@main =
  !e&Z = @e2;
  @if(@spec(e₀), e₁, &{})
```

### Scaling the grammar

To add depth-3 support, define `@e2L` and `@e2R` from `@e1L`/`@e1R` variants
with distinct label families, then extend `@e3` similarly. The label count
grows as O(2^depth × terminals), but each synthesis runs in parallel within
HVM4's optimal reduction engine.

## Extensions

- **Add subtraction/division**: extend the eval match arms and add #Sub/#Div ctors
- **String programs**: replace `#Num` with `#Chr` literals; add `#Cat`, `#Len` ops
- **Regex synthesis**: define a regex ADT; spec = positive/negative example strings
- **Type inference**: represent unknown types as superpositions; collapse to valid typings
- **SAT/constraint solving**: encode variables as `&L{0, 1}` bits; constraints as `.&.` chains
