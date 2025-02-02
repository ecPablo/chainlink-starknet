use starknet::class_hash_const;
use starknet::contract_address_const;
use starknet::syscalls::deploy_syscall;
use starknet::testing::set_caller_address;
use starknet::testing::set_contract_address;
use starknet::Felt252TryIntoClassHash;

use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
use traits::TryInto;

use chainlink::multisig::assert_unique_values;
use chainlink::multisig::Multisig;

#[contract]
mod MultisigTest {
    use array::ArrayTrait;

    #[external]
    fn increment(val1: felt252, val2: felt252) -> Array<felt252> {
        let mut ret = ArrayTrait::new();
        ret.append(val1 + 1);
        ret.append(val2 + 1);
        ret
    }
}

// TODO: test set_threshold with recursive call
// TODO: test set_signers with recursive call
// TODO: test set_signers_and_thershold with recursive call

fn sample_calldata() -> Array::<felt252> {
    let mut calldata = ArrayTrait::new();
    calldata.append(1);
    calldata.append(2);
    calldata.append(3);
    calldata
}

#[test]
#[available_gas(2000000)]
fn test_assert_unique_values_empty() {
    let mut a = ArrayTrait::<felt252>::new();
    assert_unique_values(@a);
}

#[test]
#[available_gas(2000000)]
fn test_assert_unique_values_no_duplicates() {
    let mut a = ArrayTrait::new();
    a.append(1);
    a.append(2);
    a.append(3);
    assert_unique_values(@a);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_assert_unique_values_with_duplicate() {
    let mut a = ArrayTrait::new();
    a.append(1);
    a.append(2);
    a.append(3);
    a.append(3);
    assert_unique_values(@a);
}

#[test]
#[available_gas(2000000)]
fn test_is_signer_true() {
    let signer = contract_address_const::<1>();
    let mut signers = ArrayTrait::new();
    signers.append(signer);
    Multisig::constructor(:signers, threshold: 1);
    assert(Multisig::is_signer(signer), 'should be signer');
}

#[test]
#[available_gas(2000000)]
fn test_is_signer_false() {
    let not_signer = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(contract_address_const::<1>());
    Multisig::constructor(:signers, threshold: 1);
    assert(!Multisig::is_signer(not_signer), 'should be signer');
}

#[test]
#[available_gas(2000000)]
fn test_signer_len() {
    let mut signers = ArrayTrait::new();
    signers.append(contract_address_const::<1>());
    signers.append(contract_address_const::<2>());
    Multisig::constructor(:signers, threshold: 1);
    assert(Multisig::get_signers_len() == 2, 'should equal 2 signers');
}

#[test]
#[available_gas(2000000)]
fn test_get_signers() {
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);

    Multisig::constructor(:signers, threshold: 1);
    let returned_signers = Multisig::get_signers();
    assert(returned_signers.len() == 2, 'should match signers length');
    assert(*returned_signers.at(0) == signer1, 'should match signer 1');
    assert(*returned_signers.at(1) == signer2, 'should match signer 2');
}

#[test]
#[available_gas(2000000)]
fn test_get_threshold() {
    let mut signers = ArrayTrait::new();
    signers.append(contract_address_const::<1>());
    signers.append(contract_address_const::<2>());
    Multisig::constructor(:signers, threshold: 1);
    assert(Multisig::get_threshold() == 1, 'should equal threshold of 1');
}

#[test]
#[available_gas(2000000)]
fn test_submit_transaction() {
    let signer = contract_address_const::<1>();
    let mut signers = ArrayTrait::new();
    signers.append(signer);
    Multisig::constructor(:signers, threshold: 1);

    set_caller_address(signer);
    let to = contract_address_const::<42>();
    let function_selector = 10;
    Multisig::submit_transaction(:to, :function_selector, calldata: sample_calldata());

    let (transaction, calldata) = Multisig::get_transaction(0);
    assert(transaction.to == to, 'should match target address');
    assert(transaction.function_selector == function_selector, 'should match function selector');
    assert(transaction.calldata_len == sample_calldata().len(), 'should match calldata length');
    assert(!transaction.executed, 'should not be executed');
    assert(transaction.confirmations == 0, 'should not have confirmations');
// TODO: compare calldata when loops are supported
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_submit_transaction_not_signer() {
    let signer = contract_address_const::<1>();
    let mut signers = ArrayTrait::new();
    signers.append(signer);
    Multisig::constructor(:signers, threshold: 1);

    set_caller_address(contract_address_const::<3>());
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
}

#[test]
#[available_gas(2000000)]
fn test_confirm_transaction() {
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);

    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);

    assert(Multisig::is_confirmed(nonce: 0, signer: signer1), 'should be confirmed');
    assert(!Multisig::is_confirmed(nonce: 0, signer: signer2), 'should not be confirmed');
    let (transaction, _) = Multisig::get_transaction(0);
    assert(transaction.confirmations == 1, 'should have confirmation');
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_confirm_transaction_not_signer() {
    let signer = contract_address_const::<1>();
    let not_signer = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer);
    Multisig::constructor(:signers, threshold: 1);
    set_caller_address(signer);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );

    set_caller_address(not_signer);
    Multisig::confirm_transaction(nonce: 0);
}

#[test]
#[available_gas(4000000)]
fn test_revoke_confirmation() {
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);

    Multisig::revoke_confirmation(nonce: 0);

    assert(!Multisig::is_confirmed(nonce: 0, signer: signer1), 'should not be confirmed');
    assert(!Multisig::is_confirmed(nonce: 0, signer: signer2), 'should not be confirmed');
    let (transaction, _) = Multisig::get_transaction(0);
    assert(transaction.confirmations == 0, 'should not have confirmation');
}

#[test]
#[available_gas(4000000)]
#[should_panic]
fn test_revoke_confirmation_not_signer() {
    let signer = contract_address_const::<1>();
    let not_signer = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);

    set_caller_address(not_signer);
    Multisig::revoke_confirmation(nonce: 0);
}

#[test]
#[available_gas(2000000)]
#[should_panic]
fn test_execute_confirmation_below_threshold() {
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);
    Multisig::execute_transaction(nonce: 0);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('only multisig allowed', ))]
fn test_upgrade_not_multisig() {
    let account = contract_address_const::<777>();
    set_caller_address(account);

    Multisig::upgrade(class_hash_const::<1>())
}

#[test]
#[available_gas(80000000)]
fn test_execute() {
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    let (test_address, _) = deploy_syscall(
        MultisigTest::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), false
    )
        .unwrap();
    set_caller_address(signer1);
    let mut increment_calldata = ArrayTrait::new();
    increment_calldata.append(42);
    increment_calldata.append(100);
    Multisig::submit_transaction(
        to: test_address,
        // increment()
        function_selector: 0x7a44dde9fea32737a5cf3f9683b3235138654aa2d189f6fe44af37a61dc60d,
        calldata: increment_calldata,
    );
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(signer2);
    Multisig::confirm_transaction(nonce: 0);

    let response = Multisig::execute_transaction(nonce: 0);
    assert(response.len() == 3, 'expected response length 3');
    assert(*response.at(0) == 2, 'expected array length 2');
    assert(*response.at(1) == 43, 'expected array value 43');
    assert(*response.at(2) == 101, 'expected array value 101');
}

#[test]
#[available_gas(8000000)]
#[should_panic(expected: ('invalid signer', ))]
fn test_execute_not_signer() {
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(signer2);
    Multisig::confirm_transaction(nonce: 0);

    set_caller_address(contract_address_const::<3>());
    Multisig::execute_transaction(nonce: 0);
}

#[test]
#[available_gas(8000000)]
#[should_panic(expected: ('transaction invalid', ))]
fn test_execute_after_set_signers() {
    let contract_address = contract_address_const::<100>();
    set_contract_address(contract_address);
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let signer3 = contract_address_const::<3>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(signer2);
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(contract_address);
    let mut new_signers = ArrayTrait::new();
    new_signers.append(signer2);
    new_signers.append(signer3);
    Multisig::set_signers(new_signers);

    set_caller_address(signer2);
    Multisig::execute_transaction(nonce: 0);
}

#[test]
#[available_gas(8000000)]
#[should_panic(expected: ('transaction invalid', ))]
fn test_execute_after_set_signers_and_threshold() {
    let contract_address = contract_address_const::<100>();
    set_contract_address(contract_address);
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let signer3 = contract_address_const::<3>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(signer2);
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(contract_address);
    let mut new_signers = ArrayTrait::new();
    new_signers.append(signer2);
    new_signers.append(signer3);
    Multisig::set_signers_and_threshold(new_signers, 1);

    set_caller_address(signer2);
    Multisig::execute_transaction(nonce: 0);
}

#[test]
#[available_gas(8000000)]
#[should_panic(expected: ('transaction invalid', ))]
fn test_execute_after_set_threshold() {
    let contract_address = contract_address_const::<100>();
    set_contract_address(contract_address);
    let signer1 = contract_address_const::<1>();
    let signer2 = contract_address_const::<2>();
    let mut signers = ArrayTrait::new();
    signers.append(signer1);
    signers.append(signer2);
    Multisig::constructor(:signers, threshold: 2);
    set_caller_address(signer1);
    Multisig::submit_transaction(
        to: contract_address_const::<42>(), function_selector: 10, calldata: sample_calldata(), 
    );
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(signer2);
    Multisig::confirm_transaction(nonce: 0);
    set_caller_address(contract_address);
    Multisig::set_threshold(1);

    set_caller_address(signer1);
    Multisig::execute_transaction(nonce: 0);
}
