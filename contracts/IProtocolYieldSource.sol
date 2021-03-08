// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;

import "./IYieldSource.sol";
import "./IReserve.sol";

interface ProtocolYieldSource is IYieldSource {

  /// @notice Sets the Reserve strategy on this contract
  /// @param _reserve The new reserve strategy that this yield source should use
  function setReserve(IReserve _reserve) external;

  /// @notice Returns the reserve strategy
  /// @return The current reserve strategy for this contract
  function reserve() external view returns (IReserve);

  /// @notice Transfers tokens from the reserve to the given address
  /// @param to The address to transfer reserve tokens to.
  function transferReserve(address to) external;

  /// @notice Allows the owner to transfer ERC20 tokens held by this contract to the target address. 
  /// @dev The owner should not be able to transfer any tokens that represent user deposits
  /// @param token The ERC20 token to transfer
  /// @param to The recipient of the tokens
  /// @param amount The amount of tokens to transfer
  function transferERC20(address token, address to, uint256 amount) external;

  /// @notice Allows the owner to transfer ERC721 tokens held by this contract to the target address
  /// @param token The ERC721 to transfer
  /// @param to The recipient of the token
  /// @param tokenId The ERC721 token id to transfer
  function transferERC721(address token, address to, uint256 tokenId) external;

  /// @notice Allows someone to deposit into the yield source without receiving any shares.
  /// This allows anyone to distribute tokens among the share holders.
  function sponsor(uint256 amount) external;
}
