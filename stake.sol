// SPDX-License-Identifier: MIT




/**    ______  ____  ____  _____  ____    ____  _______   ________  ________  ________  
 *   .' ___  ||_   ||   _||_   _||_   \  /   _||_   __ \ |  __   _||_   __  ||_   __  | 
 *  / .'   \_|  | |__| |    | |    |   \/   |    | |__) ||_/  / /    | |_ \_|  | |_ \_| 
 *  | |         |  __  |    | |    | |\  /| |    |  ___/    .'.' _   |  _| _   |  _| _  
 *  \ `.___.'\ _| |  | |_  _| |_  _| |_\/_| |_  _| |_     _/ /__/ | _| |__/ | _| |__/ | 
 *   `.____ .'|____||____||_____||_____||_____||_____|   |________||________||________| 
 */

pragma solidity 0.8.20;

// Token
import "./IERC20.sol";

// Utils
import "./Initializable.sol";
import "./OwnableUpgradeable.sol";
import "./ContextUpgradeable.sol";
import "./PausableUpgradeable.sol";
import "./Staking20Upgradeable.sol";

contract tokentakeV2 is 
    Initializable, 
    Staking20Upgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable 
    {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract, like a constructor.
    function initialize(
        address _tokenAddress,
        uint80 _timeUnit,
        uint256[] memory _rewardRatioNumerator,
        uint256[] memory _rewardRatioDenominator,
        uint256[] memory _rewardRatioAmount,
        uint256 _minStakeAmount,
        uint256 _locktime
    ) external initializer {
        __Ownable_init(_msgSender());
        __Staking20_init(_tokenAddress, 18);
        __Pausable_init();
        _setStakingCondition(_timeUnit, _rewardRatioNumerator, _rewardRatioDenominator, _rewardRatioAmount);
        _setMinStakeAmount(_minStakeAmount);
        _setLocktime(_locktime);
    }

    /// @dev Admin deposits reward tokens.
    function depositRewardTokens(uint256 _amount) external payable nonReentrant onlyOwner {
        require(_amount > 0, "No balance added");
        uint256 balanceBefore = IERC20(stakingToken).balanceOf(address(this));
        
        bool success = IERC20(stakingToken).transferFrom(_msgSender(), address(this), _amount);
        require(success, "Token transfer failed");

        uint256 actualAmount = IERC20(stakingToken).balanceOf(address(this)) - balanceBefore;

        rewardTokenBalance += actualAmount;
    }

    /// @dev Admin can withdraw excess reward tokens.
    function withdrawRewardTokens(uint256 _amount) external nonReentrant onlyOwner {
        // to prevent locking of direct-transferred tokens
        rewardTokenBalance = _amount > rewardTokenBalance ? 0 : rewardTokenBalance - _amount;

        bool success = IERC20(stakingToken).transfer(_msgSender(), _amount);
        require(success, "Token transfer failed");

        // The withdrawal shouldn't reduce staking token balance. `>=` accounts for any accidental transfers.
        require(
            IERC20(stakingToken).balanceOf(address(this)) >= stakingTokenBalance,
            "Staking token balance reduced."
        );
    }

    /**
     *  @notice  Set locktime.
     *
     *  @param _newAmount    New locktime in seconds.
     */
    function setLocktime(uint256 _newAmount) external onlyOwner {
        _setLocktime(_newAmount);
    }

    /**
     *  @notice  Set minimum stake limit.
     *
     *  @param _newAmount    New minimum stake limit.
     */
    function setMinStakeAmount(uint256 _newAmount) external onlyOwner {
        _setMinStakeAmount(_newAmount);
    }

    /**
     *  @notice  Set time unit. Set as a number of seconds.
     *           Could be specified as -- x * 1 hours, x * 1 days, etc.
     *
     *  @param _timeUnit    New time unit.
     */
    function setTimeUnit(uint80 _timeUnit) external onlyOwner {
        _setTimeUnit(_timeUnit);
    }

    /**
     *  @notice  Set rewards per unit of time.
     *           Interpreted as (numerator/denominator) rewards per second/per day/etc based on time-unit.
     *
     *  @param _numerator    Reward ratio numerator.
     *  @param _denominator  Reward ratio denominator.
     */
    function setRewardRatio(uint256[] memory _numerator, uint256[] memory _denominator, uint256[] memory _rewardRatioAmount) external onlyOwner {
        _setRewardRatio(_numerator, _denominator, _rewardRatioAmount);
    }

    /**
     *  @notice    Stake ERC20 Tokens.
     *  @param _amount    Amount to stake.
     */
    function stake(uint256 _amount) external payable nonReentrant whenNotPaused {
        _stake(_amount);
    }

    /**
     *  @notice    Withdraw staked ERC20 tokens.
     *  @param _amount    Amount to withdraw.
     */
    function withdraw(uint256 _amount) external nonReentrant {
        _withdraw(_amount);
    }

    /**
     *  @notice    Claim accumulated rewards.
     */
    function claimRewards() external nonReentrant {
        _claimRewards();
    }

    /**
     *  @notice    To pause staking
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     *  @notice     To unpause staking
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}