%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_tx_info
from starkware.cairo.common.bool import TRUE, FALSE

from chainlink.cairo.access.SimpleWriteAccessController.library import SimpleWriteAccessController

namespace SimpleReadAccessController:
    func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner_address : felt
    ):
        SimpleWriteAccessController.initialize(owner_address)
        return ()
    end

    # Gives access to:
    # - any externally owned account (note that offchain actors can always read
    # any contract storage regardless of onchain access control measures, so this
    # does not weaken the access control while improving usability)
    # - accounts explicitly added to an access list
    func has_access{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt, data_len : felt, data : felt*
    ) -> (bool : felt):
        let (has_access) = SimpleWriteAccessController.has_access(user, data_len, data)
        if has_access == TRUE:
            return (TRUE)
        end

        # NOTICE: access is granted to direct calls, to enable off-chain reads.
        if user == 0:
            return (TRUE)
        end

        # NOTICE: access is granted to account contracts, to enable off-chain reads.
        # The account abstraction architecture can be used to deploy a custom contract
        # that could access the data and pass it forward to a contract,
        # but a workflow like that would be of little use
        # because the contract would need to trust user inputs as it can't verify the data itself.
        # While the financial contract could accept calls from verified account contracts only (to verify data is correct),
        # it would be a risky strategy to depend on this part of infrastructure that can easily be upgraded.
        let (tx_info) = get_tx_info()
        if tx_info.account_contract_address == user:
            return (TRUE)
        end

        return (FALSE)
    end

    # TODO: remove when starkware adds get_class_hash_at
    func check_access{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt
    ):
        alloc_locals

        let empty_data_len = 0
        let (empty_data) = alloc()

        let (bool) = SimpleReadAccessController.has_access(user, empty_data_len, empty_data)
        with_attr error_message("AccessController: address does not have access"):
            assert bool = TRUE
        end

        return ()
    end
end
