// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AaveV3Ethereum} from "aave-address-book/AaveV3Ethereum.sol";
import {AaveV3Arbitrum} from "aave-address-book/AaveV3Arbitrum.sol";
import {AaveV3Optimism} from "aave-address-book/AaveV3Optimism.sol";
import {AaveV3Polygon} from "aave-address-book/AaveV3Polygon.sol";
import {AaveV3Base} from "aave-address-book/AaveV3Base.sol";
import {
  ArbitrumScript,
  BaseScript,
  EthereumScript,
  OptimismScript,
  PolygonScript
} from "solidity-utils/contracts/utils/ScriptUtils.sol";
import {CctpBridgeSteward} from "src/bridges/cctp/CctpBridgeSteward.sol";
import {CctpConstants} from "src/bridges/cctp/CctpConstants.sol";

address constant TOKEN_LOGIC = 0x3765A685a401622C060E5D700D9ad89413363a91;
address constant GUARDIAN = 0x3765A685a401622C060E5D700D9ad89413363a91;
address constant RECEIVER = address(AaveV3Ethereum.COLLECTOR);
bytes32 constant SALT = "Aave CCTP Bridge";

contract DeployCctpBridgeArbitrum is ArbitrumScript {
  function run() external broadcast {
    new CctpBridgeSteward{salt: SALT}(
      CctpConstants.ARBITRUM_TOKEN_MESSENGER,
      CctpConstants.ARBITRUM_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Arbitrum.COLLECTOR),
      RECEIVER
    );
  }
}

contract DeployCctpBridgeOptimism is OptimismScript {
  function run() external broadcast {
    new CctpBridgeSteward{salt: SALT}(
      CctpConstants.OPTIMISM_TOKEN_MESSENGER,
      CctpConstants.OPTIMISM_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Optimism.COLLECTOR),
      RECEIVER
    );
  }
}

contract DeployCctpBridgePolygon is PolygonScript {
  function run() external broadcast {
    new CctpBridgeSteward{salt: SALT}(
      CctpConstants.POLYGON_TOKEN_MESSENGER,
      CctpConstants.POLYGON_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Polygon.COLLECTOR),
      RECEIVER
    );
  }
}

contract DeployCctpBridgeBase is BaseScript {
  function run() external broadcast {
    new CctpBridgeSteward{salt: SALT}(
      CctpConstants.BASE_TOKEN_MESSENGER,
      CctpConstants.BASE_USDC,
      TOKEN_LOGIC,
      GUARDIAN,
      address(AaveV3Base.COLLECTOR),
      RECEIVER
    );
  }
}
