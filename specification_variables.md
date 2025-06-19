---
title: Specification Variables
sidebar_position: 6
---

Specification variables are an essential part of the [V] Specification Language as they allow relationships across transactions to be expressed. Similar to free variables in SMT solvers, such variables range over the domain corresponding to their type, allowing them to take on any possible value in that domain. 

Variables are declared in a special section and are scoped for the entire specification. Similar to declaring a variable in other programming languages, a variable simply needs a type and a name. For instance, `uint256 a` declares a variable called `a` with a type of `uint256`. Multiple variables can be declared as a comma-separated list in a section preceded by the `vars` keyword, like so:

```solidity
vars: uint256 a, bool b, ContractName c
```

Note that we can also declare variables of smart contract type, where the type is given by the smart contract name.

**IMPORTANT**: All [V] specifications must contain a Variables section!

## Types

Currently, most types in [V] are inherited from the smart contract language. That is, the types that are available are defined by the smart contract language the specification is checking. For example, in Solidity types such as `uint256`, `string`, and `address` may be used as well as smart contract names, as we have seen in the previous example.

## Variable Use

Unlike variables in a conventional programming language, variables in [V] are `unbound` or `free` by default. This means that a variable may have any possible value, allowing specifications to reason about more than a single concrete input. Moreover, uses of the variable place constraints upon its values. The specification then holds if at least one value can be found such that all of the constraints placed upon a variable are satisfied.

As an example, consider a variable `uint256 a` and say the specification places the following constraints upon `a`: `a > 0 && a < 10`. Since a satisfying assignment exists for `a` (e.g., `a = 5`), the specification will hold as long as the rest of it holds. Now consider a new specification that places the following constraints upon `a`: `a > 0 && a = 0`. In such a case, the specification does not hold since no satisfying assignment exists for `a`.
