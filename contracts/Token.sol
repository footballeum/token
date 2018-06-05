pragma solidity 0.4.23;

import 'zeppelin-solidity/contracts/token/ERC20/StandardToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';

contract Token is StandardToken, Ownable, BurnableToken {
    
    address public crowdsaleContract;
    string public constant symbol = "FTBL";
    string public constant name = "Footballeum";
    uint256 public constant decimals = 11;
    bool public paused;
 
  constructor()
    public
    {
        totalSupply_ = 11000000000 * 10**11;//11 billion 11 decimals
        paused = true;
        balances[msg.sender] = totalSupply_;
        assert(balances[owner] == totalSupply_);                
    }

    ///notice adds the ability to set the crowdsaleContract by the owner for transfer and transferfrom functions
  function setSaleContract(address crowdsale)
    public 
    onlyOwner 
    {
        crowdsaleContract = crowdsale;
    }

  ///notice once activated the tokens will be transferable by all token holders cannot be reverted
  function activate() 
    public
    onlyOwner 
    {
        paused = false;
    }
    
  function transfer(address _to, uint256 _value) 
    public 
    returns (bool) 
    {
        require (!paused || msg.sender == crowdsaleContract || owner); //doesnt allow transfer until unpaused or crowdsaleContract calls it
        return super.transfer(_to, _value);
    }

  function transferFrom(address _from, address _to, uint256 _value) 
    public 
    returns (bool) 
    {
        require (!paused || msg.sender == crowdsaleContract || owner); //doesnt allow transferFrom until unpaused or crowdsaleContract calls it
        return super.transferFrom(_from, _to, _value);
    }
}





