use challenges_contract::contract::ChallengesContract;
use challenges_contract::contract::ChallengesContract::ContractState;

use challenges_contract::contract::interfaces::IChallengesContract;
use challenges_contract::contract::interfaces::IChallengesContractDispatcher;
use challenges_contract::contract::interfaces::IChallengesContractDispatcherTrait;

use challenges_contract::contract::interfaces::{
    IChallengesContract, IChallengesContractDispatcher, IChallengesContractDispatcherTrait
};

use snforge_std::{declare, ContractClassTrait};

use snforge_std::{
    start_cheat_caller_address_global, stop_cheat_caller_address_global, start_cheat_caller_address,
    stop_cheat_caller_address
};
use starknet::{ContractAddress, contract_address_const};

use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use challenges_contract::contract::errors::Errors;

pub fn get_state() -> ContractState {
    let mut state = ChallengesContract::contract_state_for_testing();
    let owner = get_owner();
    let contract_address = get_address_of_contract();

    state.ownable.initializer(owner);
    start_cheat_caller_address_global(owner);

    state.set_unclaimed_wait_seconds(60);
    state.set_address_of_contract(contract_address);
    stop_cheat_caller_address_global();

    state
}

pub fn get_owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

pub fn get_address_of_contract() -> ContractAddress {
    contract_address_const::<'contract_address'>()
}

pub fn get_token_name_1() -> ByteArray {
    "Lery Token"
}

pub fn get_token_symbol_1() -> ByteArray {
    "LTK"
}

pub fn deploy_erc20_contract(
    token_name: ByteArray, token_symbol: ByteArray, name: ByteArray
) -> IERC20Dispatcher {
    let erc20_contract_class = declare(name).unwrap();

    let recipient: ContractAddress = get_owner();

    let initial_supply: u256 = 1_000_000_000_000_000;

    let mut constructor_args: Array<felt252> = ArrayTrait::new();

    constructor_args.append(initial_supply.low.into());
    constructor_args.append(initial_supply.high.into());
    constructor_args.append(recipient.into());

    let (contract_address, _) = erc20_contract_class.deploy(@constructor_args).unwrap();

    let dispacher = IERC20Dispatcher { contract_address: contract_address };

    dispacher
}

pub fn transfer_token(
    sender: ContractAddress, receiver: ContractAddress, token: ContractAddress, amount: u256
) {
    let token_contract = IERC20Dispatcher { contract_address: token };

    start_cheat_caller_address_global(sender);

    token_contract.approve(receiver, amount);
    assert(token_contract.allowance(sender, receiver) == amount, 'failed to approve allowance');
    stop_cheat_caller_address_global();

    start_cheat_caller_address_global(receiver);
    token_contract.transfer_from(sender, receiver, amount);
    // assert_balance_of_token(token_contract, receiver, amount);
    stop_cheat_caller_address_global();
}

pub fn get_balance_of_token(token: IERC20Dispatcher, address: ContractAddress) -> u256 {
    token.balance_of(address)
}

pub fn deploy_contract(
    unclaimed_wait_seconds: u64, owner: ContractAddress
) -> IChallengesContractDispatcher {
    let name: ByteArray = "ChallengesContract";
    let contract_class_hash = declare(name).unwrap();

    let mut call_data: Array<felt252> = array![];
    Serde::<u64>::serialize(@unclaimed_wait_seconds, ref call_data);
    Serde::<ContractAddress>::serialize(@owner, ref call_data);

    let (contract_address, _) = contract_class_hash.deploy(@call_data).unwrap();
    let dispatcher = IChallengesContractDispatcher { contract_address: contract_address };

    dispatcher
}

pub fn deploy_contract_step_1() -> IChallengesContractDispatcher {
    let owner_param = get_owner();

    let dispatcher = deploy_contract(owner_param);

    let unclaimed_wait_seconds = dispatcher.get_unclaimed_wait_seconds();

    dispatcher
}

pub fn assert_balance_of_token(token: IERC20Dispatcher, address: ContractAddress, amount: u256) {
    let balance = get_balance_of_token(token, address);
    assert!(balance == amount, "balance issue, wanted: {}, got: {}", amount, balance);
}


