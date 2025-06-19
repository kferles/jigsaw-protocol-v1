---
title: "[V] Language Description"
sidebar_position: 3
---

[V] is a declarative language for writing correctness specifications. Any [V] specification contains several distinct sections -- some required, some optional, and some that are mutually exclusive. This document describes these sections, detailing their purpose and syntax.

## Overview of Sections

[V] specifications contain the following sections:

```solidity
vars: <declarations>
(hints: <statements>)?
(fair: <statements>)?
((spec: <ltl_formula>) | (inv: <condition>))
```

The `vars` section is required, and is used to declare free variables in the specification. The `hints` and `fair` sections are both optional. The `hints` section is used to restrict the search space of transaction parameter values. The `fair` section is used to direct the search space of transaction sequences. Exactly _one_ of the `spec` and `inv` section is required. The `spec` section is used to describe a property of the source code that should be checked. The `inv` section is used to describe invariants, a specific type of property.


## `vars` Section

```solidity
vars: <varType> <varName>, <varType> <varName>, ...
```

The `vars` section contains all variable declarations for the specification. Most often, this include contract variable declarations of the form `ContractName varName`, but can also include other variables used in the spec.

Any variable declared in the `vars` section is considered a free variable, meaning that the specification does not hold if _any_ assignment to the variable falsifies the spec.

Besides contract types, the following are accepted as variable types in the `vars` section:
* `address`
* `string`
* `bool`
* `uint8-uint256` and `int8-int256`. `uint` and `int` are equivalent to their 256-bit counterparts.
* `bytes`
* `bytes1-bytes32`
* Struct types `Contract.StructType`
* Enum types `Contract.EnumType`
* Array types `<type>[]`, `<type>[][]`, etc.
* Bounded array types `<type>[<uint>]`, `<type>[<uint>][<uint>]`, etc.
* Tuple types `(<type>, <type>)`, `(<type>,<type>,<type>)`, etc.


## `spec` Section

```solidity
spec: []!finished(<target>, <condition>) ...
```

The `spec` section contains an LTL formula over [V] statements that describes some property of the source code. This section provides a high-level overview of the syntax of the `spec` section. Other documents discuss [[V] Statements](v_statements.md) and [LTL formulae](temporal_specifications.md) in more detail.

### LTL Formulae

OrCa works by checking the validity of the LTL formula provided in the `spec` section. We say that the formula is valid when the formula is true for (1) any possible assignment of the free variables declared in the `vars` section and (2) any possible sequence of transactions issued over the contracts in scope. When OrCa finds a set of assignments for free variables and a transaction sequence that falsified the provided formula, OrCa reports this transaction sequence as a "counterexample" to the specification.

The LTL formulae permissible in the `spec` section is described by the following grammar:

```solidity
L :   S
    | (L)
    | <> L
    | X L
    | ! L
    | [] L
    | L U L
    | L R L
    | L ; L
    | L && L
    | L || L
    | L ==> L
```

`S` in the grammar represents a [V] statement. [V] statements make up the atoms of the LTL formula within a [V] spec. [V] statements are evaluated in the context of a single transaction, as described in the next subsection. The LTL formula `S` (composed of a single [V] statement) is true for an event sequence if `S` evaluates to true over the first transaction in the event sequence.

The boolean operators `||` ("or"), `&&` ("and"), and `!` ("not") have their usual meaning. For an in-depth explanation on the semantics of temporal operators `<>`, `X`, `[]`, `U`, `R`, and `;`, see [Temporal Specifications](temporal_specifications.md).


In general, LTL formula are evaluated over infinite sequeces of events. In the context of blockchain applications, each of these events has an associated blockchain state. There are two ways that OrCa interprets a finite sequence of transactions as an infinite sequence of events to evaluate an LTL formula over:
1. Each transaction is translated into two sequential events: one event where the transaction is started, and one where the transaction is completed (or reverted if the transaction errored). The associated blockchain state of the transaction started event is the state _before_ the transaction is issued, while the state for the completed/finished/reverted event is the state _after_ the transaction is issued.
2. The event sequence is extended infinitely with null-events $\epsilon$ such that any [V] statement `S` evaluates to false over any null-event $\epsilon$.

### [V] Statements

[V] statements make up the atoms of the LTL formula within a [V] spec. The following grammar describes the syntax of a [V] statement:

```solidity
S : F(T, E)

F :   started
    | reverted
    | executed
    | finished

T :   I.I(I, ...)
    | I.I
    | I.*
    | *
```

`F` represents the type of statement, `T` represents the target of the statement, and `E` represents the conditional expression. `I` represents any identifier. Conditional expressions must evaluate to a boolean value. [[V] statements](./v_statements.md) describes the expressions allowed for statement conditions in further detail.

A [V] statement `F(T, E)` is evaluated over a particular point in the event sequence. Specifically, `F(T, E)` holds for a particular event iff the following conditions hold:

<ol type="1">
  <li>The event type matches <code>F</code>.</li>
  <ol type="a">
    <li><code>started</code> matches any transaction start event</li>
    <li><code>finished</code> matches any transaction completion event where the transaction was successfully executed</li>
    <li><code>reverted</code> matches any transaction completion event where the transaction was unsuccessfully executed (i.e. reverted)</li>
    <li><code>executed</code> matches any transaction completion event</li>
  </ol>

  <li>The pertinent transaction matches <code>T</code></li>
  <ol type="a">
    <li><code>c.txn(...)</code> and <code>c.txn</code> match the transaction <code>txn</code> over the contract instance <code>c</code></li>
    <li><code>c.*</code> matches any transaction over the contract instance <code>c</code></li>
    <li><code>*</code> matches any transaction</li>
  </ol>
  <li>The condition <code>E</code> holds over the associated blockchain state.</li>
</ol>

## `inv` Section

```solidity
inv: <condition>
```

The `inv` section is shorthand for a set of commonly-expressed specifications. Specifically, the `inv` section allows users to express _invariants_ over the space of in-scope contracts. The invariant `expr` holds when `expr` is true after issuing any transaction.

There are two forms for the `inv` section:
1. `inv: expr`
2. `inv: expr over target`

The invariant `expr over target` holds iff `expr` holds after issuing any transaction that matches `target`. Note that the first form `inv: expr` is equivalent to `inv: expr over *`. For example, to express an invariant over one specific contract `Contract`, use the following [V] specification:
```solidity
vars: Contract c
inv: <cond> over c.*
```

The invariant section `inv: expr over target` is equivalent to the following `spec` section:
```solidity
spec: []!finished(target, !expr)
```

## `hints` Section

```solidity
hints: finished(<target>, <hint-program>) ; finished(<target>, <hint-program>) ; ...
```

The hints section contains a sequence of special `finished` statements. Note that the sequence is not ending with a `;`, but `;` is required between each `finished` statement. These finished statements make up distinct hints.

Each hint contains both a `target` and a `hint-program`. The meaning of hint `finished(target, hint-program)` is that transaction `target` should be issued with transaction arguments (and `sender` and `value` values) based on the assignments in `hint-program`.

The target, like any [V] statement, may take the following forms:

1. `contractVar.function(arg1, arg2, ...)`
2. `contractVar.function`
3. `contractVar.*`
4. `*`

Since hints are used to constrain the arguments of transactions, nearly all hints will use the first form of the target (though hints that constrain the transaction `sender` or `value` may use the alternate forms).

The hint program must consist of any sequence of assignment expressions or for-all blocks separated by semicolon (`;`). Expressions inside the for-all block can be described as another hint program, so it may contain any sequence of assignment expressions or for-all blocks.

The assignment expression `<LHS> := <RHS>` must satisfy a few properties:

* `<LHS>` must be either a transaction argument, tuple of transaction arguments, an array access on an argument, a field access on an argument, or the keyword `sender` or `value`
* `<RHS>` must be an expression that evaluates to the type of `<LHS>`, or a `solve` expression that has returns the same type as `<LHS>`. For details on `solve`, please refer to [here](./by_example/hints.md#general-solve-syntax-and-behavior).

For a hint like `finished(c.foo(arg1, arg2))`, `arg1`, `arg1.field`, `arg1[0]`, `(arg1, arg2)` can be candidates for `<LHS>`.

For-all expressions can define hints on arrays. To modify each element of an array `arr` with its index value, use a hint like below:

```solidity
finished(c.foo(arr), forall{i : range(0, len(arr))}(arr[i] := i))
```

For right hand side values `<RHS>`, you can provide [V] expressions which will be interpreted when the hint is being executed. As an example, the hint below describes that the argument `sum` will be equal to the sum of the first two arguments:

```solidity
finished(c.checksum(arg1, arg2, sum), sum := arg1 + arg2)
```

### Useful Functions for Expressing Hints

[V] has a series of utility functions used to express hint constraints or assignments, here is the list below.

#### `user_address() -> address`

Return a random address among non-contract addresses in the Anvil state (contains default Anvil user addresses and addresses used for deployment).

#### `address(val) -> address`

Return the converted value `val` as an address. `val` can be an integer, or a hex string, so `address(0)` or `address("0xdeadbeef")` are valid uses of this function. In Solidity, addresses are 20-byte long, so this function converts any integer or shorter hex-string to a 20-byte representation. If the passed address is longer than maximum possible address value, OrCa will crash with a value error.

#### `elem_in_range(int low, int high) -> int`

Return a random integer in the range of `[low, high)`.

In the example below, the argument `percent` is assigned a random value from 0 to 100.

```solidity
finished(
  c.foo(percent),
  percent := elem_in_range(0, 101)
)
```

#### `len(arr) -> int`

Return the length of the array `arr` as an integer.

#### `range(int low, int high) -> list[int]`

Return a sorted array consisting of `low, low + 1, low + 2, ..., high-1`.

This function and `len` function can be used to iterate over an array in hints such as the hint below. In the example below, each cell of the array is assigned to its index value.

```solidity
finished(
  c.foo(arr), 
  forall{i: range(0, len(arr))}(arr[i] := i)
)
```

#### `ecdsa256_sign_bytes(address signer, bytes msg) -> bytes`

Return the signature based on the bytes string `msg` and the address `signer` as a 65-byte bytes string.

Below is an example of a cryptographic hint where `transferCheckSignature` function requires the address `from` to be equal to the signer of the `signature` argument and different from the null address. `HashMsg` function is only a wrapper for the [keccak256 function](https://docs.soliditylang.org/en/latest/units-and-global-variables.html#mathematical-and-cryptographic-functions).

```solidity
// Simple hashing function (uses keccak only)
function hashMsg(bytes memory my_msg) public pure returns (bytes32) {
    return keccak256(my_msg);
}

function transferCheckSignature(
    address from,
    bytes memory signature,
    address to,
    uint256 amount
) public {
    // Require that the signer was the `from` address
    (uint8 v, bytes32 r, bytes32 s) = get_vrs(signature);
    address signer = ecrecover(hashMsg(signature), v, r, s);
    require(signer != address(0));
    require(signer == from);
    // NOTE: Should transfer from the `from` address, not message sender!
    transfer(to, amount);
}
```

The hint to pass the require statements, described below, assigns `from` to a random user address using `user_address()` function and replaces the signature with a message containing the address `to`, signed by address `from` using `ecdsa256_sign_bytes`.

```solidity
vars: MyVToken token
hints: finished(token.transferCheckSignature(from, sig, to, amt),
                from := user_address();
                sig := ecdsa256_sign_bytes(from, token.toBytes(to)))
```

#### `ecdsa256_sign(address signer, bytes msg) -> (uint8, bytes32, bytes32)`

Return the signature based on the bytes string `msg` and the address `signer` as a `(uint8, bytes32, bytes32)` tuple.

## `fair` Section

The `fair` section allows users to specify a temporal property that should be assumed by OrCa, similar to temporal properties defined in [V] spec section. This section _must_ appear before the `spec` section in the specification:

```solidity
fair: prop1
spec: prop2
```

For this example specification, OrCa will only report counterexamples that both (a) satisfy the fairness property `prop1` and (b) violate the correctness property `prop2`.[^1] See documentation on [fairness assumptions](fairness_assumptions.md) for more details on the `fair` section.

[^1]: Currently, OrCa only uses the fairness property as a precondition for reporting counterexamples. Future versions of OrCa may direct the search to test only sequences that satisfy the fairness property.
