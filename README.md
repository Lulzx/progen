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
