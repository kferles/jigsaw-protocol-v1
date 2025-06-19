vars: JigsawUSD token, address user, uint256 amount
spec: []!finished(token.burnFrom(user, amount), token.balanceOf(user) != old(token.balanceOf(user)) - amount)
