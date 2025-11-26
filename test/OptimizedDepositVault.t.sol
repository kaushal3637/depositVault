// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OptimizedDepositVault.sol";

contract OptimizedDepositVaultTest is Test {
    OptimizedDepositVault public vault;
    address public user = address(0x123);

    function setUp() public {
        vault = new OptimizedDepositVault();
        vm.deal(user, 100 ether);
    }

    function testNormalDeposit() public {
        vm.startPrank(user);
        (bool success, ) = address(vault).call{value: 0.5 ether}("");
        require(success, "Deposit failed");

        (uint128 balance, uint64 lastBlock, uint64 blockDeposit) = vault.ledger(
            user
        );
        assertEq(balance, 0.5 ether);
        assertEq(lastBlock, block.number);
        assertEq(blockDeposit, 0.5 ether);
        vm.stopPrank();
    }

    function testDepositCapRefund() public {
        vm.startPrank(user);
        uint256 initialBalance = user.balance;

        // Deposit 1.5 ETH. Should accept 1 ETH, refund 0.5 ETH.
        (bool success, ) = address(vault).call{value: 1.5 ether}("");
        require(success, "Deposit failed");

        (uint128 balance, , uint64 blockDeposit) = vault.ledger(user);
        assertEq(balance, 1 ether);
        assertEq(blockDeposit, 1 ether);

        // Balance should be Initial - 1.5 + 0.5 = Initial - 1
        assertEq(user.balance, initialBalance - 1 ether);
        vm.stopPrank();
    }

    function testMultipleDepositsInBlock() public {
        vm.startPrank(user);

        // Deposit 0.6 ETH
        (bool success, ) = address(vault).call{value: 0.6 ether}("");
        require(success);

        // Deposit 0.5 ETH. Should accept 0.4, refund 0.1.
        uint256 balanceBefore = user.balance;
        (success, ) = address(vault).call{value: 0.5 ether}("");
        require(success);

        (uint128 balance, , uint64 blockDeposit) = vault.ledger(user);
        assertEq(balance, 1 ether);
        assertEq(blockDeposit, 1 ether);

        // Spent 0.5, got 0.1 back. Net spent 0.4.
        assertEq(user.balance, balanceBefore - 0.4 ether);
        vm.stopPrank();
    }

    function testNewBlockReset() public {
        vm.startPrank(user);
        (bool success, ) = address(vault).call{value: 1 ether}("");
        require(success);

        vm.roll(block.number + 1);

        // New block, can deposit another 1 ETH
        (success, ) = address(vault).call{value: 1 ether}("");
        require(success);

        (uint128 balance, uint64 lastBlock, uint64 blockDeposit) = vault.ledger(
            user
        );
        assertEq(balance, 2 ether); // Total balance accumulates
        assertEq(lastBlock, block.number);
        assertEq(blockDeposit, 1 ether); // Current block deposit is 1

        vm.stopPrank();
    }
}
