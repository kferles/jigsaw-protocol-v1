---
title: "[V] Statements"
sidebar_position: 5
---

[V] allows users to reference information about the execution of a transaction on the blockchain via so-called "[V] statements", which are formulated as follows:

```solidity
action (target, constraint)
```

The `action` describes the state of a transaction's execution on the blockchain, using the same terms introduced above for the execution model (i.e., `started`, `executed`, `finished`, and `reverted`).

The `target` describes which function/s we are interested in expressing a property about. It should be noted that only `public` or `external` functions can be referenced in a [V] statement target.

Finally, the `constraint` describes the *condition* we are checking when the `target` occurs at the timepoint specified by the `action`. 

For example, if we want to check whether or not a user's funds increase when they withdraw from a `Bank` contract, we might write the following [V] statement:

```
finished(Bank.withdraw, balance(sender) > old(balance(sender)))
```

Here, `balance` is a special [V] function used to obtain the balance of a particular address, `sender` refers to the sender of the transaction (i.e., `msg.sender`), and `old` is a special function which refers to the state of the blockchain before the `target` function is executed -- in this case, `old(balance(sender))` gets the balance of the sender *before* `withdraw` is executed, while `balance(sender)` gets the balance of the sender *after* the `withdraw`.

## Action

The action describes the state of a transaction's execution on the blockchain and also establishes when the constraint is checked. Below we describe each type of action and how it impacts the checking of the constraint.

|  Action  | Description |
| :------- | :---------- |
| started  | Refers to the invocation of the target transaction. Constraints query the blockchain state immediately before the execution of the transaction. |
| finished | Refers to a revert-free execution of the target transaction. Constraints query the blockchain state immediately after the modifications are committed to the ledger. |
| reverted | Refers to an execution of the target transaction that is reverted. Constraints query the blockchain state immediately after the revert occurs. |
| executed | Refers to a completed execution of the target transaction regardless of whether it reverts or not. Constraints query the blockchain state after the execution of the transaction completes. |

## Target

The target refers to the recipient `entity` (i.e., a smart contract) as well as the `transaction` to execute (i.e., a `public/external` smart contract function), and it has the following structure:

```solidity
entity.transaction
```

### Entity

The recipient entity is a reference to a smart contract variable. See [the specification variable section](specification_variables.md) for more information about how to declare variables for [V] specifications.

A user can also use the wildcard operator `*` to reference any given function. For instance, `Bank.*` would reference any function in the `Bank` contract, while just `*` references any function across any contract being fuzzed.

##### Transaction

This is the transaction to execute on the given recipient entity. It consists of the name of the function along with the arguments required to execute it, if any. In the event that the arguments are unnecessary for the intention of the [V] statement, and the function name is not overloaded, they can be excluded entirely, and just the function name can be provided. 

**Scoping Warning**: Variables declared/used as arguments of the `transaction` are only in scope in the `constraint` portion of the [V] statement under consideration. If they share a name with a specification variable declared in the [Variable Section](specification_variables.md) of the [V] specification, they will simply shadow the specification variable.

## Constraint

At a high level, a constraint is a [V] boolean expressions. In general, [V] expressions are operations composed of blockchain variables, smart contract variables, pure or view functions, specification variables, argument aliases, and [V** utility variables and functions.

**NOTE**: If no constraint is necessary, simply leaving off the constraint section is identical to having the constraint `True`.

### Blockchain Variables

To allow the specification of properties across different blockchains and languages, [V] provides language-agnostic access to information commonly provided by blockchains as follows:

|   Utility   | Description |
| :---------- | :---------- |
| `nulladdr`  | Evaluates to the null account |
| `sender`    | Specifies the account that invoked the transaction |
| `value`     | Specifies the amount of native tokens attached by the sender to the transaction’s message |
| `timestamp` | Specifies the timestamp of the blockchain at the invoked transaction |

### [V] Utility Variables and Functions

[V] has a series of utility variables and functions used to facilitate the property specification:

|   Utility                   | Description |
| :-------------------------- | :---------- |
| `ret`                       | The return value of the given transaction |
| `balance(account)`          | Returns `account`’s balance in native tokens |
| `old(expr)`                 | Evaluates `expr` just before the transaction executes |
| `len(arr)`                  | Returns the length of `arr` array |
| `range(low, high)`          | Returns a sorted array consisting of `low, low + 1, low + 2, ..., high-1` |
| `address(val)`              | Converts passed integer or string `val` to an address |
| `elem_in_range(low, high)`  | Returns a random integer within the `[low, high)` range |
| `MAX_UINT256`               | Returns maximum possible value for a `uint256` |
| `MAX_INT256`                | Returns maximum possible value for a `int256` |

### Arithmetic Operators

[V] allows the use of typical arithmetic operators to perform mathematical operations. Specifically, it supports the operators below:

|    Operator    |   Use   |  Description  |
| :------------- | :-----: | :------------ |
| Addition       | `a + b` | Adds the values of `a` and `b` |
| Subtraction    | `a - b` | Subtracts the value of `b` from `a` |
| Multiplication | `a * b` | Multiplies the values of `a` and `b` |
| Division       | `a / b` | Divides `a` by `b` |
| Modulus        | `a % b` | Provides the remainder of `a`’s division by `b` |
| Unary Minus    | `-a`    | Changes the sign of `a` |

### Relational Operators

[V] provides various relational operators to perform comparisons betwen values:


|     Operator     |        Use        |  Description  |
| :--------------- | :---------------: | :------------ |
| Equal            | `a = b`           | Checks if the value of `a` is equal to the value of `b` |
| Not Equal        | `a != b`          | Checks if the value of `a` is not equal to the value of `b` |
| Greater Than     | `a > b`           | Checks if the value of `a` is greater than the value of `b` |
| Greater or Equal | `a >= b`          | Checks if the value of `a` is greater than or equal to the value of `b` |
| Less Than        | `a < b`           | Checks if the value of `a` is less than the value of `b` |
| Less or Equal    | `a <= b`          | Checks if the value of `a` is less than or equal to the value of `b` |

### Logical Operators

[V] supports the following logical operators:

|   Operator   |    Use    |  Description  |
| :----------- | :-------: | :------------ |
| Logical AND  | `a && b`  | Checks if both `a` and `b` hold |
| Logical OR   | `a \|\| b`  | Checks if either `a`, `b` or both hold |
| Logical NOT  | `!a`      | Checks if `a` does not hold |
| Implication  | `a ==> b` | Checks that `b` holds if `a` holds |

### Access Operators

[V] also provides operators for accessing members of smart contracts (i.e., `public/external` variables and functions) and collections. To make an access into a contract, though, [V] must know which contract is being accessed:


|     Operator     |      Use      |  Description  |
| :--------------- | :-----------: | :------------ |
| Index            | `c[i]`        | Accesses collection `c` at index `i` |
| Member Variable  | `c.v`         | Accesses the member variable `v` contained in `c` |
| Member Function  | `c.fn(args)`  | Calls the member function `fn` with the arguments `args` provided by `c` |

### Iteration Operators

[V] provides several operators for iterating over both array values and over previous blockchain states in the transaction sequence.

|   Utility                                         | Description |
| :------------------------------------------------ | :---------- |
| `fsum{target when cond}(expr)`                    | Accumulates the sum of `expr` across all transactions to `target` that successfully execute where `cond` holds. Note that this creates a nested scope where the blockchain variables, utility variables and utility functions refer to the specified target transaction |
| `fsum{target}(expr)`                              | Shorthand for `fsum` with `cond` set to `True`. |
| `state_fold{target when cond}((x) -> expr, expr)` | A generalization of `fsum`. The first argument `(x) -> expr` is the accumulation function, which takes as input the previous accumulated value and outputs the new accumulated value (any identifier may be used in place of `x`). Transaction parameters from `target` are considered in scope for this expression. The second parameter `expr` is the initial accumulated value, and transaction parameters are _not_ in scope for this expression. Similar to `fsum`, the accumulator is only applied to transactions `target` that successfully execute where `cond` holds. |
| `state_fold{target}((x) -> expr, expr)`           | Shorthand for `state_fold` with `cond` set to `True`. |
| `forall{x : arr}(expr)`                         | Evaluates `expr` `\|arr\|` times, where `x` is bound to each element of `arr`, then evaluates to the conjunction of all results. `arr` must evaluate to an array. `expr` must always evaluate to a boolean value. |
