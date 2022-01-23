// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/**  @title                         A Fund Pooling project for community investment
     @author                        3braheem
**/
contract WePool {
    struct Pool {
        address admin;
        address[] members;
        uint256 balance;
        uint256 payout;
    }
    Pool[] public pools;

    enum Role {
        NA,
        Administrator,
        Regular
    }
    mapping(uint256 => mapping(address => Role)) public poolRoleState;
    mapping(uint256 => mapping(address => bool)) public poolMemberState;
    mapping(uint256 => mapping(address => mapping(address => bool)))
        public memberConsent;
    mapping(address => uint256) internal poolGroup;
    mapping(address => bool) public beenPaid;

    /** 
        @notice                     Requires that a function be called solely by the admin of a specific pool
        @param _pool                The pool which is being interacted with
        @param _claimant            The address who is trying to access the function
    **/
    modifier onlyAdmin(uint256 _pool, address _claimant) {
        require(poolRoleState[_pool][_claimant] == Role.Administrator);
        _;
    }

    /** 
        @notice                     Requires an address inputted into a function to not be the 0 address
        @param _input               The address that is inputted into the function
    **/
    modifier notNull(address _input) {
        require(_input != address(0));
        _;
    }

    /** 
        @notice                     Requires the specified address to be a member of a specified pool
        @param _pool                The pool which is being interacted with
        @param _input               The address that is inputted 
    **/
    modifier isAMember(uint256 _pool, address _input) {
        require(poolMemberState[_pool][_input] == true);
        _;
    }

    /** 
        @notice                     Requires the inputted index to exist in the system
        @param _poolIndex           The index of a pool in the pools array 
    **/
    modifier poolExists(uint256 _poolIndex) {
        require(_poolIndex < pools.length, "Not an existing pool.");
        _;
    }

    /** 
        @notice                     Requires consensus of pool members to be reached
        @param _accepted            The amount of members who have given consent
        @param _length              The length of the pool
    **/
    modifier consensusReached(uint256 _accepted, uint256 _length) {
        require(_accepted == _length, "Consensus has not been reached");
        _;
    }

    /** 
        @notice                     Restricts a function to only being called if sender is in a pool
        @param _claimant            The address attempting to access the function
    **/
    modifier inAPool(address _claimant) {
        require(poolGroup[_claimant] != 0, "You are not in a pool.");
        _;
    }

    /** 
        @notice                     Logs when a new pool is initialized 
        @param members              Array of members within the pool
        @param balance              The starting balance of the new pool
        @param id                   The id of the new pool
    **/
    event NewPoolCreated(
        address[] indexed members,
        uint256 indexed balance,
        uint256 indexed id
    );

    /** 
        @notice                     Logs when a pool member has given consent for admin selection 
        @param id                   The id of the pool
        @param admin                The admin selection that is being chosen
        @param consenter            The address of the consenting pool member
    **/
    event AdminConsent(
        uint256 indexed id,
        address indexed admin,
        address indexed consenter
    );

    /** 
        @notice                     Logs when a deposit has been made to a pool through deposit() 
        @param id                   The id of the pool
        @param amount               The amount that was deposited
        @param sender               The sender of the deposit
    **/
    event DepositMade(
        uint256 indexed id,
        uint256 indexed amount,
        address indexed sender
    );

    /** 
        @notice                     Logs when the payout amount for a pool has been set 
        @param id                   The id of the pool
        @param amount               The amount of the pool's payout
        @param admin                The address of the admin who set the payout
    **/
    event PayoutSet(
        uint256 indexed id,
        uint256 indexed amount,
        address indexed admin
    );

    /** 
        @notice                     Logs when a deposit to the contract has been received by receive() 
        @param amount               The amount deposited
        @param sender               The sender of the deposit
    **/
    event DepositReceived(uint256 indexed amount, address indexed sender);

    /** 
        @notice                     Logs when an admin has been appointed to a pool 
        @param id                   The id of the pool
        @param admin                The address of the admin that was appointed
    **/
    event AdminAppointed(uint256 indexed id, address indexed admin);

    /** 
        @notice                     Meant to log whatever is sent to the contract directly (donations etc.)
    **/
    receive() external payable {
        emit DepositReceived(msg.value, msg.sender);
    }

    /**
        @notice                     Function to initialize a new pool group (admins are decided by member consensus)
        @param _members             The array of members to be included in the group
        @param _startingBalance     The balance to be sent to the pool to start
        @return                     Returns the index of the pool in the contract's pools array
        @dev                        The members of the pool must appoint an admin before any payouts can happen
    **/
    function initGroup(address[] memory _members, uint256 _startingBalance)
        public
        payable
        returns (uint256)
    {
        uint256 poolIndex = pools.length;
        pools.push(
            Pool({
                admin: address(0),
                members: _members,
                payout: 0,
                balance: _startingBalance
            })
        );
        for (uint256 i = 0; i < _members.length; i++) {
            poolMemberState[poolIndex][_members[i]] = true;
            poolRoleState[poolIndex][_members[i]] = Role.Regular;
        }
        Pool storage pool = pools[poolIndex];
        pool.balance += _startingBalance;
        (bool success, ) = address(this).call{value: _startingBalance}("");
        require(success, "Something went wrong");
        emit NewPoolCreated(_members, _startingBalance, poolIndex);
        return poolIndex;
    }

    /**
        @notice                     Function to approve an address to be the admin of the pool
        @param _poolIndex           The index of the pool 
        @param _admin               The admin who is being approved by the sender
        @dev                        All members of a pool must agree to an admin choice before appointment can happen
    **/
    function approveAdmin(uint256 _poolIndex, address _admin)
        public
        isAMember(_poolIndex, msg.sender)
        isAMember(_poolIndex, _admin)
        poolExists(_poolIndex)
        inAPool(msg.sender)
    {
        require(
            memberConsent[_poolIndex][msg.sender][_admin] = false,
            "Already approved this selection."
        );
        memberConsent[_poolIndex][msg.sender][_admin] = true;
        emit AdminConsent(_poolIndex, _admin, msg.sender);
    }

    /**
        @notice                     Function to appoint an admin who has gained consensus approval
        @param _poolIndex           The index of the pool 
        @param _admin               The admin who is being appointed by the caller of the message
        @dev                        An admin is put in charge of distributing funds by consensus of pool members
    **/
    function appointAdmin(uint256 _poolIndex, address _admin)
        public
        isAMember(_poolIndex, msg.sender)
        isAMember(_poolIndex, _admin)
        poolExists(_poolIndex)
        inAPool(msg.sender)
    {
        Pool storage pool = pools[_poolIndex];
        address[] memory members = pool.members;
        for (uint256 i = 0; i < members.length; i++) {
            require(
                memberConsent[_poolIndex][members[i]][_admin] = true,
                "Consensus has not been reached."
            );
        }
        pool.admin = _admin;
        poolRoleState[_poolIndex][_admin] = Role.Administrator;
        emit AdminAppointed(_poolIndex, _admin);
    }

    /**
        @notice                     Function to deposit funds into the balance of a pool in which the sender is a member
        @param _poolIndex           The index of the pool 
        @dev                        This will deposit funds to the pool's balance 
    **/
    function deposit(uint256 _poolIndex)
        public
        payable
        isAMember(_poolIndex, msg.sender)
        poolExists(_poolIndex)
        inAPool(msg.sender)
    {
        Pool storage pool = pools[_poolIndex];
        pool.balance += msg.value;
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "The call was unsuccessful.");
        emit DepositMade(_poolIndex, msg.value, msg.sender);
    }

    /**
        @notice                     Function to set the amount that the pool pays out with payout()
        @param _poolIndex           The index of the pool 
        @param _newPayout           The amount to be set as the pool's payout
        @dev                        Sets the payout of a pool, payouts are meant to be agreed upon by pool members 
    **/
    function setPayout(uint256 _poolIndex, uint256 _newPayout)
        public
        onlyAdmin(_poolIndex, msg.sender)
        poolExists(_poolIndex)
        inAPool(msg.sender)
    {
        Pool storage pool = pools[_poolIndex];
        pool.payout += _newPayout;
        emit PayoutSet(_poolIndex, _newPayout, msg.sender);
    }

    /**
        @notice                     Function to payout a pool member 
        @param _poolIndex           The index of the pool
        @param _receiver            The member who will receive the payout 
        @dev                        Payouts are meant to be given on a schedule, which the pool must agree upon
    **/
    function payout(uint256 _poolIndex, address _receiver)
        public
        payable
        onlyAdmin(_poolIndex, msg.sender)
        notNull(_receiver)
        isAMember(_poolIndex, _receiver)
        inAPool(msg.sender)
    {
        require(
            !beenPaid[_receiver] == true,
            "This address has already received a payout."
        );
        Pool storage pool = pools[_poolIndex];
        require(pool.balance - pool.payout > 0, "Not enough funds.");
        pool.balance -= pool.payout;
        beenPaid[_receiver] = true;
        (bool success, ) = _receiver.call{value: pool.payout}("");
        require(success, "The call was unsuccessful.");
    }
}
