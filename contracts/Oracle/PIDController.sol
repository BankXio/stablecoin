// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../XSD/XSDStablecoin.sol";
import "../UniswapFork/BankXLibrary.sol";
import "../XSD/Pools/Interfaces/ICollateralPool.sol";
import "../XSD/Pools/Interfaces/IBankXWETHpool.sol";
import "../XSD/Pools/Interfaces/IXSDWETHpool.sol";
import "../Utils/Initializable.sol";
import "./Interfaces/BankXNFTInterface.sol";
import "./Interfaces/ICD.sol";


contract PIDController is Initializable {

    // Instances
    XSDStablecoin public XSD;
    BankXToken public BankX;
    ICollateralPool public collateralpool;
    
    // XSD and BankX addresses
    address public xsdwethpool_address;
    address public bankxwethpool_address;
    address public collateralpool_address;
    address public smartcontract_owner;
    address public BankXNFT_address;
    address public cd_address;
    uint public NFT_timestamp;
    // Misc addresses
    address public reward_manager_address;
    address public WETH;
    // 6 decimals of precision
    uint256 public growth_ratio;
    uint256 public xsd_step;
    uint256 public GR_top_band;
    uint256 public GR_bottom_band;

    // Time-related
    uint256 public internal_cooldown;
    uint256 public last_update;
    
    // Booleans
    bool public is_active;
    bool public use_growth_ratio;
    bool public collateral_ratio_paused;
    bool public FIP_6;
    
    //deficit related variables
    bool public bucket1;
    bool public bucket2;
    bool public bucket3;

    uint public diff1;
    uint public diff2;
    uint public diff3;

    uint public timestamp1;
    uint public timestamp2;
    uint public timestamp3;

    uint public amountpaid1;
    uint public amountpaid2;
    uint public amountpaid3;

    //arbitrage relate variables
    uint256 public xsd_percent;
    uint256 public xsd_percentage_target;
    uint256 public bankx_percentage_target;
    uint256 public cd_allocated_supply;

    //price variables
    uint256 public bankx_updated_price;
    uint256 public xsd_updated_price;
    struct PriceCheck{
        uint256 lastpricecheck;
        bool pricecheck;
    }
    mapping (address => PriceCheck) public lastPriceCheck;
    /* ========== MODIFIERS ========== */

    modifier onlyByOwner() {
        require(msg.sender == smartcontract_owner || msg.sender == reward_manager_address, "Not owner or reward_manager");
        _;
    }

    /* ========== CONSTRUCTOR ========== */
//switch back to constructor
    function initialize(address _xsd_contract_address,address _bankx_contract_address,address _xsd_weth_pool_address, address _bankx_weth_pool_address,address _collateralpool_contract_address,address _WETHaddress,address _smartcontract_owner,address _reward_manager_address, uint _xsd_percentage_target, uint _bankx_percentage_target) public initializer{
        require(
            (_xsd_contract_address != address(0))
            && (_bankx_contract_address != address(0))
            && (_xsd_weth_pool_address != address(0))
            && (_bankx_weth_pool_address != address(0))
            && (_collateralpool_contract_address != address(0))
            && (_WETHaddress != address(0))
            && (_reward_manager_address != address(0))
        , "Zero address detected"); 
        xsdwethpool_address = _xsd_weth_pool_address;
        bankxwethpool_address = _bankx_weth_pool_address;
        smartcontract_owner = _smartcontract_owner;
        reward_manager_address = _reward_manager_address;
        xsd_step = 2500;
        collateralpool_address = _collateralpool_contract_address;
        collateralpool = ICollateralPool(_collateralpool_contract_address);
        XSD = XSDStablecoin(_xsd_contract_address);
        BankX = BankXToken(_bankx_contract_address);
        WETH = _WETHaddress;
        xsd_percentage_target = _xsd_percentage_target;
        bankx_percentage_target = _bankx_percentage_target;

        // Upon genesis, if GR changes by more than 1% percent, enable change of collateral ratio
        GR_top_band = 1000;
        GR_bottom_band = 1000; 
        is_active = false;
    }

    

    //interest rate variable
    /* ========== PUBLIC MUTATIVE FUNCTIONS ========== */
    
    //add a smaller function price check
    function systemCalculations() public {
    	require(collateral_ratio_paused == false, "Collateral Ratio has been paused");
        uint256 time_elapsed = block.timestamp - last_update;
        require(time_elapsed >= internal_cooldown, "internal cooldown not passed");
        uint256 bankx_reserves = BankX.balanceOf(bankxwethpool_address);
        uint256 bankx_price = XSD.bankx_price();
        
        uint256 bankx_liquidity = bankx_reserves*bankx_price; // Has 6 decimals of precision

        uint256 xsd_supply = XSD.totalSupply();
        
        // Get the XSD price
        uint256 xsd_price = XSD.xsd_price();

        uint256 new_growth_ratio = (bankx_liquidity/(xsd_supply-collateralpool.collat_XSD())); // (E18 + E6) / E18

        uint256 last_collateral_ratio = XSD.global_collateral_ratio();
        uint256 new_collateral_ratio = last_collateral_ratio;
        uint256 silver_price = (XSD.xag_usd_price()*(1e4))/(311035); //31.1034768
        uint256 XSD_top_band = silver_price + (xsd_percent*silver_price)/100;
        uint256 XSD_bottom_band = silver_price - (xsd_percent*silver_price)/100;
        
        // make the top band and bottom band a percentage of silver price.

        if(FIP_6){
            require(xsd_price > XSD_top_band || xsd_price < XSD_bottom_band, "Use PIDController when XSD is outside of peg");
        }

       if((NFT_timestamp == 0) || ((block.timestamp - NFT_timestamp)>43200)){
            BankXInterface(BankXNFT_address).updateTVLReached();
            NFT_timestamp = block.timestamp;
        }

        // First, check if the price is out of the band
        if(xsd_price > XSD_top_band){
            new_collateral_ratio = last_collateral_ratio - xsd_step;
            
        } else if (xsd_price < XSD_bottom_band){
            new_collateral_ratio = last_collateral_ratio + xsd_step;
            

        // Else, check if the growth ratio has increased or decreased since last update
        } else if(use_growth_ratio){
            if(new_growth_ratio > ((growth_ratio*(1e6 + GR_top_band))/1e6)){
                new_collateral_ratio = last_collateral_ratio - xsd_step;
            } else if (new_growth_ratio < (growth_ratio*(1e6 - GR_bottom_band)/1e6)){
                new_collateral_ratio = last_collateral_ratio + xsd_step;
            }
        }

        growth_ratio = new_growth_ratio;
        last_update = block.timestamp;

        // No need for checking CR under 0 as the last_collateral_ratio.sub(xsd_step) will throw 
        // an error above in that case
        if(new_collateral_ratio > 1e6){
            new_collateral_ratio = 1e6;
        }
        incentiveChecker1();
        incentiveChecker2();
        incentiveChecker3();
        priceCheck();
        if(is_active){
            uint256 delta_collateral_ratio;
            if(new_collateral_ratio > last_collateral_ratio){
                delta_collateral_ratio = new_collateral_ratio - last_collateral_ratio;
                XSD.setPriceTarget(1000e6); // Set to high value to decrease CR
                emit XSDdecollateralize(new_collateral_ratio);
            } else if (new_collateral_ratio < last_collateral_ratio){
                delta_collateral_ratio = last_collateral_ratio - new_collateral_ratio;
                XSD.setPriceTarget(0); // Set to zero to increase CR
                emit XSDrecollateralize(new_collateral_ratio);
            }

            XSD.setXSDStep(delta_collateral_ratio); // Change by the delta
            uint256 cooldown_before = XSD.refresh_cooldown(); // Note the existing cooldown period
            XSD.setRefreshCooldown(0); // Unlock the CR cooldown
            //refresh interest rate.
            XSD.refreshCollateralRatio(); // Refresh CR

            // Reset params
            XSD.setXSDStep(0);
            XSD.setRefreshCooldown(cooldown_before); // Set the cooldown period to what it was before, or until next controller refresh
            //change price target to that of one ounce/gram of silver.
            XSD.setPriceTarget((XSD.xag_usd_price()*(1e4))/(311035));           
        }
    }

    function priceCheck() public {
        bankx_updated_price = XSD.bankx_price();
        xsd_updated_price = XSD.xsd_price();
        lastPriceCheck[msg.sender].lastpricecheck = block.number;
        lastPriceCheck[msg.sender].pricecheck = true;
    }

    //checks the XSD liquidity pool for a deficit.
    //bucket and difference variables should return values only if changed.
    // difference is calculated only every week.
    function incentiveChecker1() internal{
        uint silver_price = (XSD.xag_usd_price()*(1e4))/(311035);
        uint XSDvalue = (XSD.totalSupply()*(silver_price))/(1e6);
        uint _reserve1;
        (,_reserve1,) = IXSDWETHpool(xsdwethpool_address).getReserves();
        uint reserve = (_reserve1*(XSD.eth_usd_price())*2)/(1e6);
        if(((block.timestamp - timestamp1)>=64800)||(amountpaid1 >= diff3)){
            timestamp1 = 0;
            bucket1 = false;
            diff1 = 0;
            amountpaid1 = 0;
        }
        if(timestamp1 == 0){
        if(reserve<((XSDvalue*xsd_percentage_target)/100)){
            bucket1 = true;
            diff1 = (((XSDvalue*xsd_percentage_target)/100)-reserve)/2;
            timestamp1 = block.timestamp;
        }
        }
    }

    //checks the BankX liquidity pool for a deficit.
    //bucket and difference variables should return values only if changed.
    function incentiveChecker2() internal{
        cd_allocated_supply = ICD(cd_address).allocatedSupply();
        uint BankXvalue = (cd_allocated_supply*(XSD.bankx_price()))/(1e6);
        uint _reserve1;
        (, _reserve1,) = IBankXWETHpool(bankxwethpool_address).getReserves();
        uint reserve = (_reserve1*(XSD.eth_usd_price())*2)/(1e6);
        if(((block.timestamp - timestamp2)>=64800)|| (amountpaid2 >= diff2)){
            timestamp2 = 0;
            bucket2 = false;
            diff2 = 0;
            amountpaid2 = 0;
        }
        if(timestamp2 == 0){
        if(reserve<((BankXvalue*bankx_percentage_target)/100)){
            bucket2 = true;
            diff2 = (((BankXvalue*bankx_percentage_target)/100) - reserve)/2;
            timestamp2 = block.timestamp;
        }
        }
    }

    //checks the Collateral pool for a deficit
    // return system collateral as a public global variable
    function incentiveChecker3() internal{
        uint silver_price = (XSD.xag_usd_price()*(1e4))/(311035);
        uint XSDvalue = (collateralpool.collat_XSD()*(silver_price))/(1e6);//use gram of silver price
        uint collatValue = collateralpool.collatDollarBalance();// eth value in the collateral pool
        XSDvalue = (XSDvalue * XSD.global_collateral_ratio())/(1e6);
        if(((block.timestamp-timestamp3)>=604800) || (amountpaid3 >= diff3)){
            timestamp3 = 0;
            bucket3 = false;
            diff3 = 0;
            amountpaid3 = 0;
        }
        if(timestamp3 == 0 && collatValue != 0){
        if((collatValue*400)<=(3*XSDvalue)){ //posted collateral - actual collateral <= 0.25% posted collateral
            bucket3 = true;
            diff3 = (3*XSDvalue) - (collatValue*400); 
            timestamp3 = block.timestamp;
        }
        }
    }

    //functions to change amountpaid variables
    function amountPaidXSDWETH(uint ethvalue) external {
        require(msg.sender == reward_manager_address, "Only RewardManager can access this address");
        amountpaid1 += ethvalue;
    }

    function amountPaidBankXWETH(uint ethvalue) external {
        require(msg.sender == reward_manager_address, "Only RewardManager can access this address");
        amountpaid2 += ethvalue;
    }
    
    function amountPaidCollateralPool(uint ethvalue) external {
        require(msg.sender == reward_manager_address,"Only RewardManager can access this address");
        amountpaid3 += ethvalue;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function activate(bool _state) external onlyByOwner {
        is_active = _state;
    }

    function useGrowthRatio(bool _use_growth_ratio) external onlyByOwner {
        use_growth_ratio = _use_growth_ratio;
    }

    // As a percentage added/subtracted from the previous; e.g. top_band = 4000 = 0.4% -> will decollat if GR increases by 0.4% or more
    function setGrowthRatioBands(uint256 _GR_top_band, uint256 _GR_bottom_band) external onlyByOwner {
        GR_top_band = _GR_top_band;
        GR_bottom_band = _GR_bottom_band;
    }

    function setInternalCooldown(uint256 _internal_cooldown) external onlyByOwner {
        internal_cooldown = _internal_cooldown;
    }

    function setXSDStep(uint256 _new_step) external onlyByOwner {
        xsd_step = _new_step;
    }

    function setPriceBandPercentage(uint256 percent) external onlyByOwner {
        require(percent!=0,"PID:Zero value detected");
        xsd_percent = percent;
    }

    function toggleCollateralRatio(bool _is_paused) external onlyByOwner {
    	collateral_ratio_paused = _is_paused;
    }

    function activateFIP6(bool _activate) external onlyByOwner {
        FIP_6 = _activate;
    }

    function setSmartContractOwner(address _smartcontract_owner) external{
        require(msg.sender == smartcontract_owner, "Only the smart contract owner can access this function");
        require(_smartcontract_owner != address(0), "Zero address detected");
        smartcontract_owner = _smartcontract_owner;
    }

    function renounceOwnership() external{
        require(msg.sender == smartcontract_owner, "Only the smart contract owner can access this function");
        smartcontract_owner = address(0);
    }
    
    function setXSDPoolAddress(address _xsd_weth_pool_address) external onlyByOwner{
        xsdwethpool_address = _xsd_weth_pool_address;
    }

    function setBankXPoolAddress(address _bankx_weth_pool_address) external onlyByOwner{
        bankxwethpool_address = _bankx_weth_pool_address;
    }
    
    function setRewardManagerAddress(address _reward_manager_address) external onlyByOwner{
        reward_manager_address = _reward_manager_address;
    }

    function setCollateralPoolAddress(address payable _collateralpool_contract_address) external onlyByOwner{
        collateralpool_address = _collateralpool_contract_address;
        collateralpool = ICollateralPool(_collateralpool_contract_address);
    }

    function setXSDAddress(address _xsd_contract_address) external onlyByOwner{
        XSD = XSDStablecoin(_xsd_contract_address);
    }

    function setBankXAddress(address _bankx_contract_address) external onlyByOwner{
        BankX = BankXToken(_bankx_contract_address);
    }

    function setWETHAddress(address _WETHaddress) external onlyByOwner{
        WETH = _WETHaddress;
    }

    function setBankXNFTAddress(address _BankXNFT_address) external onlyByOwner{
        BankXNFT_address = _BankXNFT_address;
    }

    function setCDAddress(address _cd_address) external onlyByOwner{
        cd_address = _cd_address;
    }

    function setPercentageTarget(uint256 _xsd_percentage_target, uint256 _bankx_percentage_target) external onlyByOwner{
        xsd_percentage_target = _xsd_percentage_target;
        bankx_percentage_target = _bankx_percentage_target;
    }

    /* ========== EVENTS ========== */  
    event XSDdecollateralize(uint256 new_collateral_ratio);
    event XSDrecollateralize(uint256 new_collateral_ratio);
}