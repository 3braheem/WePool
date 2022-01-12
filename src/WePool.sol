// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/// @title A Fund Pooling project for community investment
/// @author 3braheem
contract WePool {
    struct Pool {
        uint256 index;
        PoolMember admin;
        PoolMember[] regulars;
        uint256 balance;
    }

    struct PoolMember {
        address member;
        string name;
    }

    enum Role {
        Administrator,
        Regular
    }
    mapping(uint256 => mapping(address => Role)) poolRoleState;
    mapping(uint256 => mapping(address => bool)) poolMemberState;
    mapping(address => uint256) poolGroup;

    modifier onlyAdmin(uint256 _pool, address _claimant) {
        require(poolRoleState[_pool][_claimant] == Role.Administrator);
        _;
    }

    modifier notNull(address _input) {
        require(_input != address(0));
        _;
    }

    modifier isAMember(uint256 _pool, address _input) {
        require(poolMemberState[_pool][_input] == true);
        _;
    }

    function payout(address _receiver)
        public
        payable
        onlyAdmin(poolGroup[msg.sender], msg.sender)
        notNull(_receiver)
        isAMember(poolGroup[msg.sender], _receiver)
    {
        require(poolGroup[msg.sender] != 0);
        (bool success, ) = _receiver.call{value: msg.value}("");
        require(success, "The call was unsuccessful.");
    }
}
