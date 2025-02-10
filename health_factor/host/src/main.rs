// host/src/main.rs
use methods::{GUEST_CODE_FOR_ZK_PROOF_ELF, GUEST_CODE_FOR_ZK_PROOF_ID};
use risc0_zkvm::{default_prover, ExecutorEnv};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io;
#[derive(Serialize, Deserialize)]
struct HealthFactorInput {
    total_dsc_minted: u128,
    collateral_value_in_usd: u128,
}

#[derive(Serialize, Deserialize)]
pub struct ProofOutput {
    pub proof: String,
    pub pub_inputs: String,
    pub image_id: String,
}

fn main() {
    // Get user input
    let mut total_dsc_minted = String::new();
    let mut collateral_value_in_usd = String::new();

    println!("Enter total DSC minted:");
    io::stdin().read_line(&mut total_dsc_minted).unwrap();
    let total_dsc_minted: u128 = total_dsc_minted.trim().parse().expect("Invalid input");

    println!("Enter collateral value in USD:");
    io::stdin().read_line(&mut collateral_value_in_usd).unwrap();
    let collateral_value_in_usd: u128 = collateral_value_in_usd
        .trim()
        .parse()
        .expect("Invalid input");

    let input = HealthFactorInput {
        total_dsc_minted,
        collateral_value_in_usd,
    };

    // Initialize the executor environment
    let env = ExecutorEnv::builder()
        .write(&input)
        .unwrap()
        .build()
        .unwrap();

    // Create a prover
    let prover = default_prover();
    let prove_info = prover.prove(env, GUEST_CODE_FOR_ZK_PROOF_ELF).unwrap();

    // Generate the proof
    let receipt = prove_info.receipt;
    // Verify the proof
    receipt.verify(GUEST_CODE_FOR_ZK_PROOF_ID).unwrap();

    // Generate proof output for zkVerify
    let mut bin_receipt = Vec::new();
    ciborium::into_writer(&receipt, &mut bin_receipt).unwrap();
    let proof = hex::encode(&bin_receipt);

    fs::write("proof.txt", hex::encode(&bin_receipt)).unwrap();
    let receipt_journal_bytes_array = &receipt.journal.bytes.as_slice();
    let pub_inputs = hex::encode(&receipt_journal_bytes_array);

    let image_id_hex = hex::encode(
        GUEST_CODE_FOR_ZK_PROOF_ID
            .into_iter()
            .flat_map(|v| v.to_le_bytes().into_iter())
            .collect::<Vec<_>>(),
    );

    let proof_output = ProofOutput {
        proof: "0x".to_owned() + &proof,
        pub_inputs: "0x".to_owned() + &pub_inputs,
        image_id: "0x".to_owned() + &image_id_hex,
    };

    let proof_output_json = serde_json::to_string(&proof_output).unwrap();
    fs::write("proof.json", proof_output_json).unwrap();
    println!("Proof generated");
}
