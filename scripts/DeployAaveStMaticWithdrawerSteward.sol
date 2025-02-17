// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EthereumScript} from "solidity-utils/contracts/utils/ScriptUtils.sol";
import {AaveStMaticWithdrawerSteward} from "src/asset-manager/stmatic-withdrawer/AaveStMaticWithdrawerSteward.sol";

contract DeployEthereum is EthereumScript {
    // https://etherscan.io/address/0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599
    address public constant ST_MATIC =
        0x9ee91F9f426fA633d227f7a9b000E28b9dfd8599;

    function run() external broadcast {
        bytes32 salt = "Aave StMatic Withdrawer";
        new AaveStMaticWithdrawerSteward{salt: salt}(ST_MATIC);
    }
}
