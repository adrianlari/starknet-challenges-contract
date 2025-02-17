// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.17.0

#[starknet::contract]
pub mod ChallengesContract {
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::security::ReentrancyGuardComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::security::reentrancyguard::{ReentrancyGuardComponent};
    use starknet::get_caller_address;
    use starknet::ClassHash;
    use starknet::get_block_timestamp;
    use starknet::contract_address::{ContractAddress, contract_address_const};
    use challenges_contract::contract::IChallengesContract;
    use challenges_contract::contract::types::State;
    use challenges_contract::contract::types::UserClaim;
    use starknet::storage::Map;
    use challenges_contract::contract::errors::Errors;

    // use starknet::storage_var;
    // use starknet::syscalls::{call_contract_syscall, SyscallResult};
    // use starknet::uint::U256;
    // use starknet::option::Option::{Some, None};
    // use starknet::traits::{Into, TryInto};

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        period_state: State,
        challenge_token: ContractAddress,
        total_tokens: u256,
        claims: Map<ContractAddress, UserClaim>,
        contract_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimEvent {
        pub user: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StartedEvent {
        pub challenge_token: ContractAddress,
        pub total_tokens: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EndedEvent {
        pub challenge_token: ContractAddress,
        pub total_tokens: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StateChangedEvent {
        pub new_state: State,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        ClaimEvent: ClaimEvent,
        StartedEvent: StartedEvent,
        EndedEvent: EndedEvent,
        StateChangedEvent: StateChangedEvent,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl ChallengesContractImpl of IChallengesContract<ContractState> {
        fn start(ref self: ContractState) {
            self.require_only_owner();

            self.reentrancy_guard.start();

            assert(self.period_state.read() == State::Setup, Errors::INVALID_STATE);

            self
                .require_enough_token_balance(
                    self.contract_address.read(),
                    self.challenge_token.read(),
                    self.total_tokens.read(),
                );

            self.period_state.write(State::Claim);
            self
                .emit(
                    Event::StartedEvent(
                        StartedEvent {
                            challenge_token: self.challenge_token.read(),
                            total_tokens: self.total_tokens.read(),
                        },
                    ),
                );

            self.reentrancy_guard.end();
        }

        fn end(ref self: ContractState) {
            self.require_only_owner();

            self.reentrancy_guard.start();

            assert(self.period_state.read() == State::Claim, Errors::INVALID_STATE);

            self.period_state.write(State::Ended);
            self
                .emit(
                    Event::EndedEvent(
                        EndedEvent {
                            challenge_token: self.challenge_token.read(),
                            total_tokens: self.total_tokens.read(),
                        },
                    ),
                );

            self.reentrancy_guard.end();
        }

        fn set_state(ref self: ContractState, new_state: State) {
            self.require_only_owner();

            self.reentrancy_guard.start();

            self.period_state.write(new_state);
            self.emit(Event::StateChangedEvent(StateChangedEvent { new_state: new_state }));

            self.reentrancy_guard.end();
        }

        fn set_claim_amount(ref self: ContractState, user: ContractAddress, amount: u256) {
            self.require_only_owner();

            self.reentrancy_guard.start();

            self.set_claim_amount_internal(user, amount);

            self.reentrancy_guard.end();
        }

        fn set_claim_amounts(
            ref self: ContractState, users: Array<ContractAddress>, amounts: Array<u256>,
        ) { 
            self.require_only_owner();

            self.reentrancy_guard.start();

            assert(users.len() == amounts.len(), Errors::MISMATCHING_LENGTHS);

            for i in 0..users.len() {
                self.set_claim_amount_internal(*users.at(i), *amounts.at(i));
            };

            self.reentrancy_guard.end();
        }

        fn can_claim(self: @ContractState, user: ContractAddress) -> bool {
            if self.period_state.read() != State::Claim {
                return false;
            }

            let user_claim = self.claims.read(user);
            if user_claim.has_claimed {
                return false;
            }

            if user_claim.amount == 0 {
                return false;
            }

            if user_claim.timestamp > 0 {
                return false;
            }

            return true;
        }

        fn claim(ref self: ContractState) { 
            let user = get_caller_address();
            assert(self.can_claim(user), Errors::CANNOT_CLAIM);

            self.reentrancy_guard.start();

            let mut user_claim = self.claims.read(user);
            user_claim.has_claimed = true;
            user_claim.timestamp = get_block_timestamp();

            self.total_tokens.write(self.total_tokens.read() - user_claim.amount);

            self.transfer_tokens(self.challenge_token.read(), user, user_claim.amount);

            self.emit(Event::ClaimEvent(ClaimEvent { user: user, amount: user_claim.amount, timestamp: user_claim.timestamp }));

            self.reentrancy_guard.end();
        }

        fn has_claimed(
            self: @ContractState, user: ContractAddress,
        ) -> bool { 
            let user_claim = self.claims.read(user);
            return user_claim.has_claimed;
        }

        fn get_claim_amount(
            self: @ContractState, user: ContractAddress,
        ) -> u256 { 
            let user_claim = self.claims.read(user);
            return user_claim.amount;
        }

        fn get_total_tokens(self: @ContractState) -> u256 { 
            return self.total_tokens.read();
        }

    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn pause(ref self: ContractState) { 
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        #[external(v0)]
        fn unpause(ref self: ContractState) { 
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn require_only_owner(self: @ContractState) {
            self.ownable.assert_only_owner();
        }

        fn transfer_tokens(
            ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256,
        ) { 
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let result = token_dispatcher.transfer(to, amount);
            assert(result, Errors::TRANSFER_FAILED);
        }

        fn require_enough_token_balance(
            self: @ContractState, user: ContractAddress, token: ContractAddress, amount: u256,
        ) {
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let balance = token_dispatcher.balance_of(user);

            assert(balance >= amount, Errors::INSUFFICIENT_TOKEN_BALANCE);
        }

        fn require_enough_allowance(
            self: @ContractState,
            user: ContractAddress,
            token: ContractAddress,
            amount: u256,
            spender: ContractAddress,
        ) {
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let allowance = token_dispatcher.allowance(user, spender);

            assert(allowance >= amount, Errors::INSUFFICIENT_TOKEN_ALLOWANCE);
        }

        fn get_zero_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0>()
        }

        fn set_claim_amount_internal(ref self: ContractState, user: ContractAddress, amount: u256) {
            assert(amount > 0, Errors::AMOUNT_NOT_ENOUGH);
            assert(self.period_state.read() == State::Setup, Errors::INVALID_STATE);

            let mut user_claim = self.claims.read(user);
         
            if user_claim.amount > 0 {
                let tokens = self.total_tokens.read() - user_claim.amount;
                self.total_tokens.write(tokens);
            }

            user_claim.amount = amount;
            self.claims.write(user, UserClaim { amount: amount, has_claimed: false, timestamp: 0 });

            let tokens = self.total_tokens.read() + amount;
            self.total_tokens.write(tokens);
        }
    }
}

