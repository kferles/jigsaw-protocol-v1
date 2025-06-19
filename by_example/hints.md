---
title: Guiding the Search
sidebar_position: 4
---

This section introduces the `hints` section as a tool [V] developers can use in order to help guide
the search for counterexamples against the input specification.

## Intro to Hints: A Small Example

Hints are used to guide the fuzzer's search. If the fuzzed transaction has a require statement or satisfying the spec requires a specific contract state, random fuzzing will not help without spending excessive time. In those cases, the users can provide hints to improve the quality of fuzzing.

Some ways hints can guide fuzzing include:

* Providing values to the transaction arguments
* Providing values to the sender/value fields of a transaction
* Providing constraints over transaction arguments or contract variables.

Below, we have an example function:

```solidity
function foo(uint256 x, uint256 y) public onlyOwner {
    require(x > 100000);
    require(y < x);

    ...
}
```

In this function, there are three constraints that are difficult to randomly satisfy.

* `x` must be greater than 100000.
* `y` must be less than `x`.
* `onlyOwner` limits valid callers to only the contract owner.

To pass these checks, the users can write [V] hints in the form of `finished(<target>, <hint-program>)` where target function's arguments or sender/value fields will be modified based on the hint program. The hint program is a sequence of assignments or for-all expressions containing other hint programs to modify the arguments.

An example for the function `foo` is given below.

```solidity
vars: Contract c
hints: finished(c.foo(x, y),
                    x := elem_in_range(100001, MAX_UINT256); 
                    y := elem_in_range(0, x);
                    sender := c.owner
               )
spec: ...
```

The hint above has three assignments to make it run successfully.

* `x` is assigned a random value between 100001 and MAX_UINT256 to satisfy `require(x > 100000)`.
* `y` is assigned a random value between 0 and `x` to satisfy `require(y < x)`.
* `sender` is assigned to contract's owner to satisfy the `onlyOwner` requirement.

Another way to write this hint would be to use `solve` expressions. This method invokes an SMT solver, so it is going to be slower to run but for complex cases, it might be useful. In the `solve` expressions, users can express constraints in [V]. The constraints are solved by an SMT solver and the expression returns the values to be used in assignment.

For example, the hint above can also be expressed as:

```solidity
vars: Contract c
hints: finished(c.foo(x, y),
                    (x, y) := solve{uint256 a, uint256 b}(a > 100000 && b < a);
                    sender := c.owner
               )
spec: ...
```

In the hint above, `solve` block calls SMT solver to find a satisfying solution to the provided constraint in the `solve` block, and returns `a` and `b` values satisfying the provided constraint as a tuple for assignment to the left hand side.

## Now You're Thinking with Portals: Enhancing Hints with Complex Expressions

As seen in the previous section, hints can be constructed as series of assignments with or without using `solve` blocks to pass requirements in transactions. For some complex require statements (on arrays or structs), users will need to use `solve` blocks or `forall` expressions to be able to express their constraints.

Below, we have an example function comparing two lists:

```solidity
function countVotes(address[] voters, uint256[] votes) public {
    # Require a non-empty voters and votes list
    require(voters.length == votes.length && voters.length > 0);

    # Only accepting votes for 4 candidates (1, 2, 3, 4)
    for(uint i=0; i<votes.length; i++){
        require(votes[i] < 5 && votes[i] > 0);
    }
    ...
}
```

For these two require statements, we can write a [V] hint like below:

```solidity
vars: Contract c
hints: finished(c.count_votes(voters, votes),
                    (voters, votes) := solve{address[] _voters, uint256[] _votes}(
                                            len(_voters) = len(_votes) && len(_voters) > 0);
                    forall{i : range(0, len(votes))}(votes[i] := elem_in_range(1, 5))
               )
spec: ...
```

These two expressions modify `voters` and `votes` to be able to pass the requirements:

* The first expression solves a constraint on `_voters` and `_votes` to make them equal-length and non-empty, then assigns those lists to `voters` and `votes` respectively.
* The second assignment modifies each element of the `votes` to be within the values 1-4.

In this example, calling `solve` lets us randomly generate 2 arrays with equal length which we could not do in [V]. If we did not use `solve` to write the hint, we could have fixed the length of both arrays with an expression like `votes := [elem_in_range(1, 5), elem_in_range(1, 5)]`. That would have been faster but that would also limit the possible values to fuzz for that function to a small subset.

## General Hint Syntax

The hint grammar can be described as below:

```solidity
HintSequence :   Hint
               | Hint ; HintSequence

Hint: finished(Target, HintProgram)

HintProgram :   LHSExpr := Expr
              | forall(I : I)(HintProgram)
              | HintProgram ; HintProgram

Target :   I.I(I, ...)
         | I.I
         | I.*
         | *

LHSExpr :   I
          | LHSExpr.I
          | LHSExpr[I]
          | (LHSExpr, ...)

Expr :   SolveExpr 
       | ConstraintExpr
```

`HintSequence` represents a single hint or a sequence of hints, separated by a semicolon `;`. `Hint` represents a single hint description with `Target` describing the function to match on and `HintProgram` describing the sequence of assignments to perform to modify the functions.
`Target` represents the target of the statement, similar to the definition in [[V] statements](../language_description.md#v-statements).

`HintProgram` represents a hint program, consisting of an assignment expression, a for all block containing a hint program, or a sequence of hint programs. `LHSExpr` represents any identifier, field access, array access, or tuple containing any of the previous expressions where each element has to match an argument of `Target`, `sender`, or `value`. `I` represents any identifier. `Expr` represents a solve expression (explained in the next chapter) or a constraint expression and it needs to return the type of `LHSExpr` when evaluated.

## General Solve Syntax and Behavior

To increase the expressibility of hints, `solve` expressions let users call an SMT solver and get a solution for their arguments. The `solve` expression can be described as the following:

```solidity
SolveExpr: solve{SMTVarDecl}(ConstraintExpr)

SMTVarDecl:   VarType VarName
            | SMTVarDecl, SMTVarDecl

VarType:   address 
         | string
         | bool
         | uint # Behaves same as uint256
         | uint<num> # uint8, uint16, ..., uint256 are allowed
         | int256 # Behaves same as int256
         | int<num>  # int8, int16, ..., int256 are allowed
         | bytes<num> # Only bounded byte variables are allowed
         | VarType[] # Array types

VarName: <str>
```

`SolveExpr` describes the expression which returns the concrete values to variables in `SMTVarDecl` based on the constraints in `ConstraintExpr`. `SMTVarDecl` lets users create undefined variables which *only* appear in the `ConstraintExpr`, similar to the free variables defined in [`vars` section](../language_description.md#vars-section) but only limited to primitive types and arrays described in `VarType`. `ConstraintExpr` is a [V] expression which will be translated into SMTLIB to be solved.

There are two main differences between `ConstraintExpr` in solve blocks and [V] constraints:

* For binary expressions, only primitive types (`address`, `bytes`, `bool`, `uint`, `int`, `string`) are allowed. `x = 1` is a valid expression, `x = [1, 2, 3]` is an invalid expression. For modifying array, struct, and enum variables, the users can express assignments in hints such as `x := [1, 2, 3]`, `x[0] := ...`, or `x.field := ...`.
* For binary expressions on bytes, the lengths of left hand side and right hand side expressions have to match exactly. For example, `x = b"00cafe00"` is valid only when `x` is of type `bytes4`, otherwise solver translation returns a type error.

As a warning, there may be some limitations in terms of the constraints OrCa can solve as SMT solvers (like Z3) may have difficulty providing solutions in a short amount of time where the constraints contain nested arrays or complex mathematical expressions like quadratics. If the solver times out or constraints have a type mismatch, OrCa will terminate to warn the user not to provide such constraints.

## See Also

For more details on [V] hints and hint functions, please refer to [Hint Description](../language_description.md#hints-section) and [Useful Hint Functions](../language_description.md#useful-functions-for-expressing-hints).
