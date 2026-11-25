// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {PointsHook} from "../src/PointsHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

contract PointsHookTest is Test {
    PointsHook public hook;

    address public farmer = makeAddr("farmer");
    address public attacker = makeAddr("attacker");

    uint256 constant AGRI_POINTS_ID = 1;

    function setUp() public {
        IPoolManager manager = IPoolManager(address(0xBEEF));

        // Deploy at an address with the required afterSwap permission bit.
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(PointsHook).creationCode,
            abi.encode(manager)
        );

        hook = new PointsHook{salt: salt}(manager);

        assertEq(address(hook), hookAddress);
    }

    // 1. Authorised verifier can reward a farmer.

    function test_RewardVerifiedActivity() public {
        bytes32 activityId = keccak256("vaccination-001");

        hook.rewardVerifiedActivity(
            farmer,
            activityId,
            100
        );

        assertEq(hook.pendingRewards(farmer), 100);
        assertTrue(hook.processedActivities(activityId));
    }

    // 2. Unauthorised users cannot issue rewards.

    function test_RevertWhen_UnauthorizedVerifier() public {
        vm.prank(attacker);

        vm.expectRevert("Unauthorized");

        hook.rewardVerifiedActivity(
            farmer,
            keccak256("vaccination-002"),
            100
        );
    }

    // 3. Cannot reward the zero address.

    function test_RevertWhen_InvalidFarmer() public {
        vm.expectRevert("Invalid farmer");

        hook.rewardVerifiedActivity(
            address(0),
            keccak256("vaccination-003"),
            100
        );
    }

    // 4. Cannot issue zero points.

    function test_RevertWhen_ZeroPoints() public {
        vm.expectRevert("Invalid points");

        hook.rewardVerifiedActivity(
            farmer,
            keccak256("vaccination-004"),
            0
        );
    }

    // 5. Prevent duplicate agricultural activity rewards.

    function test_RevertWhen_ActivityAlreadyRewarded() public {
        bytes32 activityId = keccak256("vaccination-005");

        hook.rewardVerifiedActivity(farmer, activityId, 100);

        vm.expectRevert("Already rewarded");

        hook.rewardVerifiedActivity(farmer, activityId, 100);
    }

    // 6. Farmer can claim accumulated rewards.

    function test_ClaimRewards() public {
        bytes32 activityId = keccak256("inventory-update-001");

        hook.rewardVerifiedActivity(farmer, activityId, 250);

        vm.prank(farmer);
        hook.claimRewards();

        assertEq(
            hook.balanceOf(farmer, AGRI_POINTS_ID),
            250
        );

        assertEq(hook.pendingRewards(farmer), 0);
    }

    // 7. Farmer cannot claim when there are no pending rewards.

    function test_RevertWhen_NoRewardsAvailable() public {
        vm.prank(farmer);

        vm.expectRevert("No rewards available");

        hook.claimRewards();
    }

    // 8. Multiple activities accumulate before claiming.

    function test_MultipleActivitiesAccumulateRewards() public {
        hook.rewardVerifiedActivity(
            farmer,
            keccak256("animal-registration-001"),
            100
        );

        hook.rewardVerifiedActivity(
            farmer,
            keccak256("health-check-001"),
            200
        );

        hook.rewardVerifiedActivity(
            farmer,
            keccak256("inventory-update-001"),
            50
        );

        assertEq(hook.pendingRewards(farmer), 350);

        vm.prank(farmer);
        hook.claimRewards();

        assertEq(
            hook.balanceOf(farmer, AGRI_POINTS_ID),
            350
        );

        assertEq(hook.pendingRewards(farmer), 0);
    }
}