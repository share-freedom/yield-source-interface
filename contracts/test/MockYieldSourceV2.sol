// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../IYieldSource.sol";
import "./ERC20Mintable.sol";
import "./TransferHelper.sol";
/**
 * @dev Extension of {ERC20} that adds a set of accounts with the {MinterRole},
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract MockYieldSourceV2 is Ownable,IYieldSource {
    address private stakeToken;
    uint256 public ratePerSecond;
    uint256 public depositTotal;
    uint256 public prizeTotal;
    mapping (address=>uint256) public depositAmount;
    mapping (address=>uint256) public prizeAmount;
    uint256 public lastYieldTimestamp;
    address public permiter;   
    address public investor;
    uint256 public investorRate; // max is 10000
    uint256 public investorMax; //
    using SafeMath for uint256;
    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    bytes32 DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256(bolt(address permit,address reciever,uint256 nonce,uint256 expiry,uint256 amount)");
    bytes32 public constant BOLT_TYPEHASH = 0x0de8d8e64f9de1f034d0c2a7736045e67c47332a0b56bcc68f4cc79cf03a81e5;
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );


    constructor(address _stakeToken, uint256 _chainid, address _permiter){
        stakeToken = _stakeToken;
        lastYieldTimestamp = block.timestamp;
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name: "Yield Source",
            version: '1',
            chainId: _chainid,
            verifyingContract: address(this) 
        }));
        permiter = _permiter;
        investor = msg.sender;
        investorRate = 100;
    }

    modifier onlyInvestor(){
        require(msg.sender == investor, "Investor: caller is not the investor");
        _;
    }

    function changeInvestorStrategy(address _investor, uint256 _investorRate, uint256 _investorMax) external onlyOwner{
        require(_investor != address(0), "investor address error");
        require(_investorRate < 10000, "investor rate must be smaller 10000");
        investor = _investor;
        investorRate = _investorRate;
        investorMax = _investorMax;
    }

    function updatePermiter(address _permiter) external onlyOwner{
        require(_permiter != address(0), "permiter address error");
        permiter = _permiter;
    }

    function withdrawInvestorAsset(address to, uint256 amount) external onlyInvestor{
        uint256 remaining = depositTotal.mul(investorRate).div(10000);
        require(remaining >= amount, "remain must bigger than withdraw");
        require(remaining <= investorMax, "remain must smaller than invest max");
        investorMax = investorMax.sub(amount);
        depositTotal = depositTotal.sub(amount);
        TransferHelper.safeTransfer(stakeToken, to, amount);    
    }

    function injectInvestorAsset(uint256 amount) external onlyInvestor{ 
        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), amount);
        investorMax = investorMax.add(amount);
        depositTotal = depositTotal.add(amount);
    }

    /// @notice Returns the ERC20 asset token used for deposits.
    /// @return The ERC20 asset token address.
    function depositToken() external view override returns (address) {
        return address(stakeToken);
    }

    /// @notice Returns the total balance (in asset tokens).  This includes the deposits and interest.
    /// @return The underlying balance of asset tokens.
    function balanceOfToken(address addr) external view override returns (uint256) {
        uint256 amount = depositAmount[addr].add(prizeAmount[addr]);
        return amount;
    }

    /// @notice Supplies tokens to the yield source.  Allows assets to be supplied on other user's behalf using the `to` param.
    /// @param amount The amount of asset tokens to be supplied.  Denominated in `depositToken()` as above.
    /// @param to The user whose balance will receive the tokens
    function supplyTokenTo(uint256 amount, address to) external override {
        //stakeToken.transferFrom(msg.sender, address(this), amount);
        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), amount);
        uint256 deposit = depositAmount[to];
        depositAmount[to] = amount.add(deposit);
        depositTotal = depositTotal.add(amount);
    }

    /// @notice Redeems tokens from the yield source.
    /// @param amount The amount of asset tokens to withdraw.  Denominated in `depositToken()` as above.
    /// @return The actual amount of interst bearing tokens that were redeemed.
    function redeemToken(uint256 amount) external override returns (uint256) {
        
        uint256  deposit = depositAmount[msg.sender];
        require(deposit  >=  amount, "deposit must bigger than redeemtoken");
        depositAmount[msg.sender] = depositAmount[msg.sender].sub(amount);
        //IERC20(stakeToken).transfer(msg.sender, amount);
        TransferHelper.safeTransfer(stakeToken, msg.sender, amount);  
        depositTotal = depositTotal.add(amount);
        return amount;
    }

    function withdrawPrize() external returns (uint256) {
        uint256 amount = prizeAmount[msg.sender];
        require(amount > 0, "don't have amount");
        prizeTotal = prizeTotal.add(amount);
        prizeAmount[msg.sender] = 0;
        IERC20(stakeToken).transfer(msg.sender, amount);
        return amount; 
    }

    function bolt(address permit, address reciever, uint256 nonce, uint256 expiry,
                    uint256 amount, uint8 v, bytes32 r, bytes32 s) external
    {
        require(permiter == permit, "invalid permit address");
        bytes32 digest =
            keccak256(abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(BOLT_TYPEHASH,
                                     permit,
                                     reciever,
                                     nonce,
                                     expiry,
                                     amount))
        ));

        require(permit == ecrecover(digest, v, r, s), "invalid-permit");
        require(expiry == 0 || block.timestamp <= expiry, "permit-expired");
       // require(nonce == nonces[permit]++, "invalid-nonce");
        require(amount < prizeTotal, "invalid-amount");
        prizeTotal = prizeTotal.sub(amount);
        TransferHelper.safeTransfer(stakeToken, msg.sender, amount);
    }

    function injectReward(uint256 amount) external returns (uint256) {
        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), amount);
        prizeTotal = prizeTotal.add(amount);
        return amount;
    }
    
    function injectReverse(uint256 amount) external returns (uint256) {
        TransferHelper.safeTransferFrom(stakeToken, msg.sender, address(this), amount);
        return amount;
    }

}



