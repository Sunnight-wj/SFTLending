// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../types/DataTypes.sol";
import "../../helper/WadRayMath.sol";
import "../../helper/PercentageMath.sol";

library GenericLogic {
    using SafeMath for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;


  /**
   * @dev Calculates the health factor
   * @param totalCollateral The total collateral in ETH
   * @param totalDebt The total debt in ETH
   * @param liquidationThreshold The liquidation threshold
   * @return The health factor calculated from the balances provided
   **/
  function calculateHealthFactor(
    uint256 totalCollateral,
    uint256 totalDebt,
    uint256 liquidationThreshold
  ) internal pure returns (uint256) {
    if (totalDebt == 0) return type(uint256).max;

    return (totalCollateral.percentMul(liquidationThreshold)).wadDiv(totalDebt);
  }


  /**
   * @dev Calculates the equivalent amount in ETH that an user can borrow, depending on the available collateral and the
   * average Loan To Value
   * @param totalCollateral The total SFT amount as collateral
   * @param totalDebt The total borrow balance
   * @param ltv The loan to value
   * @return the amount available FIL to borrow for the user
   **/
  function calculateAvailableBorrow(
    uint256 totalCollateral,
    uint256 totalDebt,
    uint256 ltv
  ) external pure returns (uint256) {
    uint256 availableBorrows = totalCollateral.percentMul(ltv);

    if (availableBorrows < totalDebt) {
      return 0;
    }

    availableBorrows = availableBorrows.sub(totalDebt);
    return availableBorrows;
  }
}