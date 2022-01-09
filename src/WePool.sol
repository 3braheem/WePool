// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/// @title A Fund Pooling project for community investment
/// @author 3braheem
contract WePool {
    struct Pool {
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
    mapping(address => Role) roleState;
    mapping(address => bool) memberState;

    function appoint(address _admin) public onlyAdmin notNull {}
}
