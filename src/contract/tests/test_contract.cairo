use core::clone::Clone;

use challenges_contract::contract::interfaces::IChallengesContract;
use challenges_contract::contract::interfaces::IChallengesContractDispatcher;
use challenges_contract::contract::interfaces::IChallengesContractDispatcherTrait;
use challenges_contract::contract::types::PeriodState;
use snforge_std::{
    stop_cheat_caller_address_global, start_cheat_caller_address_global,
    start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{contract_address_const};

use challenges_contract::contract::tests::utils::{
    get_state, get_owner, get_token_name_1, get_token_symbol_1, deploy_erc20_contract,
    transfer_token, assert_balance_of_token, deploy_contract, get_balance_of_token,
    get_end_timestamp, get_remainings_recipient,
};

#[test]
fn test_deploy_successful() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let owner = get_owner();
    let contract_name = contract_dispatcher.get_contract_name();
    let contract_owner = contract_dispatcher.get_owner();
    let challenge_token = contract_dispatcher.get_challenge_token();
    let end_timestamp = contract_dispatcher.get_end_timestamp();
    let remainings_recipient = contract_dispatcher.get_remainings_recipient();

    assert(contract_name == 'PulsarMoney Challenges v1.0.0', 'Contract name mismatch');
    assert(contract_owner == owner, 'Contract owner mismatch');
    assert(challenge_token == erc20_dispatcher.contract_address, 'Challenge token mismatch');
    assert(end_timestamp == get_end_timestamp(), 'End timestamp mismatch');
    assert(remainings_recipient == get_remainings_recipient(), 'Remainings recipient mismatch');
}

#[test]
fn test_setup_1() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amount(address1, amount1);
    stop_cheat_caller_address_global();

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amount(address2, amount2);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');
}

#[test]
fn test_setup_2() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    let amount3 = 90_000;
    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1], array![amount3]);
    stop_cheat_caller_address_global();

    let amount1_test_after = contract_dispatcher.get_claim_amount(address1);
    let amount2_test_after = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test_after == amount3, 'Amount 1 mismatch after update');
    assert(amount2_test_after == amount2, 'Amount 2 mismatch after update');

    let total_tokens_after = contract_dispatcher.get_total_tokens();
    assert(total_tokens_after == amount3 + amount2, 'Total tokens mismatch after');
}

#[test]
#[should_panic(expected: 'Insufficient token balance')]
fn test_setup_and_start_fail() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();
}

#[test]
fn test_setup_and_start() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_setup_only_owner() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(address1);
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_setup_and_start_only_owner() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(address1);
    contract_dispatcher.start();
    stop_cheat_caller_address_global();
}

#[test]
fn test_setup_and_start_and_claim() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    assert(amount1_test == amount1, 'Amount 1 mismatch');

    let has_claimed = contract_dispatcher.has_claimed(address1);
    assert(has_claimed, 'Has claimed mismatch');

    let total_tokens_after = contract_dispatcher.get_total_tokens();
    assert(total_tokens_after == amount2, 'Total tokens mismatch');

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == amount2, 'Contract balance mismatch');

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == amount1, 'Balance mismatch');
}

#[test]
#[should_panic(expected: 'Cannot claim')]
fn test_setup_and_start_cant_claim_twice() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    assert(amount1_test == amount1, 'Amount 1 mismatch');

    let has_claimed = contract_dispatcher.has_claimed(address1);
    assert(has_claimed, 'Has claimed mismatch');

    let total_tokens_after = contract_dispatcher.get_total_tokens();
    assert(total_tokens_after == amount2, 'Total tokens mismatch');

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == amount2, 'Contract balance mismatch');

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == amount1, 'Balance mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Cannot claim')]
fn test_setup_and_start_cant_claim_if_no_amount_set() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();
    let address3 = contract_address_const::<'address3'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let balance = get_balance_of_token(erc20_dispatcher, address3);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address3);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Cannot claim')]
fn test_setup_cant_claim_not_started() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();
    let address3 = contract_address_const::<'address3'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
}

#[test]
fn test_setup_and_start_and_claim_and_end() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    assert(amount1_test == amount1, 'Amount 1 mismatch');

    let has_claimed = contract_dispatcher.has_claimed(address1);
    assert(has_claimed, 'Has claimed mismatch');

    let total_tokens_after = contract_dispatcher.get_total_tokens();
    assert(total_tokens_after == amount2, 'Total tokens mismatch');

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == amount2, 'Contract balance mismatch');

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == amount1, 'Balance mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, get_owner());
    start_cheat_block_timestamp_global(get_end_timestamp() + 1);
    contract_dispatcher.end();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
    stop_cheat_block_timestamp_global();

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == 0, 'Contract balance mismatch2');

    let balance_1 = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance_1 == amount1, 'Balance mismatch');

    let balance_2 = get_balance_of_token(erc20_dispatcher, address2);
    assert(balance_2 == 0, 'Balance mismatch');

    let end_timestamp = contract_dispatcher.get_end_timestamp();
    assert(end_timestamp == get_end_timestamp(), 'End timestamp mismatch');

    let period_state = contract_dispatcher.get_period_state();
    assert(period_state == PeriodState::Ended, 'Period state mismatch');

    let balance_owner = get_balance_of_token(erc20_dispatcher, get_owner());
    assert(balance_owner == 1_000_000_000_000_000 - amount1 - amount2, 'Balance owner mismatch');

    let balance_recipient = get_balance_of_token(erc20_dispatcher, get_remainings_recipient());
    assert(balance_recipient == amount2, 'Balance recipient mismatch');
}

#[test]
#[should_panic(expected: 'Unauthorized')]
fn test_setup_and_start_and_claim_and_end_only_owner() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    assert(amount1_test == amount1, 'Amount 1 mismatch');

    let has_claimed = contract_dispatcher.has_claimed(address1);
    assert(has_claimed, 'Has claimed mismatch');

    let total_tokens_after = contract_dispatcher.get_total_tokens();
    assert(total_tokens_after == amount2, 'Total tokens mismatch');

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == amount2, 'Contract balance mismatch');

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == amount1, 'Balance mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    start_cheat_block_timestamp_global(get_end_timestamp() + 1);
    contract_dispatcher.end();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
    stop_cheat_block_timestamp_global();
}

#[test]
#[should_panic(expected: 'Claim ended')]
fn test_setup_and_start_and_claim_and_end_and_claim() {
    let (contract_dispatcher, erc20_dispatcher) = deploy_contract();

    let address1 = contract_address_const::<'address1'>();
    let address2 = contract_address_const::<'address2'>();

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Setup, 'Period state mismatch');

    let amount1 = 100_000;
    let amount2 = 200_000;

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.set_claim_amounts(array![address1, address2], array![amount1, amount2]);
    stop_cheat_caller_address_global();

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    let amount2_test = contract_dispatcher.get_claim_amount(address2);

    assert(amount1_test == amount1, 'Amount 1 mismatch');
    assert(amount2_test == amount2, 'Amount 2 mismatch');

    let total_tokens = contract_dispatcher.get_total_tokens();
    assert(total_tokens == amount1 + amount2, 'Total tokens mismatch');

    transfer_token(
        get_owner(),
        contract_dispatcher.contract_address,
        erc20_dispatcher.contract_address,
        total_tokens,
    );

    start_cheat_caller_address_global(get_owner());
    contract_dispatcher.start();
    stop_cheat_caller_address_global();

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == 0, 'Balance mismatch');

    let state = contract_dispatcher.get_period_state();
    assert(state == PeriodState::Claim, 'Period state mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address1);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);

    let amount1_test = contract_dispatcher.get_claim_amount(address1);
    assert(amount1_test == amount1, 'Amount 1 mismatch');

    let has_claimed = contract_dispatcher.has_claimed(address1);
    assert(has_claimed, 'Has claimed mismatch');

    let total_tokens_after = contract_dispatcher.get_total_tokens();
    assert(total_tokens_after == amount2, 'Total tokens mismatch');

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == amount2, 'Contract balance mismatch');

    let balance = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance == amount1, 'Balance mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, get_owner());
    start_cheat_block_timestamp_global(get_end_timestamp() + 1);
    contract_dispatcher.end();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
    stop_cheat_block_timestamp_global();

    let contract_balance = get_balance_of_token(
        erc20_dispatcher, contract_dispatcher.contract_address,
    );
    assert(contract_balance == 0, 'Contract balance mismatch2');

    let balance_1 = get_balance_of_token(erc20_dispatcher, address1);
    assert(balance_1 == amount1, 'Balance mismatch');

    let balance_2 = get_balance_of_token(erc20_dispatcher, address2);
    assert(balance_2 == 0, 'Balance mismatch');

    let end_timestamp = contract_dispatcher.get_end_timestamp();
    assert(end_timestamp == get_end_timestamp(), 'End timestamp mismatch');

    let period_state = contract_dispatcher.get_period_state();
    assert(period_state == PeriodState::Ended, 'Period state mismatch');

    let balance_owner = get_balance_of_token(erc20_dispatcher, get_owner());
    assert(balance_owner == 1_000_000_000_000_000 - amount1 - amount2, 'Balance owner mismatch');

    let balance_recipient = get_balance_of_token(erc20_dispatcher, get_remainings_recipient());
    assert(balance_recipient == amount2, 'Balance recipient mismatch');

    start_cheat_caller_address(contract_dispatcher.contract_address, address2);
    contract_dispatcher.claim();
    stop_cheat_caller_address(contract_dispatcher.contract_address);
}

