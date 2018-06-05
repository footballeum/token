pragma solidity 0.4.23;

import './Token.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract TeamWallet is Ownable{
  using SafeMath for uint256;

  uint256 constant public FREEZE_TIME = 365 days; //accounts for ICO days
  
  Token public token;
  uint256 public startTime;
  uint256 public totalWithdrawn;
  address public crowdsaleContract;

  mapping (address => uint256) teamMember;
  
  event LogWithdrawal(address _teamMember, uint256 _tokenAmount);
  

  modifier withdrawalAvailable() { 
    require(now >= startTime.add(FREEZE_TIME)); 
    _; 
  }
  
  constructor(address _token)
    public
  {  
    require(_token != 0x0);
    token = Token(_token);
    owner = msg.sender;
  }

  function setCrowdsaleContract(address _crowdsaleContract)
    public
    onlyOwner
  {
    crowdsaleContract = _crowdsaleContract;
  }

  
function setFreezeTime(uint256 freezeStartTime)
    external
  {
    require(msg.sender == crowdsaleContract);
    require(crowdsaleContract != address(0));
    startTime = freezeStartTime;
  }
  function addTeamMember(address _teamMember, uint256 _tokenAmount)
    public
    onlyOwner
    returns(bool success)
  {
    teamMember[_teamMember] = _tokenAmount;
    return true;
  }

  function transferTeamTokens()
    public
    withdrawalAvailable
    returns (bool success)
  {
    uint256 sendValue = teamMember[msg.sender];
    teamMember[msg.sender] = 0;
    token.transfer(msg.sender, sendValue);
    emit LogWithdrawal(msg.sender, sendValue);
    return true;
  }

}
