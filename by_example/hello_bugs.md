---
title: Hello, Bugs!
sidebar_position: 1
---

To start off, we'll take a look at using [V] to find a bug in a Solidity ERC20 contract. Throughout this guide, we'll use the contract [MyVToken.sol](src/MyVToken.sol) as our running example. The actual tool we use to find the bugs discussed in this guide is called OrCa. You can learn more about OrCa [here](../../../index.md), and read about how to use OrCa through the AuditHub platform [here](../../../getting_started/running_orca_through_saas.md).

## Our Bug: Burnt to a Crisp

For now, we'll take a look specifically at the `burn` transaction in `MyVToken`:

```solidity
function burn(address account, uint256 amount) public virtual onlyOwner {
    require(account != address(0), "ERC20: burn from the zero address");

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = _balances[account];
    // NOTE: The following overflow check should be added!
    /* require(accountBalance >= amount, "ERC20: burn amount exceeds balance"); */
    unchecked {
        _balances[account] = accountBalance - amount;
    }

    emit Transfer(account, address(0), amount);

    _afterTokenTransfer(account, address(0), amount);
}
```

As the comment indicates, there's a bug in this code -- if the `amount` burnt is larger than the balance for `account`, the unsafe subtraction will cause the updated balance to overflow. This means that after burning tokens, the balance for `account` will actually be larger than it was before the transaction! 

To catch bugs like these, we can express properties that must hold after executing `burn` as a [V] specification. Our particular property -- that burning tokens should never increase the balance of the burning account -- can be expressed with the following spec in [V]:

```solidity
vars: MyVToken token
spec: []!finished(token.burn(acc, amt), old(token.balanceOf(acc)) < token.balanceOf(acc))
```

## Understanding the Spec

Let's break down everything that's going on in this specification. The first line contains the `vars` section. This section declares "free variables" used in our spec. Free variables are variables that can take on any value. For our example, this means that any possible instantiation of `token` as an instance of the `MyVToken` contract is allowed to violate our specification. Most often, these free variables will be contract variables, but they're allowed to take primitive types like integers and strings as well.

The second line contains the `spec` section, which includes linear temporal logic (LTL) formula. In general, LTL formulae allow [V] specifications to describe properties over sequences of transactions. We discuss LTL formulae in more detail in a [later section](intro_to_ltl.md). Our particular formula only concerns a single transaction: `token.burn(acc, amt)`. We want to describe a property that must hold whenever `burn` completes, which is why we use the `finished(target, condition)` form. We call this form a "[V] statement", and it associates the given condition with a transaction (in this case, with a `MyVToken` `burn` transaction that successfully completes). Preceding this statement are two LTL operators: `[]` and `!`. `[]` is the LTL "always" operator. The formula `[]F` is satisfied whenever `F` _always_ holds (and so it is violated if `F` can be falsified). `!` is the "not" operator. The formula `!F` is satisfied whenever `F` is does not hold. Together, these operators create a "never" operator, so `[]!F` is satisfied so long as `F` _never_ holds. Note that swapping these operators to `![]` would NOT be equivalent! At this point, we can see that the formula `[]!finished(token.burn(acc, amt), C)` describes the property "it is never the case that condition `C` holds when successfully executing `token.burn(acc, amt)`".

Now let's discuss our particular condition -- `old(token.balanceOf(acc)) < token.balanceOf(acc)`. This condition is defined over both the variable `token` declared in the `vars` section and the parameters of the transaction `acc` and `amt` (though `amt` is not used). By default, expressions in [V] conditions are evaluated _after_ executing the transaction, so the expression `token.balanceOf(acc)` references the balance for account `acc` _after_ running `burn`. On the left side of the equation, the same expression is wrapped in `old`, which forces [V] to evaluate the expression _before_ the transaction executes. This means that the condition is true when `token.balanceOf(acc)` is strictly smaller before executing the transaction -- in other words, when `burn` *increases* the balance for the account. Finally, taking the condition in the context of our greater formula `[]!finished(token.burn(acc, amt), old(token.balanceOf(acc)) < token.balanceOf(acc))`, we can describe the property in English as "It is never the case that `burn` increases the balance of `acc` when successfully executing `token.burn(acc, amt)`".

As we saw in the implementation of `burn` for `MyVToken`, this property is false! This is because we can choose `token` to represent an instance of the `MyVToken` contract with, say, a `_balances` mapping where `_balances[0x1234] = 0`. We can also choose to pass parameters `acc = 0x1234` and `amt = 10` to `burn`. This would cause `_balances[0x1234]` to overflow due to the unsafe subtraction, thus violating our spec. In this case, there are multiple choices for values for `token`, `acc`, and `amt` that would show our property to be false, but our use of the operators `[]!` means that we need only find one such example to prove that the property does not hold.

In the [next section](intro_to_ltl.md), we discuss how to use LTL formulae to describe more complex properties in [V].
