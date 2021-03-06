// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/badger/IController.sol";

import "../interfaces/curve/IDepositZapBTC.sol";

import {BaseStrategy} from "../deps/BaseStrategy.sol";

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public crvToken; // Token we provide liquidity with
    address public reward; // Token we farm and swap to want / crvToken

    uint256 crvTokenAfterDeposit;  // Keep track of the original deposit for CRV 

    address public constant CURVE_ZAP_BTC = 
        0x7AbDBAf29929e7F8621B757D2a7c04d78d633834;
    address public constant CURVE_LENDING_POOL =
        0xFD9f9784ac00432794c8D370d4910D2a3782324C;  


    // Used to signal to the Badger Tree that rewards where sent to it
    event TreeDistribution(
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address[3] memory _wantConfig,
        uint256[3] memory _feeConfig
    ) public initializer {
        __BaseStrategy_init(
            _governance,
            _strategist,
            _controller,
            _keeper,
            _guardian
        );
        /// @dev Add config here
        want = _wantConfig[0];
        crvToken = _wantConfig[1];
        reward = _wantConfig[2];

        performanceFeeGovernance = _feeConfig[0];
        performanceFeeStrategist = _feeConfig[1];
        withdrawalFee = _feeConfig[2];

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(CURVE_ZAP_BTC, type(uint256).max);
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external pure override returns (string memory) {
        return "CurveDepositStrategy";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public view override returns (uint256) {
        return IERC20Upgradeable(crvToken).balanceOf(address(this));
    }

    /// @dev Returns true if this strategy requires tending
    function isTendable() public view override returns (bool) {
        return true;
    }

    // @dev These are the tokens that cannot be moved except by the vault
    function getProtectedTokens()
        public
        view
        override
        returns (address[] memory)
    {
        address[] memory protectedTokens = new address[](3);
        protectedTokens[0] = want;
        protectedTokens[1] = crvToken;
        protectedTokens[2] = reward;
        return protectedTokens;
    }

    /// ===== Internal Core Implementations =====

    /// @dev security check to avoid moving tokens that would cause a rugpull, edit based on strat
    function _onlyNotProtectedTokens(address _asset) internal override {
        address[] memory protectedTokens = getProtectedTokens();

        for (uint256 x = 0; x < protectedTokens.length; x++) {
            require(
                address(protectedTokens[x]) != _asset,
                "Asset is protected"
            );
        }
    }

    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    function _deposit(uint256 _amount) internal override {

        uint256[4] memory amounts = [0,0,_amount,0];
        uint256 expected = IDepositZapBTC(CURVE_ZAP_BTC).calc_token_amount(CURVE_LENDING_POOL, amounts, true) * 99 / 100;
        crvTokenAfterDeposit = IDepositZapBTC(CURVE_ZAP_BTC).add_liquidity(CURVE_LENDING_POOL, amounts, expected, address(this));
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        
        IDepositZapBTC(CURVE_ZAP_BTC).remove_liquidity_one_coin(CURVE_LENDING_POOL, balanceOfPool(), 0, 2, address(this));
    }

    /// @dev withdraw the specified amount of want, liquidate from crvToken to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        if(_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        
        IDepositZapBTC(CURVE_ZAP_BTC).remove_liquidity_one_coin(CURVE_LENDING_POOL, _amount, 0, 2, address(this));

        return _amount;
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        /* 
         * Curve protocoll will automatically compound earnings, 
         * so we are going to determine the rewards based on the difference between the balanceOfPool        
         * then we are going to withdraw those extra tokens gained.
         */  

        // Determined earned by substracting the amount of CRVTokens assigned when deposited vs the current amount
        uint256 earned =
            balanceOfPool().sub(crvTokenAfterDeposit);

        // Remove from liquidity the earned tokens
        _withdrawSome(earned);

        /// @notice Keep this in so you get paid!
        (uint256 governancePerformanceFee, uint256 strategistPerformanceFee) =
            _processRewardsFees(earned, reward);

        // TODO: If you are harvesting a reward token you're not compounding
        // You probably still want to capture fees for it
        // // Process Sushi rewards if existing
        // if (sushiAmount > 0) {
        //     // Process fees on Sushi Rewards
        //     // NOTE: Use this to receive fees on the reward token
        //     _processRewardsFees(sushiAmount, SUSHI_TOKEN);

        //     // Transfer balance of Sushi to the Badger Tree
        //     // NOTE: Send reward to badgerTree
        //     uint256 sushiBalance = IERC20Upgradeable(SUSHI_TOKEN).balanceOf(address(this));
        //     IERC20Upgradeable(SUSHI_TOKEN).safeTransfer(badgerTree, sushiBalance);
        //
        //     // NOTE: Signal the amount of reward sent to the badger tree
        //     emit TreeDistribution(SUSHI_TOKEN, sushiBalance, block.number, block.timestamp);
        // }

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(earned, block.number);

        /// @dev Harvest must return the amount of want increased
        return earned;
    }

    // Alternative Harvest with Price received from harvester, used to avoid exessive front-running
    function harvest(uint256 price)
        external
        whenNotPaused
        returns (uint256 harvested)
    {}

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();

        if (balanceOfWant() > 0) {
            uint256[4] memory amounts = [0,0,balanceOfWant(),0];
            uint256 expected = IDepositZapBTC(CURVE_ZAP_BTC).calc_token_amount(CURVE_LENDING_POOL, amounts, true) * 99 /100;
            IDepositZapBTC(CURVE_ZAP_BTC).add_liquidity(CURVE_LENDING_POOL, amounts, expected, address(this));
        }

    }

    /// ===== Internal Helper Functions =====

    /// @dev used to manage the governance and strategist fee on earned rewards, make sure to use it to get paid!
    function _processRewardsFees(uint256 _amount, address _token)
        internal
        returns (uint256 governanceRewardsFee, uint256 strategistRewardsFee)
    {
        governanceRewardsFee = _processFee(
            _token,
            _amount,
            performanceFeeGovernance,
            IController(controller).rewards()
        );

        strategistRewardsFee = _processFee(
            _token,
            _amount,
            performanceFeeStrategist,
            strategist
        );
    }
}
