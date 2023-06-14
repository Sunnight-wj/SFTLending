// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IScaledBalanceToken.sol";

interface IVariableDebtToken is IScaledBalanceToken {
  /**
   * @dev Emitted after the mint action
   * @param user The address performing the mint
   * @param value The amount to be minted
   * @param index The last index of the reserve
   **/
  event Mint(address indexed user, uint256 value, uint256 index);

  /**
   * @dev Mints debt token to the `onBehalfOf` address
   * @param user The address receiving the borrowed underlying and the debt token
   * @param amount The amount of debt being minted
   * @param index The variable debt index of the reserve
   **/
  function mint(
    address user,
    uint256 amount,
    uint256 index
  ) external;

  /**
   * @dev Emitted when variable debt is burnt
   * @param user The user which debt has been burned
   * @param amount The amount of debt being burned
   * @param index The index of the user
   **/
  event Burn(address indexed user, uint256 amount, uint256 index);

  /**
   * @dev Burns user variable debt
   * @param user The user which debt is burnt
   * @param index The variable debt index of the reserve
   **/
  function burn(
    address user,
    uint256 amount,
    uint256 index
  ) external;
}