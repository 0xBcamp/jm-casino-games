// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import { Test, console2 } from "forge-std/Test.sol";
// import { SimpleVRFContract } from "../../src/SimpleVRFContract.sol";

// contract TestSimpleVRFContract is Test {
//     SimpleVRFContract vrfConsumer;
//     address operator;
//     address owner;
//     address nobody;

//     event RandomnessRequested(uint64 requestId);
//     event RandomnessFulfilled(uint256 indexed nonce, SimpleVRFContract.Request request);

//     function setUp() public {
//         operator = address(1);
//         owner = address(2);
//         nobody = address(3);

//         vm.startPrank(owner);
//         vrfConsumer = new SimpleVRFContract(operator);
//         vm.stopPrank();

//         // Set the block timestamp for consistency in tests
//         vm.warp(1_700_819_134);
//     }

//     function testRequestRandomness() public {
//         bytes memory data = abi.encode(address(this));

//         // Expect the RandomnessRequested event
//         vm.expectEmit(true, true, true, true);
//         emit RandomnessRequested(0); // Expecting initial requestId to be 0

//         vm.prank(owner);
//         vrfConsumer.requestRandomness(data);

//         // Verify that lastRequestId is updated correctly
//         assertEq(vrfConsumer.lastRequestId(), 0);
//     }

//     function testFulfillRandomness() public {
//         // Create expected Request object
//         uint256 randomness = 0x471403f3a8764edd4d39c7748847c07098c05e5a16ed7b083b655dbab9809fae;
//         uint256 requestId = 0;
//         uint256 roundId = 2_671_924;
//         bytes memory data = abi.encode(address(this));
//         bytes memory dataWithRound = abi.encode(roundId, abi.encode(requestId, data));

//         vm.prank(owner);
//         vrfConsumer.requestRandomness(data);

//         // Call fulfillRandomness as operator
//         vm.prank(operator);
//         vrfConsumer.fulfillRandomness(randomness, dataWithRound);

//         // Verify that the request is stored correctly
//         // Retrieve and verify the stored request
//         (
//             uint256 requestTime,
//             uint256 requestBlock,
//             uint256 fulfilledTime,
//             uint256 fulfilledBlock,
//             uint256 storedRandomness
//         ) = vrfConsumer.requests(requestId);

//         assertEq(requestTime, 1_700_819_134); // 1700819134 is the block timestamp that was set in the setUp function
//         assertEq(requestBlock, 1); // The block number of the request is 1
//         assertEq(fulfilledTime, 1_700_819_134); // 1700819134 is the block timestamp that was set in the setUp
// function
//     }
// }
