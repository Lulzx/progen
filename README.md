# progen

Program synthesis using HVM4 superpositions. Represents all programs in the grammar simultaneously as a superposition, evaluates against I/O examples using short-circuit AND for pruning, and collapses to satisfying programs.

Three synthesizers:

| File | Grammar | Spec | Solution |
|---|---|---|---|
| `arith_synth.hvm` | `x\|0\|1\|2\|3\|e+e\|e*e` depth 2 | f(0)=0 f(1)=2 f(2)=6 f(3)=12 | `x*(x+1)` |
| `two_var_synth.hvm` | `a\|b\|0\|1\|e+e\|e*e` depth 2 | f(0,1)=1 f(1,0)=1 f(2,3)=5 f(1,2)=3 | `a+b` |
| `nat_synth.hvm` | predicates over Peano nats depth 2 | f(0)=T f(1)=F f(2)=T f(3)=F f(4)=T | `IsEven` |

## Usage

Requires [HVM4](https://github.com/HigherOrderCO/HVM4):

```
./clang/main arith_synth.hvm -C30 -s
./clang/main two_var_synth.hvm -C10 -s
./clang/main nat_synth.hvm -C10 -s
```

Or `HVM=path/to/clang/main ./run.sh`.

## Code generator

`gen.py` emits synthesizers for arbitrary depth and spec:

```
python gen.py --depth 3 | ./clang/main /dev/stdin -C20 -s
python gen.py --depth 3 --sort-spec | ./clang/main /dev/stdin -C20 -s
python gen.py --depth 3 --grammar twov --spec "0,1:1,1,0:1,2,3:5"
```

Flags:
- `--depth N` — expression tree depth (default: 2)
- `--spec X:Y,...` — comma-separated input:output examples
- `--grammar arith|twov` — terminal/operator set
- `--sort-spec` — check most-discriminating examples first (~8% fewer interactions)

## Depth scaling (arith grammar, `--sort-spec`)

Interaction count plateaus from depth 6 onward — pruning kills new branches before evaluation:

| depth | labels needed | interactions | time |
|-------|--------------|-------------|------|
| 2 | 37 | ~3K | <1ms |
| 3 | 77 | 15K | <1ms |
| 4 | 157 | 218K | 2ms |
| 5 | 317 | 297K | 5ms |
| 6 | 637 | 349K | 3ms |
| 7 | 1277 | 355K | 3ms |
| 8 | 2557 | 353K | 3ms |

Depth 8 is the hard ceiling: HVM4 encodes labels as ≤16-bit values (2 base64 chars = 4096 max), and depth 9 would require 5117 unique labels.

## How it works

Each tree slot gets its own label family so independent sub-expressions collapse independently (shared labels would collapse to the same branch — the oracle problem). The dup `!e&Z = @grammar` commutes through all internal superpositions via DUP-SUP, giving two complete copies: one for spec checking, one to return.

```hvm
@spec = λe.
  !e1&U = e; !e2&V = e1₁; !e3&W = e2₁;
  ((@eval(e1₀, 0) == 0) .&.
   ((@eval(e2₀, 1) == 2) .&.
    ((@eval(e3₀, 2) == 6) .&.
     (@eval(e3₁, 3) == 12))))

@main = !e&Z = @e2; @if(@spec(e₀), e₁, &{})
```
