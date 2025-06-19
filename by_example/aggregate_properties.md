---
title: Aggregate Properties
sidebar_position: 3
---

This section introduces a few new operators that can be used in the _conditions_ of [V] statements. These operators will allow you to express more complex properties in [V], including properties that reference _aggregate values_ across multiple transactions.

## Our Bug: Minty but not fresh

This example will look at the `mint` and `tokenSupply` functions in `MyVToken`, as well as the `MyVToken` constructor:

```solidity
constructor() {
    owner = msg.sender;

    // NOTE: Need to add amount to the total supply!
    // Can do this by calling mint instead of updating _balances directly
    /* mint(msg.sender, 100); */
    _balances[msg.sender] += 100;
}

function mint(address account, uint256 amount) public virtual onlyOwner {
    require(account != address(0), "ERC20: mint to the zero address");

    _beforeTokenTransfer(address(0), account, amount);

    _totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);

    _afterTokenTransfer(address(0), account, amount);
}

function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
}
```

Across all transactions, `MyVToken` keeps track of the total supply of tokens using the `_totalSupply` state variable. When the `MyVToken` contract is created, `100` tokens are created in the contract owner's account. Afterwards, tokens can only be created by calls to `mint` and can only be removed by calls to `burn`. Thus, the total supply of tokens should be `100` plus the sum of all minted tokens, minus the sum of all burnt tokens. This condition is expressed by the following [V] spec:

```solidity
vars: MyVToken token
spec: []!finished(token.*, token.totalSupply() != 100 + fsum{token.mint(acc, amt)}(amt) - fsum{token.burn(acc, amt)}(amt))
```

As you can see in the implementation of `MyVToken`, the constrcutor adds the tokens to the balance directly, without inrementing the total supply. This means that the returned value from `totalSupply()` will always be off by 100.

## Understanding the Spec

The first new aspect of this spec you may notice is the target: `token.*`. [V] allows wildcards to be used in targets, both in the form shown here and in the form of a standalone wildcard `*`. Here, `token.*` refers to any transactions within `MyVToken` called on `token`. When there are multiple deployed contracts, the target `*` refers to any transaction over any deployed contract. In this spec, we could also use `*` as the target if we want to check the property across transactions over all deployed contracts.

The second new feature showcased in this spec is the `fsum` macro. `fsum` is used to sum over expressions evaluated at multiple previous points in the transaction sequence. The first argument, enclosed in `{}` is a syntactic argument -- the `target` of the `fsum`. The second argument, enclosed in `()` is an expression to be evaluated at each previous blockchain state whose corresponding transaction matches the `target`. Specifically, the result of `fsum{target}(expr)` is the sum of all `expr` evaluated at each point along the preceding transaction sequence that matches the `target`. Framed another way, `fsum` can be thought of as applying a filter, map, and fold:
1. First, filter the sequence of previous blockchain states (_including the current state_) based on the input `target`. Note that these are the states _after_ the `target` transaction was successfully executed.
2. Next, map each blockchain state to the evaluation of `expr` over that state. `expr` may reference state variables, `public view` transactions, or transaction arguments.
3. Finally, sum all resulting evaluations of `expr`.

Our example condition has two `fsum` calls. The first, `fsum{token.mint(acc, amt)}(amt)`, sums the input `amt` to all previous calls to `mint`. The second does the same, but for the `burn` transaction. Thus, the righthand-side expression is exactly 100 plus the number of minted tokens, minus the number of burned tokens.

### Conditions on `target`

In some cases, users may wish to only include blockchain states in `fsum` results when certain conditions are met. For example, we may wish to express some condition involving the total number of coins minted to the zero address. To express this, we would need to apply `fsum` to all blockchain states resulting from `mint` where the `acc` parameter is 0. This can be done with a `when` clause within the target parameter of the `fsum`. With our example, the expression would take the form: `fsum{token.mint(acc, amt) when acc = 0}(amt)`.

In general, `fsum{target when cond}(expr)` is evaluated in the same way as `fsum{target}(expr)`, except that it only evaluates `expr` over blockchain states that satisfy the condition `cond`. Note that transaction parameters _are_ considered in scope for `cond`.

## Shorthand: `inv`

The spec above describes a property that should hold for `MyVToken` across all possible transactions. This type of spec is called an "invariant". Since specifying invariants is so common, [V] has an additional shorthand way to express such conditions. The following spec is an equivalent way to describe the property we discussed:

```solidity
vars: MyVToken token
inv: token.totalSupply() = 100 + fsum{token.mint(acc, amt)}(amt) - fsum{token.burn(acc, amt)}(amt)
```

In general, any spec of the form `inv: P` is equivalent to `spec: []!finished(*, !P)`. Note that since [V] only allows one spec per file, users cannot provide both a `spec` and `inv` section in a single file.

## Other Expressions in [V] Conditions

In addition to `fsum`, there are two other advanced operators we'll discuss in this section: `forall` and `state_fold`.

### `forall`

The `forall` operator allows users to quantify conditions over arrays in [V]. For example, your smart contract may keep track of an array of stake holders, and you may wish to ensure that those stake holders maintain some minimum balance. Such a condition -- that all users in some array `stakers` have a balance of at least `min_bal` -- could be expressed as:

```solidity
forall{acc in stakers}(token.balance[acc] >= min_bal)
```

Like `fsum`, `forall` takes a syntactic argument first in `{}` and an expression within `()`. In general, `forall{x in arr}(expr)` evaluates to true exactly when `expr` evaluates to true when `x` is bound to any value within `arr`. To run without error, `forall` also requires that `arr` is an array.

### `state_fold`

`state_fold` is a generalization of the `fsum` operator. When describing `fsum`, we mentioned that the operator basically acts like a combined filter, map, and fold, where `+` was the folding operator. `state_fold` generalizes this idea by allowing users to define their own fold operator. For example, the expression `100 + fsum{token.mint(acc, amt)}(amt)` from the spec above (describing the number of minted tokens) can be written equivalently as:

```solidity
state_fold{token.mint(acc, amt)}((total) -> total + amt, 100)
```

In general, `state_fold{target}((x) -> expr, a_0)` is evaluated in the following way:
1. First, filter the sequence of previous blockchain states (_including the current state_) based on the input `target`.
2. Next, starting with the oldest matching blockchain state, evaluate `expr` with `x` bound to `a_0`. Call this value `a_1`. Subsequently, evaluate `expr` over the next oldest blockchain state in the filtered sequence, binding `x` to `a_1` and call the result `a_2`. Continue this process for all `n` blockchain states in the sequence.
3. After performing this process iteratively, return the last value `a_n`.

Also, similarly to `fsum`, `when` clauses can be included in `state_fold` with the syntax `state_fold{target when cond}((x) -> expr, a_0)`.

