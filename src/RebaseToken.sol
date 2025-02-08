// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Ike Uzoma Charles
 * @notice This is a cross-chain rebase token that incentivises user to deposit into a vault and gain interest in rewards
 * @notice the interest rate in the smart contracts can only decrease
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    uint256 private constant PRECISION_FACTOR = 1e27;
    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) s_userInterestRates;
    mapping(address => uint256) s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        // console.logBytes32(MINT_AND_BURN_ROLE);

        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Set the interest ra
     * e in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Set the interest rate
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice This is the amount of tokens that have been minted to the user not including the interest that has been accumulated since the last time the user interacted with the protocol
     * @param _user The user to get the principle balance for
     * @return The principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     *  @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRates[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Calculate the balance of the user including the interest that has been accumulated since the last update
     * (principal balance * the interest that has accrued)
     * @param _user The user to calculate the balance for
     * @return The balance of the user including the interest
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (to number of tokens that have actually been minted to the user)
        // mutiply the principle balance by the interest rate
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param recipient The user to transer the tokens to
     * @param amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }

        if (balanceOf(recipient) == 0) {
            s_userInterestRates[recipient] = s_userInterestRates[msg.sender];
        }
        return super.transfer(recipient, amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _sender The user to transfer the tokens from
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRates[_recipient] = s_userInterestRates[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the interest that has accrued since the last update
     * @param _user The user to calculate the interest accumulated for
     * @return linearInterest The interest that has accrued since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        // we need to calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        // 1. Calculate the time since the last update
        // 2. Calculate the amount of linear growth
        // (principal amount) + principal amount * interest rate * time elapsed

        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
            
        linearInterest =
            (s_userInterestRates[_user] * timeElapsed) +
            PRECISION_FACTOR;
    }

    function _mintAccruedInterest(address _user) internal {
        // (1) find the current balance of rebase token that have been minted to user
        // (2) calculate their current balance including any interests -> balanceOf
        // (3) calculate the number of tokens that need to be minted by the user => (2) - (1)
        // call _mint to mint the token to the user
        // set the user last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * @notice Get the interest rate for the contract
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get the interest rate for the user
     * @param _user The user to get interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRates[_user];
    }
}
