// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract Vault {
    // we need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal to the amount of eth the user has sent
    // create a redeem function that burns the tokens from the user and sends the user ETH
    // create a way to add rewards to the vault
    error RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {
        // mint tokens to the user
        // the amount of tokens to mint is equal to the amount of eth sent
        // the user should be able to redeem the tokens for the amount of eth sent
    }

    /**
     * @notice Allows users to deposit ETH and mint rebase tokens in return
     */
    function deposit() external payable {
        // we neeed to use the amount of ETH the user has sent to mint tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their rebase tokens for ETH
     * @param _amount The amount of tokens the user wants to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // 1. we need to burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. We need to send the user ETH
        (bool success, ) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
            revert RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
