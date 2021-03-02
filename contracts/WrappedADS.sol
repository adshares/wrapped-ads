pragma solidity ^0.5.16;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Pausable.sol";
import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";
import "./OwnerRole.sol";

contract WrappedADS is ERC20, ERC20Detailed, ERC20Pausable, OwnerRole, MinterRole {
    using SafeMath for uint256;

    mapping (address => uint256) private _minterAllowances;

    /**
     *
     */
    constructor () public ERC20Detailed("Wrapped ADS", "WADS", 11) {

    }

    function wrapTo(address account, uint256 amount, uint64 from, uint64 txid) public onlyMinter returns (bool) {
        _checksumCheck(from);
        emit Wrap(account, from, txid, amount);
        _mint(account, amount);
        _minterApprove(_msgSender(), _minterAllowances[_msgSender()].sub(amount, "WrappedADS: minted amount exceeds minterAllowance"));
        return true;
    }

    /**
     * @dev Unwrap and destroy `amount` tokens from the caller.
     *
     */
    function unwrap(uint256 amount, uint64 to) public {
        _checksumCheck(to);
        emit Unwrap(_msgSender(), to, amount);
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Unwraps and destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     */
    function unwrapFrom(address account, uint256 amount, uint64 to) public {
        _checksumCheck(to);
        emit Unwrap(account, to, amount);
        _burnFrom(account, amount);
    }

    function minterAllowance(address minter) public view returns (uint256) {
        return _minterAllowances[minter];
    }

    /**
     * Set the minterAllowance granted to `minter`.
     *
     */
    function minterApprove(address minter, uint256 amount) public onlyOwner returns (bool) {
        _minterApprove(minter, amount);
        return true;
    }

    /**
     * @dev Atomically increases the minterAllowance granted to `minter`.
     *
     */
    function increaseMinterAllowance(address minter, uint256 addedValue) public onlyOwner returns (bool) {
        _minterApprove(minter, _minterAllowances[minter].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the minterAllowance granted to `minter`
     *
     */
    function decreaseMinterAllowance(address minter, uint256 subtractedValue) public onlyOwner returns (bool) {
        _minterApprove(minter, _minterAllowances[minter].sub(subtractedValue, "WrappedADS: decreased minterAllowance below zero"));
        return true;
    }

    function _minterApprove(address minter, uint256 amount) internal {
        require(isMinter(minter), "WrappedADS: minter approve for non-minting address");

        _minterAllowances[minter] = amount;
        emit MinterApproval(minter, amount);
    }

    function isMinter(address account) public view returns (bool) {
        return MinterRole.isMinter(account) || isOwner(account);
    }

    function removeMinter(address account) public onlyOwner {
        _minterApprove(account, 0);
        _removeMinter(account);
    }

    function isPauser(address account) public view returns (bool) {
        return PauserRole.isPauser(account) || isOwner(account);
    }

    function removePauser(address account) public onlyOwner {
        _removePauser(account);
    }

    function _checksumCheck(uint64 adsAddress) pure internal {
        uint8 x;
        uint16 crc = 0x1D0F;

        for(uint8 i=7;i>=2;i--) {
            x = (uint8)(crc >> 8) ^ ((uint8)(adsAddress >> i*8));
            x ^= x>>4;
            crc = (crc << 8) ^ ((uint16)(x) << 12) ^ ((uint16)(x) <<5) ^ ((uint16)(x));
        }

        require(crc == (adsAddress & 0xFFFF), "WrappedADS: invalid ADS address");
    }

    event Wrap(address indexed to, uint64 indexed from, uint64 txid, uint256 value);
    event Unwrap(address indexed from, uint64 indexed to, uint256 value);
    event MinterApproval(address indexed minter, uint256 value);
}