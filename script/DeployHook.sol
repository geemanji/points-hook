// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";
import "../src/PointsHook.sol";

contract DeployHook is Script {
    // CREATE2 Deployer Proxy — required for forge script deployments
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");

        // PointsHook only uses afterSwap, so only AFTER_SWAP_FLAG must be set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        // Mine a salt that makes the hook deploy to an address whose bottom 14 bits match flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER, flags, type(PointsHook).creationCode, abi.encode(IPoolManager(poolManager))
        );

        vm.startBroadcast(privateKey);

        PointsHook hook = new PointsHook{salt: salt}(IPoolManager(poolManager));
        require(address(hook) == hookAddress, "DeployHook: address mismatch");

        vm.stopBroadcast();
    }
}
