const { expectEvent, constants } = require( "@openzeppelin/test-helpers" );
const { expect } = require( "chai" );
const { ethers } = require( "hardhat" );

const paymentAddress = require( "../scripts/paymentMethods.json" )

const propertyURI = "0x697066733a2f2f516d63617954786344694c526b617475566258416554554a514d385743587138626b756b3579314d726343744477"


describe( "PropertyNFT", function () {

    let propertyNFT, tokenization

    before( async () => {
        const PropertyNFT = await ethers.getContractFactory( "PropertyNFT" )
        propertyNFT = await PropertyNFT.deploy();

    } );

    it( "Should add array of Payment methods.", async function () {
        await propertyNFT.addPaymentMethod( paymentAddress )
    } );
    it( "Should return Added payment methods length", async () => {
        expect( await propertyNFT.paymentMethodLength() ).to.equal( paymentAddress.length )
    } );
    it( "Should List Property and deploy Tokenization contract", async () => {
        const reciept = await propertyNFT.listProperty(
            69,
            "AQR696969HEY",
            "The 69 View",
            "TV69",
            propertyURI,
            "0x675bE6d0B35117D21C538d3363C5DB7699658157",
            true
        )
        reciept.wait()
        const propertyId = await propertyNFT.tokenIds()
        expect( propertyId ).to.be.not.equal( 0 )
        await propertyNFT.properties( propertyId ).then( async result => {
            expect( result["propertyAddress"] ).to.be.not.undefined
        } );
    } )
    it( "Should Deploy Property Tokenization ccontract", async () => {
        const propertyId = await propertyNFT.tokenIds()
        expect( propertyId ).to.be.not.equal( 0 )
        await propertyNFT.properties( propertyId ).then( async ( result ) => {
            expect( result["propertyAddress"] ).to.be.not.undefined;
            tokenization = await ethers.getContractAt( "PropertyTokenization", result["propertyAddress"] );
            expect( await tokenization.propetySymbol() ).to.equal( "TV69" )
        } );
    } );
    it( "Should ", async () => {
        // const account = 
        console.log();
    } )
    describe( "Tokenization", async () => {
        it( "Shoul", () => {
            console.log( constants );
        } )
    } )

} );
