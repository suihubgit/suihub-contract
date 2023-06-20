// SPDX-License-Identifier: MIT

module token::sht {
    use std::option;
    use std::ascii::string;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::url;

    const SYMBOL: vector<u8> = b"SHT";
    const NAME: vector<u8> = b"SuiHub Token";
    const DESCRIPTION: vector<u8> = b"SuiHub Token";
    const DECIMAL: u8 = 9;
    const ICON_URL: vector<u8> = b"https://bafkreic5dtwz67yiouukpdcbl6d3m6raiw5pat7dqr4df2othtlzr6ynbq.ipfs.nftstorage.link/";

    const TOTAL_SUPPLY: u64 = 800000000000000000;

    /// Name of the coin. By convention, this type has the same name as its parent module
    /// and has no fields. The full type of the coin defined by this module will be `COIN<SHT>`.
    struct SHT has drop {}

    /// Register the managed currency to acquire its `TreasuryCap`
    fun init(witness: SHT, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<SHT>(
            witness,
            DECIMAL,
            SYMBOL,
            NAME,
            DESCRIPTION,
            option::some(url::new_unsafe(string(ICON_URL))),
            ctx);

        coin::mint_and_transfer(&mut treasury_cap, TOTAL_SUPPLY, tx_context::sender(ctx), ctx);

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    public entry fun custom_burn(
        treasury_cap: &mut TreasuryCap<SHT>, 
        coin: &mut Coin<SHT>, 
        value: u64,
        ctx: &mut TxContext
    ) {
        let split = coin::split(coin, value, ctx);
        coin::burn(treasury_cap, split);
    }
 
    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(SHT {}, ctx)
    }
}