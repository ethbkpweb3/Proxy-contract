// SPDX-License-Identifier: MIT


pragma solidity 0.8.20;

import "./ReentrancyGuardUpgradeable.sol";
import "./ContextUpgradeable.sol";
import "./IERC20.sol";
import "./IStaking20.sol";
import "./SafeMath.sol";

abstract contract Staking20Upgradeable is ReentrancyGuardUpgradeable, IStaking20 {
    
    /// @dev Total wallets staked their coins in the contract.
    uint256 public totalStakersCount;

    /// @dev Total amount of reward paid by the contract.
    uint256 public totalRewardPaid;

    /// @dev Total amount of coin staked in the contract.
    uint256 public totalCoinStaked;

    /// @dev Total amount of reward tokens in the contract currently.
    uint256 public rewardTokenBalance;

    ///@dev Address of ERC20 contract -- staked tokens belong to this contract.
    address public stakingToken;

    /// @dev Decimals of staking token.
    uint16 public stakingTokenDecimals;

    ///@dev Next staking condition Id. Tracks number of conditon updates so far.
    uint64 private nextConditionId;

    /// @dev Total amount of tokens staked in the contract.
    uint256 public stakingTokenBalance;

    /// @dev List of accounts that have staked that token-id.
    address[] public stakersArray;

    /// @dev Minimum stake amount to stake.
    uint256 public minStakeAmount;

    /// @dev Locktime in seconds.
    uint256 public locktime;

    ///@dev Mapping staker address to Staker struct.
    mapping(address => Staker) public stakers;

    ///@dev Mapping from condition Id to staking condition.
    mapping(uint256 => StakingCondition) private stakingConditions;

    function __Staking20_init(
        address _stakingToken,
        uint16 _stakingTokenDecimals
    ) internal onlyInitializing {
        __ReentrancyGuard_init();

        require(address(_stakingToken) != address(0), "token address 0");
        require(_stakingTokenDecimals != 0, "decimals 0");

        stakingToken = _stakingToken;
        stakingTokenDecimals = _stakingTokenDecimals;
    }

    /*///////////////////////////////////////////////////////////////
                        External/Public Functions
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice View amount staked, rewards and total rewards for a user.
     *
     *  @param _staker          Address for which to calculated rewards.
     *  @return _tokensStaked   Amount of tokens staked.
     *  @return _rewards        Available reward amount.
     *  @return _totalRewards   Total reward amount.
     */
    function getStakeInfo(address _staker) external view virtual returns (uint256 _tokensStaked, uint256 _rewards, uint256 _totalRewards) {
        _tokensStaked = stakers[_staker].amountStaked;
        _rewards = _availableRewards(_staker);
        _totalRewards = stakers[_staker].totalEarnedRewards;
    }

    /// @notice View locked coins of the staker.
    function getLockedCoins(address _staker) public view returns (LockedDeposits[] memory _lockedCoins) {
        _lockedCoins = stakers[_staker].lockedCoins;
    }

    /// @notice View timeunit used by the contract.
    function getTimeUnit() public view returns (uint80 _timeUnit) {
        _timeUnit = stakingConditions[nextConditionId - 1].timeUnit;
    }

    /// @notice View reward ratio for the current condition.
    function getRewardRatio() public view returns (uint256[] memory _numerator, uint256[] memory _denominator, uint256[] memory _rewardRatioAmount) {
        _numerator = stakingConditions[nextConditionId - 1].rewardRatioNumerator;
        _denominator = stakingConditions[nextConditionId - 1].rewardRatioDenominator;
        _rewardRatioAmount = stakingConditions[nextConditionId - 1].rewardRatioAmount;
    }

    /// @notice View total rewards available in the staking contract.
    function getRewardTokenBalance() public view returns (uint256) {
        return rewardTokenBalance;
    }

    /// @notice View total rewards paid by the staking contract.
    function getTotalRewardPaid() public view returns (uint256) {
        return totalRewardPaid;
    }

    /// @notice View total coins staked in the staking contract.
    function getTotalCoinStaked() public view returns (uint256) {
        return totalCoinStaked;
    }

    /// @notice View current staker count in the staking contract.
    function getCurrentStakerCount() public view returns (uint) {
        return stakersArray.length;
    }

    /// @notice View total staker count in the staking contract.
    function getTotalStakerCount() public view returns (uint256) {
        return totalStakersCount;
    }

    /// @notice View minimum stake amount in the staking contract.
    function getMinStakeAmount() public view returns (uint256) {
        return minStakeAmount;
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice  Set lock time.
     *
     *  @param _newAmount    New locktime in seconds.
     */
    function _setLocktime(uint256 _newAmount) internal virtual {
        uint256 _oldAmount = locktime;
        locktime = _newAmount;

        emit UpdatedLocktime(_oldAmount, _newAmount);
    }

    /**
     *  @notice  Set minimum stake limit.
     *
     *  @param _newAmount    New minimum stake limit.
     */
    function _setMinStakeAmount(uint256 _newAmount) internal virtual {
        uint256 _oldAmount = minStakeAmount;
        minStakeAmount = _newAmount;

        emit UpdatedMinStakeAmount(_oldAmount, _newAmount);
    }

    /**
     *  @notice  Set time unit. Set as a number of seconds.
     *           Could be specified as -- x * 1 hours, x * 1 days, etc.
     *
     *  @param _timeUnit    New time unit.
     */
    function _setTimeUnit(uint80 _timeUnit) internal virtual {
        StakingCondition memory condition = stakingConditions[nextConditionId - 1];
        require(_timeUnit != condition.timeUnit, "Time-unit unchanged.");

        _setStakingCondition(_timeUnit, condition.rewardRatioNumerator, condition.rewardRatioDenominator, condition.rewardRatioAmount);

        emit UpdatedTimeUnit(condition.timeUnit, _timeUnit);
    }

    /**
     *  @notice  Set rewards per unit of time.
     *           Interpreted as (numerator/denominator) rewards per second/per day/etc based on time-unit.
     *
     *  @param _numerator    Reward ratio numerator.
     *  @param _denominator  Reward ratio denominator.
     *  @param _rewardRatioAmount  Reward ratio amount limit.
     */
    function _setRewardRatio(uint256[] memory _numerator, uint256[] memory _denominator, uint256[] memory _rewardRatioAmount) internal virtual {
        StakingCondition memory condition = stakingConditions[nextConditionId - 1];
        require(_numerator.length == _denominator.length && _denominator.length == _rewardRatioAmount.length, "Reward ratio mismatch");

        _setStakingCondition(condition.timeUnit, _numerator, _denominator, _rewardRatioAmount);

        emit UpdatedRewardRatio(
            condition.rewardRatioNumerator,
            _numerator,
            condition.rewardRatioDenominator,
            _denominator,
            condition.rewardRatioAmount,
            _rewardRatioAmount
        );
    }

    /// @dev Staking logic.
    function _stake(uint256 _amount) internal virtual returns (bool) {
        require(_amount != 0, "Staking 0 tokens");
        require(msg.value == 0, "Value not 0");
        require(_amount >= minStakeAmount, "Minimum stake limit not reached");

        if (!stakers[_stakeMsgSender()].stakedBefore) {
            stakers[_stakeMsgSender()].stakedBefore = true;
            totalStakersCount += 1;
        }

        if (stakers[_stakeMsgSender()].amountStaked > 0 || _checkLockedCoins(_stakeMsgSender()) == true) {
            _updateUnclaimedRewardsForStaker(_stakeMsgSender());
        } else {
            stakersArray.push(_stakeMsgSender());
            stakers[_stakeMsgSender()].timeOfLastUpdate = uint80(block.timestamp);
            stakers[_stakeMsgSender()].conditionIdOflastUpdate = nextConditionId - 1;
        }

        uint256 balanceBefore = IERC20(stakingToken).balanceOf(address(this));

        uint256 ourAllowance = IERC20(stakingToken).allowance(_stakeMsgSender(), address(this));
        require(_amount <= ourAllowance, 'Not enough allowance');
        bool success = IERC20(stakingToken).transferFrom(_stakeMsgSender(), address(this), _amount);
        require(success, 'Token transfer failed');

        uint256 actualAmount = IERC20(stakingToken).balanceOf(address(this)) - balanceBefore;

        stakers[_stakeMsgSender()].lockedCoins.push(LockedDeposits(actualAmount, block.timestamp + locktime));
        stakingTokenBalance += actualAmount;
        totalCoinStaked += actualAmount;

        emit TokensStaked(_stakeMsgSender(), actualAmount);
        return true;
    }

    /// @dev Withdraw logic.
    function _withdraw(uint256 _amount) internal virtual returns (bool) {
        require(_amount != 0, "Withdrawing 0 tokens");

        _updateUnclaimedRewardsForStaker(_stakeMsgSender());
        uint256 _amountStaked = stakers[_stakeMsgSender()].amountStaked;

        require(_amountStaked >= _amount, "Withdrawing more than staked");

        if (_amountStaked == _amount && _checkLockedCoins(_stakeMsgSender()) == false) {
            address[] memory _stakersArray = stakersArray;
            for (uint256 i = 0; i < _stakersArray.length; ++i) {
                if (_stakersArray[i] == _stakeMsgSender()) {
                    stakersArray[i] = _stakersArray[_stakersArray.length - 1];
                    stakersArray.pop();
                    break;
                }
            }
        }

        stakers[_stakeMsgSender()].amountStaked -= _amount;
        stakingTokenBalance -= _amount;

        bool success = IERC20(stakingToken).transfer(_stakeMsgSender(), _amount);
        require(success, "Token transfer failed");

        emit TokensWithdrawn(_stakeMsgSender(), _amount);
        return true;
    }

    /// @dev Logic for claiming rewards.
    function _claimRewards() internal virtual returns (bool) {
        uint256 rewards = stakers[_stakeMsgSender()].unclaimedRewards + _calculateRewards(_stakeMsgSender());

        require(rewards != 0, "No rewards");
        require(rewards <= rewardTokenBalance, "Not enough reward tokens to claim");
        rewardTokenBalance -= rewards;

        _updateLockedCoins(_stakeMsgSender());
        stakers[_stakeMsgSender()].timeOfLastUpdate = uint80(block.timestamp);
        stakers[_stakeMsgSender()].unclaimedRewards = 0;
        stakers[_stakeMsgSender()].conditionIdOflastUpdate = nextConditionId - 1;

        bool success = IERC20(stakingToken).transfer(_stakeMsgSender(), rewards);
        require(success, "Token transfer failed");

        totalRewardPaid += rewards;
        stakers[_stakeMsgSender()].totalEarnedRewards += rewards;

        emit RewardsClaimed(_stakeMsgSender(), rewards);
        return true;
    }

    /// @dev View available rewards for a user.
    function _availableRewards(address _staker) internal view virtual returns (uint256 _rewards) {
        if (stakers[_staker].amountStaked == 0 && _getUnlockedCoinAmount(_staker) == 0) {
            _rewards = stakers[_staker].unclaimedRewards;
        } else {
            _rewards = stakers[_staker].unclaimedRewards + _calculateRewards(_staker);
        }
    }

    /// @dev Update unclaimed rewards for a users. Called for every state change for a user.
    function _updateUnclaimedRewardsForStaker(address _staker) internal virtual {
        _updateLockedCoins(_staker);
        uint256 rewards = _calculateRewards(_staker);
        stakers[_staker].unclaimedRewards += rewards;
        stakers[_staker].timeOfLastUpdate = uint80(block.timestamp);
        stakers[_staker].conditionIdOflastUpdate = nextConditionId - 1;
    }

    /// @dev Update locked coins for users. Called for every state change for a user.
    function _updateLockedCoins(address _staker) internal virtual {
        for (uint256 j = 0; j < stakers[_staker].lockedCoins.length; j++) {
            if (block.timestamp >= stakers[_staker].lockedCoins[j].lockedUntilTime && stakers[_staker].lockedCoins[j].lockedUntilTime != 0) {
                stakers[_staker].amountStaked += stakers[_staker].lockedCoins[j].amountDeposited;
                delete stakers[_staker].lockedCoins[j];
            }
        }
    }

    /// @dev Set staking conditions.
    function _setStakingCondition(uint80 _timeUnit, uint256[] memory _numerator, uint256[] memory _denominator, uint256[] memory _rewardRatioAmount) internal virtual {
        require(
            _numerator.length != 0 || _denominator.length != 0 || _rewardRatioAmount.length != 0,
            "Numerator, denominator or amount data is missing"
        );
        require(_timeUnit != 0, "time-unit can't be 0");
        uint256 conditionId = nextConditionId;
        nextConditionId += 1;

        stakingConditions[conditionId] = StakingCondition({
            timeUnit: _timeUnit,
            rewardRatioNumerator: _numerator,
            rewardRatioDenominator: _denominator,
            rewardRatioAmount: _rewardRatioAmount,
            startTimestamp: uint80(block.timestamp),
            endTimestamp: 0
        });

        if (conditionId > 0) {
            stakingConditions[conditionId - 1].endTimestamp = uint80(block.timestamp);
        }
    }

    /// @dev Check if staker has locked coins.
    function _checkLockedCoins(address _staker) internal view returns (bool) {
        Staker memory staker = stakers[_staker];
        bool lockedCoinAvailable = false;
    
        for (uint256 j = 0; j < staker.lockedCoins.length; j++) {
            if (staker.lockedCoins[j].lockedUntilTime != 0) {
                lockedCoinAvailable = true;
                break;
            }
        }

        return lockedCoinAvailable;
    }

    /// @dev Get Numerator and denominator based on stakers staked amount.
    function _calculateStakerRatio(address _staker, StakingCondition memory _condition, uint256 _freedCoins) internal view virtual returns (uint) {
        uint _stakerRatio = 0;
        for (uint i = _condition.rewardRatioAmount.length; i > 0; i--) {
            if (stakers[_staker].amountStaked + _freedCoins >= _condition.rewardRatioAmount[i - 1]) {
                _stakerRatio = i - 1;
                break;
            }
        }
        return _stakerRatio;
    }

    /// @dev Calculate unlocked coins for a staker.
    function _getUnlockedCoinAmount(address _staker) internal view returns (uint256) {
        Staker memory staker = stakers[_staker];
        uint256 unlockedCoinAmount = 0;
    
        for (uint256 j = 0; j < staker.lockedCoins.length; j++) {
            if (block.timestamp >= staker.lockedCoins[j].lockedUntilTime && staker.lockedCoins[j].lockedUntilTime != 0) {
                unlockedCoinAmount += staker.lockedCoins[j].amountDeposited;
            }
        }

        return unlockedCoinAmount;
    }

    /// @dev Calculate rewards for a staker.
    function _calculateRewards(address _staker) internal view virtual returns (uint256 _rewards) {
        Staker memory staker = stakers[_staker];

        uint256 _stakerConditionId = staker.conditionIdOflastUpdate;
        uint256 _nextConditionId = nextConditionId;

        uint256 unlockedCoinAmount = _getUnlockedCoinAmount(_staker);

        for (uint256 i = _stakerConditionId; i < _nextConditionId; i += 1) {
            StakingCondition memory condition = stakingConditions[i];
            uint stakerRatio = _calculateStakerRatio(_staker, condition, unlockedCoinAmount);

            uint256 startTime = i != _stakerConditionId ? condition.startTimestamp : staker.timeOfLastUpdate;
            uint256 endTime = condition.endTimestamp != 0 ? condition.endTimestamp : block.timestamp;

            (bool noOverflowProduct, uint256 rewardsProduct) = SafeMath.tryMul(
                (endTime - startTime) * (staker.amountStaked + unlockedCoinAmount),
                condition.rewardRatioNumerator[stakerRatio]
            );
            (bool noOverflowSum, uint256 rewardsSum) = SafeMath.tryAdd(
                _rewards,
                (rewardsProduct / condition.timeUnit) / condition.rewardRatioDenominator[stakerRatio]
            );

            _rewards = noOverflowProduct && noOverflowSum ? rewardsSum : _rewards;
        }

        (, _rewards) = SafeMath.tryMul(_rewards, 10 ** stakingTokenDecimals);

        _rewards /= (10 ** stakingTokenDecimals);
    }

    /// @dev Exposes the ability to override the msg sender
    function _stakeMsgSender() internal virtual returns (address) {
        return msg.sender;
    }
}