use starknet::ContractAddress;
use challenges_contract::contract::types::PeriodState;
use challenges_contract::contract::types::UserClaim;

#[starknet::interface]
pub trait IChallengesContract<TContractState> {
    fn get_total_tokens(self: @TContractState) -> u256;
    fn get_claim_amount(self: @TContractState, user: ContractAddress) -> u256;

    fn start(ref self: TContractState);
    fn end(ref self: TContractState);
    fn set_state(ref self: TContractState, new_state: PeriodState);
    fn set_claim_amount(ref self: TContractState, user: ContractAddress, amount: u256);
    fn set_claim_amounts(
        ref self: TContractState, users: Array<ContractAddress>, amounts: Array<u256>,
    );

    fn set_address_of_contract(ref self: TContractState, address: ContractAddress);
    fn set_end_timestamp(ref self: TContractState, end_timestamp: u64);

    fn can_claim(self: @TContractState, user: ContractAddress) -> bool;
    fn claim(ref self: TContractState);
    fn has_claimed(self: @TContractState, user: ContractAddress) -> bool;

    fn get_contract_name(self: @TContractState) -> felt252;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_challenge_token(self: @TContractState) -> ContractAddress;
    fn get_period_state(self: @TContractState) -> PeriodState;
    fn get_claim_info(self: @TContractState, user: ContractAddress) -> UserClaim;
    fn get_end_timestamp(self: @TContractState) -> u64;
    fn get_remainings_recipient(self: @TContractState) -> ContractAddress;
    fn set_remainings_recipient(ref self: TContractState, remainings_recipient: ContractAddress);
}
