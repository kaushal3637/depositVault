//SPDX-License-Identifier: Unlicense

pragma solidity ^0.6.11;

import "forge-std/console.sol";

contract BlockDepositVault {
    uint256 immutable PER_BLOCK_CAP = 1 ether;

    struct DepositInfo {
        uint256 amount;
        uint256 depositedAtBlock;
    }

    mapping(address => DepositInfo) public ledger;

    constructor() public {}

    receive() external payable {
        require(msg.value <= PER_BLOCK_CAP, "TOO_MUCH_ETH");
        DepositInfo storage prev = ledger[tx.origin];
        uint256 maxDeposit = prev.depositedAtBlock == block.number
            ? PER_BLOCK_CAP - prev.amount
            : PER_BLOCK_CAP;
        console.log("maxDeposit", maxDeposit);
        console.log("prev.amount", prev.amount);
        console.log("block.number", block.number);
        console.log("prev.depositedAtBlock", prev.depositedAtBlock);
        console.log("tx.origin is:", tx.origin);
        if (msg.value > maxDeposit) {
            // refund user if they are above the max deposit allowed
            uint256 refundValue = msg.value - maxDeposit;
            (bool success, ) = msg.sender.call{value: refundValue}("");
            require(success, "ETH_TRANSFER_FAIL");

            prev.amount -= refundValue;
            console.log("After subtract prev.amount", prev.amount);
        }
        console.log("Before add prev.amount", prev.amount);
        prev.amount += msg.value;
        console.log("Final prev.amount", prev.amount);
        prev.depositedAtBlock = block.number;
    }

    function withdraw(uint256 amount) external {
        console.log("In withdraw(), tx.origin:", tx.origin);
        DepositInfo storage prev = ledger[tx.origin];
        console.log("In withdraw(), ledger[tx.origin].amount:", prev.amount);
        require(prev.amount >= amount, "NOT_ENOUGH_ETH");
        prev.amount -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH_TRANSFER_FAIL");
    }
}
