import FungibleToken from 0xFUNGIBLE_TOKEN_ADDRESS
import FUSD from 0xFUSD_ADDRESS
import Profile from 0xVERSUS_ADDRESS
import FIND from 0xFIND_ADDRESS


transaction(name: String, amount: UFix64) {
	prepare(acct: AuthAccount) {

		//Add exising FUSD or create a new one and add it
		let fusdReceiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/fusdReceiver)
		if !fusdReceiver.check() {
			let fusd <- FUSD.createEmptyVault()
			acct.save(<- fusd, to: /storage/fusdVault)
			acct.link<&FUSD.Vault{FungibleToken.Receiver}>( /public/fusdReceiver, target: /storage/fusdVault)
			acct.link<&FUSD.Vault{FungibleToken.Balance}>( /public/fusdBalance, target: /storage/fusdVault)
		}

		let leaseCollection = acct.getCapability<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>(FIND.LeasePublicPath)
		if !leaseCollection.check() {
			acct.unlink(FIND.LeasePublicPath)
			destroy <- acct.load<@AnyResource>(from:FIND.LeaseStoragePath)

			acct.save(<- FIND.createEmptyLeaseCollection(), to: FIND.LeaseStoragePath)
			acct.link<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>( FIND.LeasePublicPath, target: FIND.LeaseStoragePath)
		}

		let bidCollection = acct.getCapability<&FIND.BidCollection{FIND.BidCollectionPublic}>(FIND.BidPublicPath)
		if !bidCollection.check() {
			acct.unlink(FIND.BidPublicPath)
			destroy <- acct.load<@AnyResource>(from:FIND.BidStoragePath)

			acct.save(<- FIND.createEmptyBidCollection(receiver: fusdReceiver, leases: leaseCollection), to: FIND.BidStoragePath)
			acct.link<&FIND.BidCollection{FIND.BidCollectionPublic}>( FIND.BidPublicPath, target: FIND.BidStoragePath)
		}

		let profileCap = acct.getCapability<&{Profile.Public}>(Profile.publicPath)
		if !profileCap.check() {
			acct.unlink(Profile.publicPath)
			destroy <- acct.load<@AnyResource>(from:Profile.storagePath)

			let profile <-Profile.createUser(name:name, description: "", allowStoringFollowers:true, tags:["find"])

			let fusdWallet=Profile.Wallet( name:"FUSD", receiver:fusdReceiver, balance:acct.getCapability<&{FungibleToken.Balance}>(/public/fusdBalance), accept: Type<@FUSD.Vault>(), names: ["fusd", "stablecoin"])

			profile.addWallet(fusdWallet)
			profile.addCollection(Profile.ResourceCollection("FINDLeases",leaseCollection, Type<&FIND.LeaseCollection{FIND.LeaseCollectionPublic}>(), ["find", "leases"]))
			profile.addCollection(Profile.ResourceCollection("FINDBids", bidCollection, Type<&FIND.BidCollection{FIND.BidCollectionPublic}>(), ["find", "bids"]))

			acct.save(<-profile, to: Profile.storagePath)
			acct.link<&Profile.User{Profile.Public}>(Profile.publicPath, target: Profile.storagePath)
		}

		let price=FIND.calculateCost(name)
		if price != amount {
			panic("Calculated cost does not match expected cost")
		}
		log("The cost for registering this name is ".concat(price.toString()))

		let vaultRef = acct.borrow<&FUSD.Vault>(from: /storage/fusdVault) ?? panic("Could not borrow reference to the owner's Vault!")
		
		let payVault <- vaultRef.withdraw(amount: price) as! @FUSD.Vault

		let leases=acct.borrow<&FIND.LeaseCollection>(from: FIND.LeaseStoragePath)!
		leases.register(name: name, vault: <- payVault)
	

	}
}
