const { zkVerifySession, ZkVerifyEvents } = require("zkverifyjs");
const fs = require("fs");

// Load proof.json (Make sure the path is correct)
const proof = require("../health_factor/proof.json");

async function verifyProof() {
  console.log("Starting zkVerify session on Testnet...");
  const session = await zkVerifySession
    .start()
    .Testnet()
    .withAccount(process.env.SEED_PHRASE);

  console.log("Submitting proof for verification...");
  const { events, txResults } = await session
    .verify()
    .risc0()
    .waitForPublishedAttestation()
    .execute({
      proofData: {
        proof: proof.proof,
        vk: proof.image_id,
        publicSignals: proof.pub_inputs,
        version: "V1_2", // Mention the R0 version
      },
    });
  let attestationId, leafDigest;
  events.on(ZkVerifyEvents.IncludedInBlock, (eventData) => {
    console.log("Proof included in block:", eventData);
    attestationId = eventData.attestationId;
    leafDigest = eventData.leafDigest;
  });

  events.on(ZkVerifyEvents.Finalized, (eventData) => {
    console.log("Proof finalized:", eventData);
  });

  events.on(ZkVerifyEvents.AttestationConfirmed, async (eventData) => {
    console.log("Attestation Confirmed", eventData);
    const proofDetails = await session.poe(attestationId, leafDigest);
    proofDetails.attestationId = eventData.id;
    fs.writeFileSync("attestation.json", JSON.stringify(proofDetails, null, 2));
    console.log("proofDetails", proofDetails);
  });
}

// Run the verification
verifyProof();
