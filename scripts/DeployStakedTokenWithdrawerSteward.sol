// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EthereumScript} from "solidity-utils/contracts/utils/ScriptUtils.sol";
import {StakedTokenWithdrawerSteward} from "src/asset-manager/stmatic-withdrawer/StakedTokenWithdrawerSteward.sol";

contract DeployEthereum is EthereumScript {
    function run() external broadcast {
        new StakedTokenWithdrawerSteward();
    }
}
