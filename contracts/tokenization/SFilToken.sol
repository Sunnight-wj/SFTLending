// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./base/BaseERC20.sol";
import "../helper/WadRayMath.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/ISFilToken.sol";

contract SFilToken is Initializable, BaseERC20('ERC20_IMPL', 'ERC20_IMPL'), ISFilToken {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    ILendingPool internal _pool;
    address internal _treasury;
    address internal _underlyingAsset;

    modifier onlyLendingPool {
    require(_msgSender() == address(_pool), "CALLER_MUST_BE_LENDING_POOL");
    _;
  }

  function initialize(
    ILendingPool pool,
    address treasury,
    address underlyingAsset,
    string calldata tokenName, 
    string calldata tokenSymbol
  ) external initializer {
    _pool = pool;
    _treasury = treasury;
    _underlyingAsset = underlyingAsset;
    _setName(tokenName);
    _setSymbol(tokenSymbol);
  }

  function updateTreasuryAddress(address newTreasuryAddress) external onlyLendingPool {
    _treasury = newTreasuryAddress;
  }

  /**
   * @dev Calculates the balance of the user: principal balance + interest generated by the principal
   * @param user The user whose balance is calculated
   * @return The balance of the user
   **/
  function balanceOf(address user)
    public
    view
    override(BaseERC20, IERC20)
    returns (uint256)
  {
    return super.balanceOf(user).rayMul(_pool.getReserveNormalizedIncome());
  }

  /**
   * @dev calculates the total supply of sFIL
   * since the balance of every single user increases over time, the total supply
   * does that too.
   * @return the current total supply
   **/
  function totalSupply() public view override(BaseERC20, IERC20) returns (uint256) {
    uint256 currentSupplyScaled = super.totalSupply();

    if (currentSupplyScaled == 0) {
      return 0;
    }

    return currentSupplyScaled.rayMul(_pool.getReserveNormalizedIncome());
  }

  /**
   * @dev Burns sFIL from `user` and sends the equivalent amount of FIL to `receiverOfUnderlying`
   * - Only callable by the LendingPool, as extra state updates there need to be managed
   * @param user The owner of the sFIL, getting them burned
   * @param receiver The address that will receive the FIL
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  function burn(
    address user,
    address receiver,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool {
    uint256 amountScaled = amount.rayDiv(index);
    _burn(user, amountScaled);

    IERC20(_underlyingAsset).safeTransfer(receiver, amount);

    emit Transfer(user, address(0), amount);
    emit Burn(user, receiver, amount, index);
  }


  /**
   * @dev Mints `amount` sFIL to `user`
   * - Only callable by the LendingPool, as extra state updates there need to be managed
   * @param user The address receiving the minted tokens
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   */
  function mint(
    address user,
    uint256 amount,
    uint256 index
  ) external override onlyLendingPool {

    uint256 amountScaled = amount.rayDiv(index);
    _mint(user, amountScaled);

    emit Transfer(address(0), user, amount);
    emit Mint(user, amount, index);
  }

  /**
   * @dev Mints sFIL to the reserve treasury
   * - Only callable by the LendingPool
   * @param amount The amount of tokens getting minted
   * @param index The new liquidity index of the reserve
   */
  function mintToTreasury(uint256 amount, uint256 index) external override onlyLendingPool {
    if (amount == 0) {
      return;
    }

    address treasury = _treasury;

    // Compared to the normal mint, we don't check for rounding errors.
    // The amount to mint can easily be very small since it is a fraction of the interest ccrued.
    // In that case, the treasury will experience a (very small) loss, but it
    // wont cause potentially valid transactions to fail.
    _mint(treasury, amount.rayDiv(index));

    emit Transfer(address(0), treasury, amount);
    emit Mint(treasury, amount, index);
  }


  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   **/
  function scaledBalanceOf(address user) external view override returns (uint256) {
    return super.balanceOf(user);
  }

  /**
   * @dev Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled balance and the scaled total supply
   **/
  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (super.balanceOf(user), super.totalSupply());
  }

  /**
   * @dev Returns the scaled total supply of the variable debt token. Represents sum(debt/index)
   * @return the scaled total supply
   **/
  function scaledTotalSupply() public view virtual override returns (uint256) {
    return super.totalSupply();
  }

  /**
   * @dev Returns the address of the Aave treasury, receiving the fees on sFIL
   **/
  function RESERVE_TREASURY_ADDRESS() public view returns (address) {
    return _treasury;
  }

  /**
   * @dev Returns the address of the underlying asset
   **/
  function UNDERLYING_ASSET_ADDRESS() public override view returns (address) {
    return _underlyingAsset;
  }

  /**
   * @dev Returns the address of the lending pool 
   **/
  function POOL() public view returns (ILendingPool) {
    return _pool;
  }

  /**
   * @dev Transfers the underlying asset to `target`. Used by the LendingPool to transfer
   * assets in borrow(), withdraw()
   * @param target The recipient of sFIL
   * @param amount The amount getting transferred
   * @return The amount transferred
   **/
  function transferUnderlyingTo(address target, uint256 amount)
    external
    override
    onlyLendingPool
    returns (uint256)
  {
    IERC20(_underlyingAsset).safeTransfer(target, amount);
    return amount;
  }

  /**
   * @dev Transfers the sFIL between two users. 
   * @param from The source address
   * @param to The destination address
   * @param amount The amount getting transferred
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    ILendingPool pool = _pool;

    uint256 index = pool.getReserveNormalizedIncome();

    super._transfer(from, to, amount.rayDiv(index));

    emit BalanceTransfer(from, to, amount, index);
  }
}