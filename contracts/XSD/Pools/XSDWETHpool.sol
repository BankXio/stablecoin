// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../../Utils/Initializable.sol';
import '../../Utils/UQ112x112.sol';
import '../../Oracle/Interfaces/IPIDController.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../XSDStablecoin.sol';
import '../../BankX/BankXToken.sol';
import './Interfaces/IXSDWETHpool.sol';

contract XSDWETHpool is IXSDWETHpool, Initializable, ReentrancyGuard{
    using UQ112x112 for uint224;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    bytes32 public constant override PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public override nonces;
    uint256 private constant PRICE_PRECISION = 1e6;
    address private XSDaddress;
    address private WETHaddress;
    address public smartcontract_owner;
    address public router_address;
    //keeps track of amount that needs to be burnt
    uint public xsdamount;

    IPIDController pid_controller;
    XSDStablecoin private XSD;
    BankXToken private BankX;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves
    
    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity even

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    uint public reserve0_residue;
    uint public reserve1_residue;

    function getReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'XSDWETH: TRANSFER_FAILED');
    }


    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    constructor(address _smartcontract_owner, uint _reserve0_residue, uint _reserve1_residue){
        require(_smartcontract_owner != address(0), "Zero address detected");
        smartcontract_owner = _smartcontract_owner;
        reserve0_residue = _reserve0_residue;
        reserve1_residue = _reserve1_residue;
    }
    // called once by the smartcontract_address at time of deployment
    function initialize(address _token0, address _token1, address _bankx_contract_address, address _pid_address, address _collateral_pool_address) public initializer {
        require(msg.sender == smartcontract_owner, 'XSD/WETH: FORBIDDEN'); // sufficient check
        require((_token0 != address(0))
        &&(_token1 != address(0))
        &&(_bankx_contract_address != address(0))
        &&(_pid_address != address(0))
        &&(_collateral_pool_address != address(0)), "Zero address detected");
        XSDaddress = _token0;
        XSD = XSDStablecoin(XSDaddress);
        BankX = BankXToken(_bankx_contract_address);
        WETHaddress = _token1;
        pid_controller = IPIDController(_pid_address);
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'XSDWETH: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        unchecked{
            uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // Returns dollar value of collateral held in this XSD pool
    function collatDollarBalance() public view override returns (uint256) {
            return ((IERC20(WETHaddress).balanceOf(address(this))*(XSD.eth_usd_price()))/(PRICE_PRECISION));     
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to) external override lock{
        //router access only
        require(msg.sender == router_address, "Only the router can access this function");
        require(amount0Out > 0 || amount1Out > 0, 'XSDWETH: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        _reserve0 = uint112(_reserve0);
        _reserve1 = uint112(_reserve1);
        require(amount0Out < (_reserve0-reserve0_residue) && amount1Out < (_reserve1-reserve1_residue), 'XSDWETH: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = XSDaddress;
        address _token1 = WETHaddress;
        require(to != _token0 && to != _token1, 'XSDWETH: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'XSDWETH: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = balance0;
        uint balance1Adjusted = balance1;
        require(balance0Adjusted*(balance1Adjusted) >= uint(_reserve0)*(_reserve1), 'XSDWETH: K');
        }
        if(amount1Out != 0) xsdamount = amount0In;
        _update(balance0, balance1,_reserve0,_reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external override nonReentrant {
        address _token0 = XSDaddress; // gas savings
        address _token1 = WETHaddress; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this))-(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this))-(reserve1));
    }

    // force reserves to match balances
    function sync() external override nonReentrant {
        _update(IERC20(XSDaddress).balanceOf(address(this)), IERC20(WETHaddress).balanceOf(address(this)), reserve0, reserve1);
        kLast = uint(reserve0)*(reserve1);
    }

    function setSmartContractOwner(address _smartcontract_owner) external{
        require(msg.sender == smartcontract_owner, "Only the smart contract owner can access this function");
        require(_smartcontract_owner != address(0), "Zero address detected");
        smartcontract_owner = _smartcontract_owner;
    }

    function setRouterAddress(address _router_address) external{
        require(msg.sender == smartcontract_owner, "Only the smart contract owner can access this function");
        router_address = _router_address;
    }

    function renounceOwnership() external{
        require(msg.sender == smartcontract_owner, "Only the smart contract owner can access this function");
        smartcontract_owner = address(0);
    }

    function resetAddresses(address _token0, address _token1, address _bankx_contract_address, address _pid_address, address _collateral_pool_address) external{
        require(msg.sender == smartcontract_owner, 'XSD/WETH: FORBIDDEN'); // sufficient check
        require((_token0 != address(0))
        &&(_token1 != address(0))
        &&(_bankx_contract_address != address(0))
        &&(_pid_address != address(0))
        &&(_collateral_pool_address != address(0)), "Zero address detected");
        XSDaddress = _token0;
        XSD = XSDStablecoin(XSDaddress);
        BankX = BankXToken(_bankx_contract_address);
        WETHaddress = _token1;
        pid_controller = IPIDController(_pid_address);
    }
    /* ========== EVENTS ========== */
    event ProvideLiquidity(address sender, uint amount0, uint amount1);
    event ProvideLiquidity2(address sender, uint amount1);
    

}