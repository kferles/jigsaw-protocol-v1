---
title: Fairness Assumptions
sidebar_position: 8
---

Fairness assumptions allow a user to assume some (temporal) property holds. A fairness assumption is placed in the Fairness Section of the [V] specification which is marked by the `fair` tag (short for `fairness assumption`). The specification itself contains a logical combination of [V] statements as follows:

```solidity
fair: prop
```

where `prop` contains [V] statements combined with logical and temporal operators (see [temporal specifications](temporal_specifications.md) for more information about these operators).

**Important**: The `fair` section must come before the `inv`/`spec` sections in the [V] specification!

Note that the `fair` section is *OPTIONAL* and is not necessary to include in every [V] specification.

# Reducing to a Temporal Property

Fairness assumptions can be equivalently expressed using only temporal properties as follows:

```
fair: prop1
spec: prop2
```

becomes the following temporal specification

```
spec: prop1 ==> prop2
```

**NOTE**: While these are technically equivalent, OrCa may sometimes behave differently on these two specifications as OrCa uses special reasoning to take advantage of known assumptions given in Fairness sections.
