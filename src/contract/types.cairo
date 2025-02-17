#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum State {
    #[default]
    Setup,
    Claim,
    Ended,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserClaim {
    pub amount: u256,
    pub has_claimed: bool,
    pub timestamp: u64,
}

