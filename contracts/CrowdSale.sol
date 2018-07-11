pragma solidity 0.4.23;

import './Token.sol';

contract CrowdSale is Ownable{
  using SafeMath for uint256;

  uint256 constant internal TOKEN_DECIMALS = 10**11;
  uint256 constant internal ICO_TOKENS = 6380000000*TOKEN_DECIMALS;
  uint256 constant internal ETH_DECIMALS = 10**18;
  uint8 constant internal TIERS = 4;

  uint256 public totalTokensSold;
  uint256 public icoStartTime;
  uint256 public icoEndTime;
  uint256 public weiRaised;
  address public holdings;
  uint256 public softCap;
  address public owner;
  uint256 public cap;
  bool private paused;
  bool private lock;

  struct Participant {
    uint256 contrAmount;
    uint256 remainingWei;
    bool whitelistStatus;
  }

  mapping(address => Participant) public participants;

  //The footballeum token already deployed
  Token public token; 

  struct SaleTier {      
    uint256 tokensToBeSold;  //amount of tokens to be sold in this SaleTier
    uint256 tokensSold;      //amount of tokens sold in each SaleTier
    uint256 bonusPercent;    //percentage of bonus to be given.
    uint256 minContribution; //minimum amount to contribute by tier   
    uint256 tierEnd;         //day tier ends 
    uint256 price;           //wei per token    
  }
   
  mapping(uint8 => SaleTier) saleTier;
  
  event LogWithdrawal(address _investor, uint256 _amount);
  event LogTokensBought(address indexed participant, uint256 indexed amountTkns); 

  modifier icoIsActive() {
    require(weiRaised < cap && now < icoEndTime && totalTokensSold <= ICO_TOKENS);
    _;
  }

  modifier icoHasEnded() {
    require(weiRaised >= cap || now > icoEndTime || totalTokensSold == ICO_TOKENS);
    _;
  }

  modifier activeContract(){
    require(paused == false);
    _;
  }


  // @param: _holdings for holding ether
  // @param: _token token address deployed on the mainnet first
  // @param: _price of ETH

  constructor(address _holdings, address _token) 
    public 
  {
    require(_holdings != 0x0);
    require(_token != 0x0); 
 
    // @dev: CONFIRM WEIRAISED
    weiRaised = 0;
    token = Token(_token);    
    holdings = _holdings;

    // @dev: SET AT TIME OF DEPLOYMENT
    softCap = 2000 ether;

    // @dev: SHOULD BE SAME AS TOKEN OWNER
    owner = msg.sender; 

    // @dev: CHANGE AT TIME OF DEPLOYMENT
    cap = 60000 ether;

    saleTier[0].tokensToBeSold = (880000000)*TOKEN_DECIMALS;
    saleTier[0].bonusPercent = 40;
    saleTier[0].minContribution = 2 ether;

    saleTier[1].tokensToBeSold = (2750000000)*TOKEN_DECIMALS;
    saleTier[1].bonusPercent = 30;
    saleTier[1].minContribution = 1 ether;

    saleTier[2].tokensToBeSold = (2750000000)*TOKEN_DECIMALS;
    saleTier[2].bonusPercent = 20;
    saleTier[2].minContribution = 0.5 ether;

    saleTier[3].tokensToBeSold = 0;
    saleTier[3].bonusPercent = 0;
    saleTier[3].minContribution = 0.5 ether;

    for(uint8 i = 0; i<TIERS; i++){
      saleTier[i].price = 10000000000000; //wei per token based on $500 USD per ETH 0.005USD per token
    }
 }

  // @notice Accepts random Eth being sent, buyToknes rejects if address isn't whitelisted
  // @notice doesn't allow for owner to send ethereum to the contract in the event
  // of a refund, refund is done manually by owner
  function()
    public
    payable
  {
    buyTokens();
  }

  function startICO()
    public
    onlyOwner
   {
    require(!lock);
    token.transferFrom(owner, address(this), ICO_TOKENS);//transferring 6.38 billion tokens with 11 decimals to the crowdsale contract for distribution
    icoEndTime = now + 126 days;
    saleTier[0].tierEnd = now + 28 days;
    saleTier[1].tierEnd = now + 56 days;
    saleTier[2].tierEnd = now + 84 days;
    saleTier[3].tierEnd = now + 126 days;
    lock = true;
   } 

  // @notice buyer calls this function to order to get on the list for approval
  // buyers must send the ether with their whitelist application
  // @notice internal function called by the callback function
  // @param: _buyer is the msg.sender from the callback function //see if it works without
  // @param: _value is the msg.value from the callback function //see if it works without
  function buyTokens()
    internal
    icoIsActive
    activeContract
    
    returns (bool buySuccess)
  {
    
    Participant storage participant = participants[msg.sender];
    uint8 tier = calculateTier();
    require(ethPrice != 0);
    require(participant.whitelistStatus);
    uint256 remainingWei = msg.value.add(participant.remainingWei);
    require(msg.value.add(participant.remainingWei) >= saleTier[tier].minContribution);
    uint256 price = saleTier[tier].price; 
    participant.remainingWei = 0;
    uint256 totalTokensRequested;
    uint256 tierRemainingTokens;
    uint256 tknsRequested;
    
    while(remainingWei >= price && tier != TIERS) {
      SaleTier storage currentTier = saleTier[tier];
      price = currentTier.price;
      tknsRequested = (remainingWei.div(price)).mul(TOKEN_DECIMALS);
      tierRemainingTokens = currentTier.tokensToBeSold.sub(currentTier.tokensSold);
      if(tknsRequested >= tierRemainingTokens){
        tknsRequested -= tierRemainingTokens;
        totalTokensRequested += tierRemainingTokens;
        totalTokensRequested += calculateBonusTokens(tierRemainingTokens, tier);
        currentTier.tokensSold += totalTokensRequested;
        remainingWei -= ((tierRemainingTokens.mul(price)).div(TOKEN_DECIMALS));
        tier++;
      } else{
        totalTokensRequested += tknsRequested;
        totalTokensRequested += calculateBonusTokens(tknsRequested, tier);
        currentTier.tokensSold += totalTokensRequested;
        remainingWei -= ((tknsRequested.mul(price)).div(TOKEN_DECIMALS));
      }  
    }
    
    uint256 amount = msg.value.sub(remainingWei);
    totalTokensSold += totalTokensRequested; //includes bonus tokens
    weiRaised += amount;
    participant.remainingWei += remainingWei;
    participant.contrAmount += amount;
    emit LogTokensBought(msg.sender, totalTokensRequested);
    token.transfer(msg.sender, totalTokensRequested);
    if(weiRaised >= cap || now > icoEndTime || totalTokensSold == ICO_TOKENS){
      finalizeICO();
    }
    return true;
  }

  // @notice interface for founders to add addresses to the whitelist
  // @param listOfAddresses array of addresses that met the KYC/AML/Accreditation requirements
  function approveAddressForWhitelist(address[] listOfAddresses) 
    public 
    onlyOwner
    icoIsActive 
  {
    for(uint8 i = 0; i < listOfAddresses.length; i++){
      participants[listOfAddresses[i]].whitelistStatus = true;      
    }
  }

  // @notice pause specific functions of the contract
  function pauseContract() public onlyOwner {
    paused = true;
  }

  // @notice to unpause functions 
  function unpauseContract() public onlyOwner {
    paused = false;
  } 

  function checkContributorStatus()
    view
    public
    returns (bool whiteListed)
  {
    return (participants[msg.sender].whitelistStatus);
  }     

  // @notice owner withdraws ether periodically from the crowdsale contract 
  function ownerWithdrawal()
    public
    onlyOwner
    returns(bool success)
  {
    emit LogWithdrawal(msg.sender, address(this).balance);
    holdings.transfer(address(this).balance);
    return(true); 
  }

  // @notice calculate bonus tokens based on buyer token request
  // @param: _tokensRequested amount of tokens the buyer can get based on the wei sent 
  // @param: _tier which bonus tier the buyer has sent the wei
  function calculateBonusTokens(uint256 _tokensRequested, uint8 _tier)
    view
    internal
    returns (uint256 bonusTokens)
  {
    if(saleTier[_tier].bonusPercent > 0){
      bonusTokens = _tokensRequested.mul(saleTier[_tier].bonusPercent).div(uint256(100));
    }else{
      bonusTokens = 0; 
    } 
    return bonusTokens; 
  }

  // @notice calculates the tier based on end of tier and if there are tokens left in that tier
  function calculateTier()
    internal
    returns(uint8 _tier)
    {
      for(uint8 i = 0; i < TIERS; i++){
        if(saleTier[i].tierEnd < now && saleTier[i].tokensSold < saleTier[i].tokensToBeSold)
        {
          uint256 leftOverTokens = saleTier[i].tokensToBeSold - saleTier[i].tokensSold;
          saleTier[i].tokensToBeSold -= leftOverTokens;
          saleTier[i+1].tokensToBeSold + leftOverTokens;
        }
        if(saleTier[i].tierEnd >= now && saleTier[i].tokensSold < saleTier[i].tokensToBeSold)
        {
          _tier = i;
          break;
        }
      }
      return _tier;
    }

  /// @notice calculate unsold tokens for transfer to holdings to be used at a later date
  function calculateRemainingTokens()
    view
    internal
    returns (uint256 remainingTokens)
  {
    //uint256 remainingTokens;
    for(uint8 i = 0; i < TIERS; i++){
      if(saleTier[i].tokensSold < saleTier[i].tokensToBeSold){
        remainingTokens += saleTier[i].tokensToBeSold.sub(saleTier[i].tokensSold);
      }
    }
    return remainingTokens;
  }

  function finalizeICO()
    internal
  {
    token.burn(calculateRemainingTokens());
  }

  // @notice no ethereum will be held in the crowdsale contract
  // when refunds become available the amount of Ethererum needed will
  // be manually transfered back to the crowdsale to be refunded
  // @notice only the last person that buys tokens if they deposited enough to buy more 
  // tokens than what is available will be able to use this function
  function claimRemainingWei()
    external
    activeContract
    icoHasEnded
    returns (bool success)
  {
    Participant storage participant = participants[msg.sender];
    require(participant.whitelistStatus);
    require(participant.remainingWei != 0);
    uint256 sendValue = participant.remainingWei;
    participant.remainingWei = 0;
    emit LogWithdrawal(msg.sender, sendValue);
    msg.sender.transfer(sendValue);
    return true;
  }
}