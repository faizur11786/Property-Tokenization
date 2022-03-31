// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require( "hardhat" );
const paymentAddress = require( "./paymentMethods.json" )

async function main () {
  printStars();
  console.log( "Deploying the PropertyNFT Contract...", );
  printStars();
  const PropertyNFT = await hre.ethers.getContractFactory( "PropertyNFT" )
  console.error( "Deploying..." );
  printStars();
  const propertyNFT = await PropertyNFT.deploy()
  await propertyNFT.deployed()
  console.log( "Contract successfully Deployed at:", propertyNFT.address )
  printStars();
  console.log( "\nAdding Payment Methods" );
  await propertyNFT.addPaymentMethod( paymentAddress )
  // printStars()
  console.log( `Payment methods added ${await propertyNFT.paymentMethodLength()}` );


  // const PropertyNFT = await hre.ethers.getContractFactory( "PropertyNFT" );
  // const propertyNFT = await PropertyNFT.deploy();
  // console.log( "Contract deployed" );
  // await propertyNFT.deployed();
  // console.log( "Greeter deployed at:", propertyNFT.address );
}

function printStars () {
  console.log( "\n*****************************************************" );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch( ( error ) => {
  console.error( error );
  process.exitCode = 1;
} );
