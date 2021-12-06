import FUSD from 0xFUSD_ADDRESS
import FIND from 0xFIND_ADDRESS

transaction(name: String, amount: UFix64) {

    prepare(account: AuthAccount) {
        let vaultRef = account.borrow<&FUSD.Vault>(from: /storage/fusdVault) ?? panic("Could not borrow reference to the fusdVault!")

        log("Sending ".concat(amount.toString()).concat( " to profile with name ").concat(name))
        FIND.deposit(to: name, from: <- vaultRef.withdraw(amount: amount))
    }

}
 

