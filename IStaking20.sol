// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IStaking20 {
    /// @dev Emitted when tokens are staked.
    event TokensStaked(address indexed staker, uint256 amount);

    /// @dev Emitted when a tokens are withdrawn.
    event TokensWithdrawn(address indexed staker, uint256 amount);

    /// @dev Emitted when a staker claims staking rewards.
    event RewardsClaimed(address indexed staker, uint256 rewardAmount);

    /// @dev Emitted when contract admin updates timeUnit.
    event UpdatedTimeUnit(uint256 oldTimeUnit, uint256 newTimeUnit);

    /// @dev Emitted when contract admin updates rewardsPerUnitTime.
    event UpdatedRewardRatio(
        uint256[] oldNumerator,
        uint256[] newNumerator,
        uint256[] oldDenominator,
        uint256[] newDenominator,
        uint256[] oldRatioAmount,
        uint256[] newRatioAmount
    );

    /// @dev Emitted when contract admin updates minimum staking amount.
    event UpdatedMinStakeAmount(uint256 oldAmount, uint256 newAmount);

    /// @dev Emitted when contract admin updates locktime.
    event UpdatedLocktime(uint256 oldAmount, uint256 newAmount);

    /**
     *  @notice Staker Info.
     *
     *  @param amountStaked             Total number of tokens staked by the staker.
     *
     *  @param timeOfLastUpdate         Last reward-update timestamp.
     *
     *  @param unclaimedRewards         Rewards accumulated but not claimed by user yet.
     *
     *  @param conditionIdOflastUpdate  Condition-Id when rewards were last updated for user.
     */
    struct Staker {
        uint128 timeOfLastUpdate;
        uint64 conditionIdOflastUpdate;
        uint256 amountStaked;
        uint256 unclaimedRewards;
        uint256 totalEarnedRewards;
        LockedDeposits[] lockedCoins;
        bool stakedBefore;
    }

    struct LockedDeposits {
        uint256 amountDeposited;
        uint256 lockedUntilTime;
    }

    /**
     *  @notice Staking Condition.
     *
     *  @param timeUnit                 Unit of time specified in number of seconds. Can be set as 1 seconds, 1 days, 1 hours, etc.
     *
     *  @param rewardRatioNumerator     Rewards ratio is the number of reward tokens for a number of staked tokens,
     *                                  per unit of time.
     *
     *  @param rewardRatioDenominator   Rewards ratio is the number of reward tokens for a number of staked tokens,
     *                                  per unit of time.
     *
     *  @param startTimestamp           Condition start timestamp.
     *
     *  @param endTimestamp             Condition end timestamp.
     */
    struct StakingCondition {
        uint80 timeUnit;
        uint80 startTimestamp;
        uint80 endTimestamp;
        uint256[] rewardRatioNumerator;
        uint256[] rewardRatioDenominator;
        uint256[] rewardRatioAmount;
    }

    /**
     *  @notice Stake ERC721 Tokens.
     *
     *  @param amount    Amount to stake.
     */
    function stake(uint256 amount) external payable;

    /**
     *  @notice Withdraw staked tokens.
     *
     *  @param amount    Amount to withdraw.
     */
    function withdraw(uint256 amount) external;

    /**
     *  @notice Claim accumulated rewards.
     *
     */
    function claimRewards() external;

    /**
     *  @notice View amount staked, rewards and total rewards for a user.
     *
     *  @param staker    Address for which to calculated rewards.
     */
    function getStakeInfo(
        address staker
    )
        external
        view
        returns (
            uint256 _tokensStaked,
            uint256 _rewards,
            uint256 _totalRewards
        );
}