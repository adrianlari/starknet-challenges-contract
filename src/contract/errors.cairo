pub mod Errors {
    pub const INVALID_STATE: felt252 = 'Invalid state';
    pub const INSUFFICIENT_TOKEN_BALANCE: felt252 = 'Insufficient token balance';
    pub const INSUFFICIENT_TOKEN_ALLOWANCE: felt252 = 'Insufficient token allowance';
    pub const AMOUNT_NOT_ENOUGH: felt252 = 'Amount not enough';
    pub const MISMATCHING_LENGTHS: felt252 = 'Mismatching lengths';
    pub const CANNOT_CLAIM: felt252 = 'Cannot claim';
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
    pub const CANNOT_END: felt252 = 'Cannot end';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const CLAIM_ENDED: felt252 = 'Claim ended';
}
