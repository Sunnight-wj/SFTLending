// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../types/DataTypes.sol";
import "./logic/ReserveLogic.sol";
import "../interfaces/ISFilToken.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IVariableDebtToken.sol";
import "./logic/GenericLogic.sol";
import "../helper/PercentageMath.sol";


contract LendingPool is ILendingPool, Ownable2StepUpgradeable {
    using ReserveLogic for DataTypes.ReserveData;
    using SafeERC20 for IERC20;
    using PercentageMath for uint256;

    address public filToken;
    address public sftToken;
    address public distributor;
    DataTypes.ReserveData public reserve;
    mapping (address => uint) public pledges; // address => SFT amount
    mapping (address => uint) public rewards; // plege SFT also can earn rewards

    function initialize(
        address _filToken,
        address _sftToken,
        address _distributor,
        address _sFilTokenAddress,
        address _variableDebtTokenAddress,
        address _interestRateStrategyAddress,
        uint16 _reserveFactor,
        uint16 _ltv,
        uint16 _liquidationThreshold
        ) external initializer {
        require(address(_filToken) != address(0), "fil token address cannot be zero");
        require(address(_sftToken) != address(0), "SFT token address cannot be zero");
        require(address(_sFilTokenAddress) != address(0), "sFil token address cannot be zero");
        require(address(_variableDebtTokenAddress) != address(0), "variableDebt token address cannot be zero");
        require(address(_interestRateStrategyAddress) != address(0), "interestRateStrategy address cannot be zero");
        __Context_init_unchained();
        __Ownable_init_unchained();
        filToken = _filToken;
        sftToken = _sftToken;
        _setDistributor(_distributor);
        reserve.sFilTokenAddress = _sFilTokenAddress;
        reserve.variableDebtTokenAddress = _variableDebtTokenAddress;
        reserve.interestRateStrategyAddress = _interestRateStrategyAddress;
        reserve.reserveFactor = _reserveFactor;
        reserve.ltv = _ltv;
        reserve.liquidationThreshold = _liquidationThreshold;
    }

    function setDistributor(address newDistributor) external onlyOwner {
        _setDistributor(newDistributor);
    }

    function _setDistributor(address _distributor) private {
        emit SetDistributor(distributor, _distributor);
        distributor = _distributor;
    }

    function setReserveFactor(uint16 newReserveFactor) external onlyOwner {
        _setReserveFactor(newReserveFactor);
    }

    function _setReserveFactor(uint16 _reserveFactor) private {
        emit SetReserveFactor(reserve.reserveFactor, _reserveFactor);
        reserve.reserveFactor = _reserveFactor;
    }

    function setInterestRateStrategyAddress(address newInterestRateStrategyAddress) external onlyOwner {
        _setInterestRateStrategyAddress(newInterestRateStrategyAddress);
    }

    function _setInterestRateStrategyAddress(address _interestRateStrategyAddress) private {
        emit SetInterestRateStrategyAddress(reserve.interestRateStrategyAddress, _interestRateStrategyAddress);
        reserve.interestRateStrategyAddress = _interestRateStrategyAddress;
    }

    function updateTreasuryAddress(address newTreasuryAddress) external onlyOwner {
        ISFilToken(reserve.sFilTokenAddress).updateTreasuryAddress(newTreasuryAddress);
    }

    function getReserveData() public view returns (DataTypes.ReserveData memory) {
        return reserve;
    }

    function getUserAccountData(address user) public view returns (
        uint totalCollateral,
        uint totalDebt,
        uint availableBorrows,
        uint healthFactor
    ) {
        totalCollateral = pledges[user];
        totalDebt = IERC20(reserve.variableDebtTokenAddress).balanceOf(user);
        availableBorrows = GenericLogic.calculateAvailableBorrow(totalCollateral, totalDebt, reserve.ltv);
        healthFactor = GenericLogic.calculateHealthFactor(totalCollateral, totalDebt, reserve.liquidationThreshold);
    }


    /**
     * @dev Deposits an `amount` of FIL into the reserve, receiving equivalent sFIL in return.
     * @param amount The amount to be deposited
     * @param onBehalfOf The address that will receive the sFIL, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of sFIL
     *   is a different wallet
     **/
    function deposit(uint amount, address onBehalfOf) external {
        address sFilToken = reserve.sFilTokenAddress;
        reserve.updateState();
        reserve.updateInterestRates(filToken, sFilToken, amount, 0);
        IERC20(filToken).safeTransferFrom(address(msg.sender), sFilToken, amount);
        ISFilToken(sFilToken).mint(onBehalfOf, amount, reserve.liquidityIndex);
        emit Deposit(msg.sender, onBehalfOf, amount);
    }

    /**
     * @dev Withdraws an `amount` of FIL from the reserve, burning the equivalent sFIL owned
     * @param amount The FIL amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to Address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     **/
    function withdraw(uint amount, address to) external returns (uint) {
        address sFilToken = reserve.sFilTokenAddress;
        uint userBalance = ISFilToken(sFilToken).balanceOf(address(msg.sender));
        require(amount <= userBalance, "NOT_ENOUGH_AVAILABLE_USER_BALANCE");
        uint256 amountToWithdraw = amount;
        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        reserve.updateState();
        reserve.updateInterestRates(filToken, sFilToken, 0, amountToWithdraw);
        ISFilToken(sFilToken).burn(address(msg.sender), to, amountToWithdraw, reserve.liquidityIndex);
        emit Withdraw(msg.sender, to, amountToWithdraw);
        return amountToWithdraw;
    }

    /**
     * @dev pledge an `amount` of SFT for borrowing FIL from the pool
     * @param amount The amount of SFT
     * @param onBehalfOf The address that will receive the SFT as collateral,same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary is a different wallet
     */
    function pledge(uint amount, address onBehalfOf) external {
        require(IERC20(sftToken).allowance(address(msg.sender), address(this)) >= amount, "SFT_APPROVE_NOT_ENOUGH");
        require(IERC20(sftToken).balanceOf(address(msg.sender)) >= amount, "SFT_BALANCE_NOT_ENOUGH");
        IERC20(sftToken).safeTransferFrom(address(msg.sender), address(this), amount);
        pledges[onBehalfOf] += amount;
        emit Pledge(msg.sender, onBehalfOf, amount);
    }

    /**
     * @dev unpledge an `amount` of SFT from the pool
     * @param amount The amount of SFT
     */
    function unpledge(uint amount) external {
        require(amount <= pledges[msg.sender], "UNPLEDGE_AMOUNT_NOT_ENOUGH");
        uint totalCollateral = pledges[msg.sender] - amount;
        uint totalDebt = IERC20(reserve.variableDebtTokenAddress).balanceOf(address(msg.sender));
        require(totalCollateral.percentMul(reserve.ltv) >= totalDebt, "INVALID_AMOUNT");
        pledges[msg.sender] -= amount;
        IERC20(sftToken).safeTransfer(address(msg.sender), amount);
        emit Unpledge(msg.sender, amount);
    }

    /**
     * @dev Allows users to borrow a specific `amount` of FIL, provided that the borrower already deposited enough collateral
     * @param amount The amount to be borrowed
     **/
    function borrow(uint amount) external {
        (, ,uint availableBorrows,) = getUserAccountData(address(msg.sender));
        require(availableBorrows >= amount, "AVAILABLE_BORROWS_NOT_ENOUGH");
        reserve.updateState();
        IVariableDebtToken(reserve.variableDebtTokenAddress).mint(address(msg.sender), amount, reserve.variableBorrowIndex);
        reserve.updateInterestRates(filToken, reserve.sFilTokenAddress, 0, amount);
        ISFilToken(reserve.sFilTokenAddress).transferUnderlyingTo(address(msg.sender), amount);
        emit Borrow(msg.sender, amount, reserve.currentVariableBorrowRate);
    }

    /**
     * @notice Repays a borrowed `amount` of FIL, burning the equivalent debt tokens owned
     * @param amount The amount to repay
     * - Send the value type(uint256).max in order to repay the whole debt
     * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
     * user calling the function if he wants to reduce/remove his own debt, or the address of any other
     * other borrower whose debt should be removed
     * @return The final amount repaid
     **/
    function repay(uint amount, address onBehalfOf) public returns (uint) {
        
        uint256 margin = 0; // user actual need transfered FIL amount
        uint256 userDebt = IERC20(reserve.variableDebtTokenAddress).balanceOf(onBehalfOf);
        uint256 userRewards = rewards[address(msg.sender)];
        uint paybackAmount = amount < userDebt? amount : userDebt;
        uint256 rewardsToRepay = userRewards >= paybackAmount? paybackAmount : userRewards;
        margin = paybackAmount - rewardsToRepay;
        
        require(IERC20(filToken).allowance(address(msg.sender), address(this)) >= margin, "FIL_ALLOWANCE_NOT_ENOUGH");
        require(IERC20(filToken).balanceOf(address(msg.sender)) >= margin, "FIL_BALANCE_NOT_ENOUGH");
        reserve.updateState();
        IVariableDebtToken(reserve.variableDebtTokenAddress).burn(onBehalfOf, paybackAmount, reserve.variableBorrowIndex);
        address sFILToken = reserve.sFilTokenAddress;
        reserve.updateInterestRates(filToken, sFILToken, paybackAmount, 0);
        IERC20(filToken).safeTransferFrom(msg.sender, reserve.sFilTokenAddress, margin);
        rewards[msg.sender] -= rewardsToRepay;
        IERC20(filToken).safeTransfer(reserve.sFilTokenAddress, rewardsToRepay);
        emit Repay(msg.sender, onBehalfOf, paybackAmount, rewardsToRepay, margin);
        return paybackAmount;
    }

   /**
    * @dev Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
    * @param user The address of the borrower getting liquidated
    * to receive the underlying collateral asset directly
    **/    
    function liquidate(address user) external {
        ( ,uint totalDebt, ,uint healthFactor) = getUserAccountData(user);
        require(
            healthFactor < GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            "HEALTH_FACTOR_ABOVE_THRESHOLD"
        );
        repay(totalDebt, user);
        IERC20(sftToken).transfer(address(msg.sender), pledges[user]);
        delete pledges[user];
        emit Liquidate(msg.sender, user, totalDebt, pledges[user]);
    }

    function distributeReward(address[] calldata userList, uint[] calldata rewardList, uint totalRewards) external {
        require(address(msg.sender) == distributor, "ONLY_DISTRIBUTOR_CAN_CALL");
        require(userList.length == rewardList.length, "INCORRECT_PARAM");
        require(IERC20(filToken).allowance(address(msg.sender), address(this)) >= totalRewards, "FIL_TOKEN_APPROVE_NOT_ENOUGH");
        require(IERC20(filToken).balanceOf(address(msg.sender)) >= totalRewards, "FIL_TOKEN_BALANCE_NOT_ENOUGH");
        for (uint i = 0; i < userList.length; i++) {
            rewards[userList[i]] += rewardList[i];
            emit DistributeSingleReward(distributor, userList[i], rewardList[i]);
        }
        IERC20(filToken).safeTransferFrom(address(msg.sender), address(this), totalRewards);
    }

    function claimReward() external {
        require(pledges[msg.sender] == 0, "MUST_UNPLEGE_ALL_COLLATERAL");
        uint claimAmount = rewards[msg.sender];
        require(IERC20(filToken).balanceOf(address(this)) >= claimAmount);
        delete rewards[msg.sender];
        IERC20(filToken).safeTransfer(address(msg.sender), claimAmount);
        emit ClaimReward(msg.sender, claimAmount);
    }

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome() external view returns (uint256) {
    return reserve.getNormalizedIncome();
  }

  /**
   * @dev Returns the normalized variable debt per unit of FIL
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt() external view returns (uint256) {
    return reserve.getNormalizedDebt();
  }
}