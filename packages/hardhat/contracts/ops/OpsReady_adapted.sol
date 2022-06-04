// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// this contract come from https://github.com/gelatodigital/ops/blob/master/contracts/vendor/gelato/OpsReady.sol
// just adapted it because Spouf contract doesn't support a constructor because it's a proxy

import {
    SafeERC20Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IOps {
    function gelato() external view returns (address payable);

    function getFeeDetails() external view returns (uint256, address);
}

abstract contract OpsReady {
    address public ops;
    address payable public gelato;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier onlyOps() {
        require(msg.sender == ops, "OpsReady: onlyOps");
        _;
    }

    // constructor(address _ops) {
    //     ops = _ops;
    //     gelato = IOps(_ops).gelato();
    // }

    function _transfer(uint256 _amount, address _paymentToken) internal {
        if (_paymentToken == ETH) {
            (bool success, ) = gelato.call{value: _amount}("");
            require(success, "_transfer: ETH transfer failed");
        } else {
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_paymentToken), gelato, _amount);
        }
    }
}
