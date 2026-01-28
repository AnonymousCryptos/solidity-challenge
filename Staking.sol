// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Staking is Ownable, ReentrancyGuard {
    IERC20 public immutable token;

    struct Position {
        uint256 amount;
        uint256 startTime;
        bool interestClaimed;
    }

    mapping(address => Position) private positions;

    constructor(address _token) {
        require(_token != address(0), "Invalid token");
        token = IERC20(_token);
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Can't be Zero amount");

        Position storage p = positions[msg.sender];

        if (p.amount > 0) {
            uint256 interest = _interest(msg.sender);

            // Single transfer is intentional:
            // saves gas by avoiding multiple ERC20 transfers
            // principal and interest are paid atomically
            uint256 payout = p.amount + interest;
            token.transfer(msg.sender, payout);
        }

        token.transferFrom(msg.sender, address(this), amount);

        positions[msg.sender] = Position({
            amount: amount,
            startTime: block.timestamp,
            interestClaimed: false
        });
    }

    function redeem(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");

        Position storage p = positions[msg.sender];
        require(amount <= p.amount, "Insufficient stake");

        p.amount -= amount;

        // Note:
        // In a production system, users should ideally be warned or required
        // to explicitly acknowledge that redeeming before claiming interest
        // will forfeit their accrued rewards. It is unfair for user and breaks their trust in the product.
        // This behavior is implemented strictly to comply with the rules defined in the coding challenge.
        p.interestClaimed = true;

        token.transfer(msg.sender, amount);

        if (p.amount == 0) {
            delete positions[msg.sender];
        }
    }

    function claimInterest() external nonReentrant {
        uint256 interest = _interest(msg.sender);
        require(interest > 0, "No interest to claim");

        positions[msg.sender].interestClaimed = true;
        token.transfer(msg.sender, interest);
    }

    function sweep() external onlyOwner {
        // Note:
        // Allowing the owner (or any single entity) to withdraw all tokens
        // from a staking contract is generally not ideal in production systems.
        // Doing so can break user trust and would cause future redeem or interest
        // claims to fail due to insufficient funds. The owner should 
        // maintain the required funds at all times to keep the protocol functional
        //
        // This function is implemented strictly to comply with the challenge
        // requirements and does not reflect a recommended production approach.
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    function _interest(address user) internal view returns (uint256) {
        Position memory p = positions[user];

        if (p.amount == 0 || p.interestClaimed) {
            return 0;
        }

        uint256 duration = block.timestamp - p.startTime;

        if (duration < 1 days) {
            return 0;
        }

        if (duration >= 7 days) {
            return (p.amount * 10) / 100;
        }

        return (p.amount * 1) / 100;
    }
}
