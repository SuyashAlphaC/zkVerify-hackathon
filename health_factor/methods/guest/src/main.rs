// methods/guest/src/main.rs
#![no_main]
risc0_zkvm::guest::entry!(main);

use risc0_zkvm::guest::env;

const LIQUIDATION_THRESHOLD: u128 = 50;
const LIQUIDATION_PRECISION: u128 = 100;
const PRECISION: u128 = 1_000_000_000_000_000_000; // 1e18

pub fn main() {
    // Read the input values directly from the host
    let total_dsc_minted: u128 = env::read();
    let collateral_value_in_usd: u128 = env::read();

    // Calculate health factor
    let health_factor = if total_dsc_minted == 0 {
        u128::MAX
    } else {
        let collateral_adjusted =
            (collateral_value_in_usd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        (collateral_adjusted * PRECISION) / total_dsc_minted
    };

    // Commit the result
    env::commit(&health_factor);
    env::commit(&collateral_value_in_usd);
    env::commit(&total_dsc_minted);
}
