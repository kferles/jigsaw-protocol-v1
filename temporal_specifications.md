---
title: Temporal Specifications
sidebar_position: 5
---


Temporal specifications enable a user to check properties that should hold *over time*. Temporal specifications are declared in the temporal section of the [V] specification which is marked by the `spec` tag (short for `temporal specification`). The specification itself contains a logical combination of [V] statements as follows:

```solidity
spec: prop
```

where `prop` contains [V] statements combined with logical and temporal operators.

## Temporal Operators

Unlike logical operators, temporal operators specify properties over time. All but the sequence operator are inherited from [Linear Temporal Logic (LTL)](https://en.wikipedia.org/wiki/Linear_temporal_logic) and have the same semantics. The semantics of the sequence operator is explained in the [Sequential Properties](#sequential-properties) section.

|  Operator  |    Use    |  Description  |
| :--------- | :-------: | :------------ |
| Always     | `[] a`    | `a` holds from now on |
| Eventually | `<> a`    | `a` either holds now or at some point in the future |
| Next       | `X a`     | `a` holds in the next state |
| Sequence   | `a ; b`   | `a` holds followed by `b` in the appropriate slot of the next transaction |
| Until      | `a U b`   | `b` holds at some point, and `a` holds at all previous points |
| Release    | `a R b`   | `b` holds up to and including the point where `a` begins to hold; if `a` never holds, `b` must hold at all points |

## Logical Operators

In addition to temporal operators, statements can be composed with the following logical operators.

|   Operator   |    Use    |  Description  |
| :----------- | :-------: | :------------ |
| Logical AND  | `a && b`  | Checks if both `a` and `b` hold |
| Logical OR   | <code>a &#124;&#124; b</code>  | Checks if either `a`, `b` or both hold |
| Logical NOT  | `!a`      | Checks if `a` does not hold |

## Sequential Properties

Sequential properties are a special case of temporal properties. Rather than reasoning about arbitrary transactions like temporal properties, sequential properties reason about specific sequences of transactions defined by the user. While they are less general than their temporal counterparts, they are often easier to write and verify. Such properties are specified by composing [V] statements using the sequence operator defined below.

|  Operator  |   Use   |  Description  |
| :--------- | :-----: | :------------ |
| Sequence   | `a ; b` | `a` holds followed by `b` in the appropriate slot of the next transaction |

The sequence operator allows users to specify sequences of transactions without having to directly reason about the number of steps between them in the execution model. For example, from a temporal perspective `finished(c.foo) ; started(c.bar) = finished(c.foo) && X started(c.bar)` while `finished(c.foo) ; finished(c.bar) = finished(c.foo) && X X finished(c.bar)`. The sequence operator allows the number of explicit time steps to remain hidden from view by advancing time to the appropriate location in the next transaction. Note that this means the semantics of the `a ; b` is determined by the identity of a and b (i.e., the type of [V] statement). In addition, note that for `started(c.foo) ; finished(c.foo)` to hold, it requires the sequence to include two executed `c.foo` transactions.
