#!/bin/bash
# Run all synthesizers and show output
HVM="${HVM:-$HOME/work/HVM4-official/clang/main}"

if [ ! -x "$HVM" ]; then
  echo "HVM4 binary not found at $HVM"
  echo "Set HVM= to the path of your HVM4-official/clang/main binary"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Arithmetic Expression Synthesizer ==="
echo "Spec: f(0)=0, f(1)=2, f(2)=6"
echo "Grammar: x | 0 | 1 | 2 | 3 | Expr+Expr | Expr*Expr (depth 2)"
echo ""
"$HVM" "$DIR/arith_synth.hvm" -C6 -s
echo ""

echo "=== Two-Variable Synthesizer ==="
echo "Spec: f(0,1)=1  f(1,0)=1  f(2,3)=5  f(1,2)=3"
echo "Grammar: a | b | 0 | 1 | Expr+Expr | Expr*Expr (depth 2)"
echo ""
"$HVM" "$DIR/two_var_synth.hvm" -C4 -s
echo ""

echo "=== Nat Predicate Synthesizer ==="
echo "Spec: f(0)=T f(1)=F f(2)=T f(3)=F f(4)=T"
echo "Grammar: Always | Never | IsZero | IsEven | IsOdd | Not | And | Or (depth 2)"
echo ""
"$HVM" "$DIR/nat_synth.hvm" -C4 -s
