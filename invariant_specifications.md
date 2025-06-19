---
title: Invariant Specifications
sidebar_position: 7
---

Invariant specifications enable a user to check properties that should always hold. Invariants are declared in a special section of the [V] specification, marked by the `inv` tag (short for "invariant"). The invariant section itself contains a single [V] expression, written as follows:

```solidity
inv: constraint
```

Semantically, an invariant specification is violated whenever the constraint is violated after executing _any_ transaction.


### Specifying a Target

In some cases, users may wish to specify an invariant over a single contract or single transaction. This can be done with the following syntax:

```solidity
inv: constraint over target
```

Here, `over` is a keyword that separates the target from the invariant constraint. This restricted invariant specification is violated whenever the constraint is violated after executing any transaction that matches `target`.

For example, with a contract `c`, a target of `c.*` would specify that the invariant should hold after executing any transaction within `c`. A target of `c.foo(x)` would specify that the condition need only hold after any execution of the `foo(x)` transaction. Note that the transaction parameter `x` could then be referenced by the constraint. 


### Temporal Equivalents

All invariant specifications can be expressed as equivalent (but possibly more verbose) temporal properties. Specifically, the invariant `con over target` could be equivalently written as `[]!finished(target, !con)` (replacing `target` with `*` for invariants with no specified target).
