// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

/**  @title A Fund Pooling project for community investment
     @author 3braheem
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

    /** 
        @notice                 Requires that a function be called solely by the admin of a specific pool
        @param _pool            The pool which is being interacted with
        @param _claimant       The address who is trying to access the function
    **/
    modifier onlyAdmin(uint256 _pool, address _claimant) {
        require(poolRoleState[_pool][_claimant] == Role.Administrator);
        _;
    }

    /** 
        @notice                 Requires an address inputted into a function to not be the 0 address
        @param _input           The address that is inputted into the function
    **/
    modifier notNull(address _input) {
        require(_input != address(0));
        _;
    }

    /** 
        @notice                 Requires the specified address to be a member of a specified pool
        @param _pool            The pool which is being interacted with
        @param _input           The address that is inputted 
    **/
    modifier isAMember(uint256 _pool, address _input) {
        require(poolMemberState[_pool][_input] == true);
        _;
    }

    /** 
        @notice                 Requires the inputted index to exist in the system
        @param _poolIndex       The index of a pool in the pools array 
    **/
    modifier poolExists(uint256 _poolIndex) {
        require(_poolIndex < pools.length, "Not an existing pool.");
        _;
    }

    modifier consensusReached(uint256 _accepted, uint256 _length) {
        require(_accepted == _length, "Consensus has not been reached");
        _;
    }

    modifier inAPool(address _claimant) {
        require(poolGroup[_claimant] != 0, "You are not in a pool.");
        _;
    }

    event NewPoolCreated(
        address[] indexed members,
        uint256 indexed balance,
        uint256 indexed id
    );

    event AdminConsent(
        uint256 indexed pool,
        address indexed admin,
        address indexed consenter
    );

    event DepositMade(
        uint256 indexed id,
        uint256 indexed amount,
        address indexed sender
    );

    event DepositReceived(uint256 indexed amount, address indexed sender);
    event AdminAppointed(uint256 indexed pool, address indexed admin);

    receive() external payable {
        emit DepositReceived(msg.value, msg.sender);
    }

    function initGroup(
        address[] memory _members,
        uint256 _startingBalance,
        uint256 _startingPayout
    ) public payable returns (uint256) {
        uint256 poolIndex = pools.length;
        pools.push(
            Pool({
                admin: address(0),
                members: _members,
                payout: _startingPayout,
                balance: _startingBalance
            })
        );
        (bool success, ) = address(this).call{value: _startingBalance}("");
        require(success, "Something went wrong");
        for (uint256 i = 0; i < _members.length; i++) {
            poolGroup[_members[i]] = poolIndex;
            poolMemberState[poolIndex][_members[i]] = true;
            poolRoleState[poolIndex][_members[i]] = Role.Regular;
        }
        emit NewPoolCreated(_members, _startingBalance, poolIndex);
        return poolIndex;
    }

    function approveAdmin(address _admin)
        public
        isAMember(poolGroup[msg.sender], msg.sender)
        isAMember(poolGroup[msg.sender], _admin)
        poolExists(poolGroup[msg.sender])
        inAPool(msg.sender)
    {
        require(
            memberConsent[poolGroup[msg.sender]][msg.sender][_admin] = false,
            "Already approved this selection."
        );
        memberConsent[poolGroup[msg.sender]][msg.sender][_admin] = true;
        emit AdminConsent(poolGroup[msg.sender], _admin, msg.sender);
    }

    function appointAdmin(address _admin)
        public
        isAMember(poolGroup[msg.sender], msg.sender)
        isAMember(poolGroup[msg.sender], _admin)
        poolExists(poolGroup[msg.sender])
        inAPool(msg.sender)
    {
        Pool storage pool = pools[poolGroup[msg.sender]];
        address[] memory members = pool.members;
        for (uint256 i = 0; i < members.length; i++) {
            require(
                memberConsent[poolGroup[msg.sender]][members[i]][_admin] = true,
                "Consent has not been reached."
            );
        }
        pool.admin = _admin;
        poolRoleState[poolGroup[msg.sender]][_admin] = Role.Administrator;
        emit AdminAppointed(poolGroup[msg.sender], _admin);
    }

    function deposit()
        public
        payable
        isAMember(poolGroup[msg.sender], msg.sender)
        poolExists(poolGroup[msg.sender])
        inAPool(msg.sender)
    {
        Pool storage pool = pools[poolGroup[msg.sender]];
        pool.balance += msg.value;
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "The call was unsuccessful.");
        emit DepositMade(poolGroup[msg.sender], msg.value, msg.sender);
    }

    function setPayout(uint256 _newPayout)
        public
        onlyAdmin(poolGroup[msg.sender], msg.sender)
        poolExists(poolGroup[msg.sender])
        inAPool(msg.sender)
    {
        Pool storage pool = pools[poolGroup[msg.sender]];
        pool.payout += _newPayout;
    }

    function payout(address _receiver)
        public
        payable
        onlyAdmin(poolGroup[msg.sender], msg.sender)
        notNull(_receiver)
        isAMember(poolGroup[msg.sender], _receiver)
        inAPool(msg.sender)
    {
        Pool storage pool = pools[poolGroup[msg.sender]];
        require(pool.balance - pool.payout > 0, "Not enough funds.");
        pool.balance -= pool.payout;
        (bool success, ) = _receiver.call{value: pool.payout}("");
        require(success, "The call was unsuccessful.");
    }
}
