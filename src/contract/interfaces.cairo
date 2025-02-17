use starknet::ContractAddress;
use challenges_contract::contract::types::State;

#[starknet::interface]
pub trait IChallengesContract<TContractState> {
    fn get_total_tokens(self: @TContractState) -> u256;
    fn get_claim_amount(self: @TContractState, user: ContractAddress) -> u256;
  
    fn start(ref self: TContractState);
    fn end(ref self: TContractState);
    fn set_state(ref self: TContractState, new_state: State);
    fn set_claim_amount(ref self: TContractState, user: ContractAddress, amount: u256);
    fn set_claim_amounts(
        ref self: TContractState, users: Array<ContractAddress>, amounts: Array<u256>,
    );

    fn can_claim(self: @TContractState, user: ContractAddress) -> bool;
    fn claim(ref self: TContractState);
    fn has_claimed(self: @TContractState, user: ContractAddress) -> bool;
}
