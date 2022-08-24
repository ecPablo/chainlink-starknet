%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import FALSE, TRUE
from openzeppelin.token.erc20.library import ERC20
from openzeppelin.token.erc20.presets.ERC20Upgradeable import (
    initializer,
    upgrade,
    name,
    symbol,
    totalSupply,
    decimals,
    balanceOf,
    allowance,
    transfer,
    transferFrom,
    approve,
    increaseAllowance,
    decreaseAllowance,
)
from starkware.starknet.std_contracts.ERC20.permitted import (
    permitted_initializer,
    permitted_minter_only,
    permittedMinter,
)
from contracts.ERC677.library import ERC677
from contracts.ERC677.interfaces.IERC677Receiver import IERC677Receiver

const NAME = 'ChainLink Token'
const SYMBOL = 'LINK'

@external
func link_initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    initial_supply : Uint256, recipient : felt, proxy_admin : felt
):
    alloc_locals
    initializer(NAME, SYMBOL, 18, initial_supply, recipient, proxy_admin)
    permitted_initializer(recipient)
    return ()
end

# This implements Starkgate IMintableToken interface
@external
func permissionedMint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
):
    alloc_locals
    permitted_minter_only()
    local syscall_ptr : felt* = syscall_ptr

    ERC20._mint(recipient=recipient, amount=amount)

    return ()
end

@external
func permissionedBurn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt, amount : Uint256
):
    alloc_locals
    permitted_minter_only()
    local syscall_ptr : felt* = syscall_ptr

    ERC20._burn(account=account, amount=amount)

    return ()
end

# This implements the ERC677 interface
@external
func transferAndCall{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, value : Uint256, data_len : felt, data : felt*
) -> (success : felt):
    ERC677.transfer_and_call(to, value, data_len, data)
    return (TRUE)
end

@view
func type_and_version() -> (meta : felt):
    return ('LinkToken 0.0.1')
end
