---
title: Intro to LTL
sidebar_position: 2
---

In the previous section, we constructed a specification that reasoned about a single transaction. In this section, we'll see how LTL (Linear Temporal Logic) formulae can be used to describe properties over sequences of multiple transaction. Again, the specs we construct will reason over the contract [MyVToken.sol](src/MyVToken.sol).

## Our Bug: Little Transfer Lapse

In this example, we'll look at two transactions: `approve` and `transferFrom`:

```solidity
function approve(
    address tokenOwner,
    address spender,
    uint256 amount
) internal virtual {
    require(
        tokenOwner != address(0),
        "ERC20: approve from the zero address"
    );
    require(spender != address(0), "ERC20: approve to the zero address");

    // NOTE: should be `tokenOwner` instead of `owner`
    // (`owner` refers to the owner of the contract)
    _allowances[owner][spender] = amount;
    emit Approval(tokenOwner, spender, amount);
}

function transferFrom(
    address from,
    address to,
    uint256 amount
) public virtual override returns (bool) {
    address spender = msg.sender;

    // Checks that spender has enough allowance
    // Then removes amount from spender's allowance
    _spendAllowance(from, spender, amount);

    _transfer(from, to, amount);
    return true;
}
```

The purpose of `allowance` is to permit other users to spend on the behalf of the allowing party. However, as the comment in the code indicates, there is a bug in `approve` that prevents this functionality. Specifically, instead of updating the `allowance` mapping for `tokenOwner`, `approve` updates the allowance for the contract owner!

To catch this bug, we'll create a functional correctness specification that describes the purpose of `approve`. We want to ensure that after calling `approve(tokenOwner, spender, amount)`, a call to `transferFrom(spender, otherAddress, otherAmount)` succeeds for any `otherAddress` and for any `otherAmount <= amount`. This property is expressed by the following [V] spec:

```solidity
vars: MyVToken token, address spender, uint allowed
spec: []!(finished(token.approve(tOwner, acc, amt), acc = spender && amt = allowed) ;
          reverted(token.transferFrom(from, to, amt), from = spender && amt <= allowed))
```

## Understanding the Spec

In the last section, we learned how the `finished` statement describes properties over transactions that complete successfully. In this spec, in addition to the `finished` statement, we also include a `reverted` statement, which matches any transaction that _reverts_ when executed. Before we fully dive into explaining the constraints within the statements though, it's important that we first discuss how the composition of these statements corresponds to actual sequences of transactions.

[V] includes several LTL operators for composing statements. We've seen `[]` (the "always" operator), and to combine it with `!` to create "safety" specs -- specs that assert that bad things should not happen to the system. Most specs in [V] (including this one) will start with `[]!`, since our specs often describe behaviors that should never happen. Writing specs in this way also has the nice property that whenever they are violated, we get a concrete "counterexample" to the spec that we can immediately run on our code to reproduce the bug.

In this spec, we see another LTL operator being used: the sequential operator `;`. To explain this, we'll have to discuss _timesteps_, a detail of LTL formulae that we glossed over in the last section. In addition to the set of variable assignments that is necessary to evaluate boolean formulas (e.g. `a || b` is satisfied by `{a: True, b: False}`), LTL formulas are evaluated over a sequence of events. A given formula may be satisfied given one sequence, but not the other. For our context, these sequences are made up of transactions, and each step in the sequence denotes the start or end to a transaction. When we write a spec in [V] for our smart contract, we are hoping that the LTL formula it represents is satisfied for every possible sequence of transactions that can be created through our smart contracts. For example, when we write `spec: []!F`, we hope that along every possible sequence of transactions, `!F` holds at every step. The sequence operator `;` then allows us to reference the _next_ transaction in the sequence. Specifically, `F;G` is satisfied by a sequence if `F` is satisfied by the first transaction and `G` is satisfied by the second. Combining this with our "never" operator gives us `[]!(F;G)`, which is satisfied by a sequence of transactions so long as there is no point in the sequence where `F` is satisfied and `G` is satisfied by the following transaction. 

Let's now apply that understanding to our current spec. The first statement `finished(token.approve(tOwner, acc, amt), acc = spender && amt = allowed)` is satisfied by a transaction `token.approve` whenever it finishes and its arguments `acc` and `amt` match those we defined in the `vars` section. This requirement is fairly easy to satisfy, since as free variables, `spender` and `allowed` may take any possible values. The second statement `reverted(token.transferFrom(from, to, amt), from = spender && amt <= allowed)` is satisfied by transaction `token.transferFrom` immediately following the `token.approve` _that reverts_ when both of the following are true:
   1. The `from` argument matches one of those same free variables, and thus matches the `acc` parameter from the previous transaction.
   2. The `amt` argument is no more than `allowed`, i.e. no more than the `amt` parameter of the `token.approve` transaction.
Thus, the formula as a whole is satisfied by a sequence so long as there is no sequential pair of `approve` and `transferFrom` transactions that satisfy each of these statements respectively.

Now let's see how our bug can lead to a violation in this spec. As we discussed, `token.approve` should enable the spender to transfer a given amount. However, the bug we demonstrated would not allow this for any spender other than the token owner! This means that the spec can be violated by a sequence including sequential `approve` and `transferFrom` transactions when the `spender` free variable is set to any user address and the `allowed` variable is made non-zero.

## Expanding the Spec

This sub-section delves even further into the technical details surrounding LTL. If you'd like to skip it, feel free to move onto the [next section](aggregate_properties.md), where we discuss how to express aggregate properties over sequences of blockchain states within [V] specs.

One shortcoming of the spec that we wrote above is that it requires the `transferFrom` to occur _immediately_ after a call to `approve`. In reality, the spender should be able to transfer funds at any time in the future, so long as they have not been spent. Essentially, we want to say that after `approve` is called, any valid `transferFrom` involving the spender should not revert _until_ those funds are actually spent. How would we write a spec to express this required behavior?

To understand the answer, we'll need to introduce a new LTL operator: `U`, read as "until". `U` allows us to express properties where one thing must be true _until_ another becomes true. Specifically, the formula `F U G` is satisfied by a sequence when
  1. there is some event `e` in the sequence that satisfies `G`, and 
  2. all events in the sequence _before_ `e` satisfy `F`.
Using `U` will allow us to express that `transferFrom` should not revert _until_ the approved funds are used.

Our new spec will also use the `X` operator, read "next", which is very similar to `;` with some slight differences. From the explanation of timesteps, you may have noticed a unique quirk of [V] -- the start and end of a transaction are each considered _distinct_ timesteps. A statement like `finished(c.foo, F)` or `reverted(c.bar, G)` is satisfied by the _end_ of the transaction, as that is the point that the transaction will either complete successfully or revert. Thus, it could never be the case that at one time step, `finished(c.foo, F)` holds, and then at the very next one, `reverted(c.bar, G)` holds. The purpose of `;` is to act as syntax sugar around the "next" operator `X`. When using `;`, [V] will automatically use the number of `X` operators necessary to make the series of statements feasibly satisfiable. For our example, `finished(c.foo, F); reverted(c.bar, G)` would be translated to `finished(c.foo, F) && XXreverted(c.bar, G)`, since the reverting `c.bar` would have to happen two steps ahead of the successfully completed `c.foo` (as one step after would be the start of the `c.bar` transaction).

Now that we understand these two new operators, let's take a look at our new spec:

```solidity
[]!(finished(token.approve(tOwner, acc, amt), acc = spender && amt = allowed) &&
    X(!finished(token.transferFrom(from, to, amt), from = spender) U
       reverted(token.transferFrom(from, to, amt), from = spender && amt <= allowed)))
```

This spec has the same `finished` and `reverted` statements from our previous spec, which are now the first and third statements here respectively. However, we no longer require the `transferFrom` to take place immedately after the `approve`. Instead, we say that starting from the next step after `approve`,the formula `!finished(token.transferFrom(from, to, amt), from = spender)` must hold _until_ our revert statement holds. Remember, the entire forumla is surrounded by `[]!`, so any sequence satisfying this inner formula consitutes a counterexample (and thus a bug in our smart contracts). Thus, our new spec is violated by any sequence where (a) an `approve` transaction succeeds, (b) eventually, a `transferFrom` transaction reverts where `from` is the approved sender and `amt` is no more than the approved amount, and (c) no transactions in between the two were successfully-completing `transferFrom` calls where `from` was that same spender.

At this point, you may be left wondering: "What if the spender spends less than the allowed amount and then incorrectly reverts? How could I write a spec to catch that bug?" To catch a bug like this, we need to be able to express the amount of funds the spender has spent over a sequence of transactions. [In the next section](aggregate_properties.md), we discuss how to express aggregate properties like these, as well as other more complex properties in [V].