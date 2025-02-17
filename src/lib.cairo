pub mod contract {
    pub mod challenges_contract;
    pub mod interfaces;
    pub mod types;
    pub mod errors;
    // pub mod my_token_1;

    pub use interfaces::IChallengesContract;
    pub use types::{State, UserClaim};
    // #[cfg(test)]
// pub mod tests {
//     pub mod test_contract;
//     pub mod utils;
// }
}
