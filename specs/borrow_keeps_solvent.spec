vars: StablesManager manager, address holding, address token, uint256 amount, uint256 minJUsdAmountOut, bool direct
spec: []!finished(manager.borrow(holding, token, amount, minJUsdAmountOut, direct), !manager.isSolvent(token, holding))
