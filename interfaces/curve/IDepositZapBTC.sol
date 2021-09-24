// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.11;


interface IDepositZapBTC {
    
    /**
     * @notice Wrap underlying coins and deposit them into `_pool`
     * @param _pool Address of the pool to deposit into
     * @param _deposit_amounts List of amounts of underlying coins to deposit
     * @param _min_mint_amount Minimum amount of LP tokens to mint from the deposit
     * @param _receiver Address that receives the LP tokens
     * @return Amount of LP tokens received by depositing
     */
    function add_liquidity(
        address _pool,
        uint256[4] calldata _deposit_amounts,
        uint256 _min_mint_amount,
        address _receiver
    ) external returns (uint256);


    /**
     *  @notice Withdraw and unwrap coins from the pool
     *  @dev Withdrawal amounts are based on current deposit ratios
     *  @param _pool Address of the pool to deposit into
     *  @param _burn_amount Quantity of LP tokens to burn in the withdrawal
     *  @param _min_amounts Minimum amounts of underlying coins to receive
     *  @param _receiver Address that receives the LP tokens
     *  @return List of amounts of underlying coins that were withdrawn
     */
    function remove_liquidity(
        address _pool,
        uint256 _burn_amount,
        uint256[4] calldata _min_amounts,        
        address _receiver
    ) external returns (uint256[4] memory);


    /**
     *  @notice Withdraw and unwrap a single coin from the pool
     *  @param _pool Address of the pool to deposit into
     *  @param _burn_amount Amount of LP tokens to burn in the withdrawal
     *  @param i Index value of the coin to withdraw
     *  @param _min_amount Minimum amount of underlying coin to receive
     *  @param _receiver Address that receives the LP tokens
     *  @return Amount of underlying coin received
     */
    function remove_liquidity_one_coin(
        address _pool,
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount,
        address _receiver
    ) external returns (uint256);    


    /**
     *  @notice Withdraw coins from the pool in an imbalanced amount
     *  @param _pool Address of the pool to deposit into
     *  @param _amounts List of amounts of underlying coins to withdraw
     *  @param _max_burn_amount Maximum amount of LP token to burn in the withdrawal
     *  @param _receiver Address that receives the LP tokens
     *  @return Actual amount of the LP token burned in the withdrawal
     */
    function remove_liquidity_imbalance(
        address _pool,
        uint256[4] calldata _amounts,       
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);        


    /**
     * @notice Calculate the amount received when withdrawing and unwrapping a single coin
     * @param _pool Address of the pool to deposit into
     * @param _token_amount Amount of LP tokens to burn in the withdrawal
     * @param i Index value of the underlying coin to withdraw
     * @return Amount of coin received
     */
    function calc_withdraw_one_coin(
        address _pool,        
        uint256 _token_amount,
        int128 i
    ) external view returns (uint256);     
    

    /**
        @notice Calculate addition or reduction in token supply from a deposit or withdrawal
        @dev This calculation accounts for slippage, but not fees.
         Needed to prevent front-running, not for precise calculations!
        @param _pool Address of the pool to deposit into
        @param _amounts Amount of each underlying coin being deposited
        @param _is_deposit set True for deposits, False for withdrawals
        @return Expected amount of LP tokens received
     */
    function calc_token_amount(
        address _pool,        
        uint256[4] calldata _amounts,
        bool _is_deposit
    ) external view returns (uint256);    
}
