// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OptimizedDepositVault {
    // Pack variables to fit in a single storage slot (32 bytes)
    struct DepositInfo {
        uint128 balance; // User's total balance
        uint64 lastDepositBlock; // Block number of last deposit
        uint64 blockDeposit; // Amount deposited in the current block
    }

    uint256 constant PER_BLOCK_CAP = 1 ether;

    mapping(address => DepositInfo) public ledger;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event Refund(address indexed user, uint256 amount);

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address user, uint256 amount) internal {
        DepositInfo memory info = ledger[user];
        uint64 currentBlock = uint64(block.number);

        // Reset block deposit tracking if new block
        if (info.lastDepositBlock != currentBlock) {
            info.blockDeposit = 0;
            info.lastDepositBlock = currentBlock;
        }

        // Calculate how much can be deposited
        uint256 maxDeposit;
        unchecked {
            // Safe because blockDeposit is capped at PER_BLOCK_CAP (1e18) which fits in uint64
            // and we ensure it doesn't exceed PER_BLOCK_CAP below
            maxDeposit = PER_BLOCK_CAP - info.blockDeposit;
        }

        uint256 depositAmount = amount;
        uint256 refundAmount = 0;

        if (amount > maxDeposit) {
            unchecked {
                refundAmount = amount - maxDeposit;
            }
            depositAmount = maxDeposit;
        }

        // Update state
        unchecked {
            info.balance += uint128(depositAmount);
            info.blockDeposit += uint64(depositAmount);
        }

        // Write to storage
        ledger[user] = info;

        emit Deposit(user, depositAmount);

        // Refund excess
        if (refundAmount > 0) {
            emit Refund(user, refundAmount);
            (bool success, ) = user.call{value: refundAmount}("");
            require(success, "ETH_TRANSFER_FAIL");
        }
    }

    function withdraw(uint256 amount) external {
        DepositInfo memory info = ledger[msg.sender];
        require(info.balance >= amount, "NOT_ENOUGH_ETH");

        unchecked {
            info.balance -= uint128(amount);
        }

        ledger[msg.sender] = info;
        emit Withdrawal(msg.sender, amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAIL");
    }
}
