// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ILendingPool {

  /**
   * @dev Emitted on deposit()
   * @param user The address initiating the deposit
   * @param onBehalfOf The beneficiary of the deposit, receiving the sFIL
   * @param amount The amount deposited
   **/
  event Deposit(
    address user,
    address indexed onBehalfOf,
    uint amount
  );

  /**
   * @dev Deposits an `amount` of FIL into the reserve, receiving equivalent sFIL in return.
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the sFIL, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of sFIL
   *   is a different wallet
   **/
  function deposit(uint amount, address onBehalfOf) external;

  /**
   * @dev Emitted on withdraw()
   * @param user The address initiating the withdrawal, owner of sFIL
   * @param to Address that will receive the underlying
   * @param amount The amount to be withdrawn
   **/
  event Withdraw(address indexed user, address indexed to, uint amount);

  /**
   * @dev Withdraws an `amount` of FIL from the reserve, burning the equivalent sFIL owned
   * @param amount The FIL amount to be withdrawn
   *   - Send the value type(uint).max in order to withdraw the whole aToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   **/
  function withdraw(uint amount, address to) external returns (uint);

  /**
   * @dev Emitted on pledge()
   * @param user The address initiating the pledge
   * @param onBehalfOf The beneficiary of the pledge
   * @param amount The amount of SFT pledged
   **/
  event Pledge(address user, address indexed onBehalfOf, uint amount);

  /**
   * @dev pledge an `amount` of SFT for borrowing FIL from the pool
   * @param amount The amount of SFT
   * @param onBehalfOf The address that will receive the SFT as collateral,same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary is a different wallet
   */
  function pledge(uint amount, address onBehalfOf) external;

  /**
   * @dev Emitted on Unpledge()
   * @param user The address initiating the unpledge
   * @param amount The amount of SFT unpledged
   **/
  event Unpledge(address user, uint amount);

  /**
   * @dev unpledge an `amount` of SFT from the pool
   * @param amount The amount of SFT
   */
  function unpledge(uint amount) external;

  /**
   * @dev Emitted on borrow() when debt needs to be opened
   * @param user The address of the user initiating the borrow(), receiving the funds on borrow()
   * @param amount The amount borrowed out
   * @param borrowRate The numeric rate at which the user has borrowed
   **/
  event Borrow(
    address user,
    uint256 amount,
    uint256 borrowRate
  );

  /**
   * @dev Allows users to borrow a specific `amount` of FIL, provided that the borrower already deposited enough collateral
   * @param amount The amount to be borrowed
   **/
  function borrow(uint amount) external;

  /**
   * @dev Emitted on repay()
   * @param user The address of the user initiating the repay(), providing the funds
   * @param onBehalfOf The beneficiary of the repayment, getting his debt reduced
   * @param paybackAmount The amount repaid
   * @param rewardsToRepay The amount of rewards to cover debt
   * @param margin The amount of FIL user actually need transfer 
   **/
  event Repay(
    address indexed user,
    address indexed onBehalfOf,
    uint256 paybackAmount,
    uint256 rewardsToRepay,
    uint256 margin
  );


  /**
   * @notice Repays a borrowed `amount` of FIL, burning the equivalent debt tokens owned
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @return The final amount repaid
   **/
  function repay(uint amount, address onBehalfOf) external returns (uint);

/**
  * @dev Emitted on liquidate()
  * @param liquidator The address of the liquidator
  * @param user The address of the borrower getting liquidated
  * @param totalDebt The user's totalDebt that liquidator need to cover
  * @param totalCollteral The user's totalCollteral SFT liquidator will receive
  */
  event Liquidate(address liquidator, address indexed user, uint totalDebt, uint totalCollteral);

 /**
  * @dev Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
  * @param user The address of the borrower getting liquidated
  * to receive the underlying collateral asset directly
  **/    
  function liquidate(address user) external;

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome() external view returns (uint);

  /**
   * @dev Returns the normalized variable debt per unit of asset
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt() external view returns (uint);

  event DistributeSingleReward(address distributor, address user, uint amount);
  event ClaimReward(address user, uint amount);
  event SetDistributor(address oldDistributor, address newDistributor);
  event SetReserveFactor(uint16 oldReserveFactor, uint16 newReserveFactor);
  event SetInterestRateStrategyAddress(address oldInterestRateStrategyAddress, address newInterestRateStrategyAddress);
}