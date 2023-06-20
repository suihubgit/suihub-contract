module presale::presale {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::event;
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::address;
    use sui::table::{Self, Table};
    use std::vector;

    struct Round<phantom SHT> has key {
        id: UID,
        sht_sold: u64,
        ratio: u64,
        is_on: bool,
        presale_start_timestamp: u64,
        presale_end_timestamp: u64,
        beneficiary: address,
        min_buy: u64,
        max_buy: u64,
        referral: Table<address, vector<ReferralInfo>>,
        fund: Balance<SHT>,
    }

    struct ReferralInfo has store {
        buyer: address,
        sui_reward: u64,
        sht_amount: u64,
    }

    struct AdminCap has key, store {
        id: UID,
    }

    struct UpdateRatioEvent has copy, drop {
        new_ratio: u64,
    }

    struct UpdatePresaleTimeEvent has copy, drop {
        is_on: bool,
        trigger_time: u64,
    }

    struct UpdateBeneficiaryEvent has copy, drop {
        beneficiary: address,
    }

    struct AddFundEvent has copy, drop {
        fund_amount: u64,
    }

    struct UpdateMinBuyEvent has copy, drop {
        min_buy: u64
    }

    struct UpdateMaxBuyEvent has copy, drop {
        max_buy: u64
    }

    struct CreateNewRoundEvent has copy, drop {
        ratio: u64,
        beneficiary: address,
        min_buy: u64,
        max_buy: u64,
    }

    struct OnOffEvent has copy, drop {
        is_on: bool
    }

    struct UpdateRoundStartEndTimeEvent has copy, drop {
        presale_start_timestamp: u64,
        presale_end_timestamp: u64,
    }

    // Constants

    // Must deposit more than MIN_BUY
    const EInsufficientDepositMin: u64 = 0;
    // Must deposit less than MAX_BUY
    const EInsufficientDepositMax: u64 = 1;
    // Must buy after presale start
    const EIncorrectTimeStart: u64 = 2;
    // Must buy before presale end
    const EIncorrectTimeEnd: u64 = 3;
    // Must buy when admin resume presale process
    const EPresalePaused: u64 = 4;
    // End timestamp must greater than start timestamp
    const EInvalidEndTimestamp: u64 = 5;
    // SHT fund amount must greater than 0
    const EInsufficientFund: u64 = 6;
    // SHT fund not enough for buying
    const ENotEnoughFund: u64 = 7;
    // remain fund SHT is zero
    const ENoMoreFundLeft: u64 = 8;

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    // User methods

    public entry fun buy<SHT>(
        round: &mut Round<SHT>,
        c: Coin<SUI>,
        clock_object: &Clock,
        referer_address: address,
        ctx: &mut TxContext
    ) {
        let b = coin::into_balance(c);
        let sui_amount = balance::value(&b);
        assert!(sui_amount >= round.min_buy, EInsufficientDepositMin);
        assert!(sui_amount <= round.max_buy, EInsufficientDepositMax);
        assert!(round.is_on, EPresalePaused);

        let now = clock::timestamp_ms(clock_object);
        assert!(now >= round.presale_start_timestamp, EIncorrectTimeStart);
        assert!(now <= round.presale_end_timestamp, EIncorrectTimeEnd);

        let sht_amount = sui_amount * round.ratio;
        let fund_amount = balance::value(&round.fund);
        assert!(sht_amount <= fund_amount, ENotEnoughFund);

        round.sht_sold = round.sht_sold + sht_amount;

        let sht_taken = coin::take(&mut round.fund, sht_amount, ctx);
        transfer::public_transfer(sht_taken, tx_context::sender(ctx));

        if (address::to_u256(referer_address) != address::to_u256(round.beneficiary)) {
            let sui_for_beneficiary_amount = sui_amount * 90 / 100;
            let sui_for_beneficiary = coin::take(&mut b, sui_for_beneficiary_amount, ctx);
            transfer::public_transfer(sui_for_beneficiary, round.beneficiary);
            
            let sui_for_referer_amount = sui_amount - sui_for_beneficiary_amount;
            let sui_for_referer = coin::take(&mut b, sui_for_referer_amount, ctx);
            transfer::public_transfer(sui_for_referer, referer_address);

            let referral_info = ReferralInfo {
                buyer: tx_context::sender(ctx),
                sui_reward: sui_for_referer_amount,
                sht_amount,
            };
            if (table::contains(&round.referral, referer_address)) {
                let ref_vec = table::borrow_mut(&mut round.referral, referer_address);
                vector::push_back<ReferralInfo>(ref_vec, referral_info);
            } else {
                let ref_vec = vector::empty<ReferralInfo>();
                vector::push_back<ReferralInfo>(&mut ref_vec, referral_info);
                table::add(&mut round.referral, referer_address, ref_vec);
            }
            
        } else {
            let sui_for_beneficiary = coin::take(&mut b, sui_amount, ctx);
            transfer::public_transfer(sui_for_beneficiary, round.beneficiary);
        };
        let remain_sui = coin::from_balance(b, ctx);
        if (coin::value(&remain_sui) > 0) {
            transfer::public_transfer(remain_sui, tx_context::sender(ctx))
        } else {
            coin::destroy_zero(remain_sui)
        }
    }

    // Admin methods
    public entry fun update_ratio<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        ratio: u64
    ) {
        round.ratio = ratio;
        event::emit(UpdateRatioEvent {
            new_ratio: ratio
        });
    }

    public entry fun on_off_round<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        is_on: bool
    ) {
        round.is_on = is_on;
        event::emit(OnOffEvent {
            is_on
        });
    }

    public entry fun update_round_start_end_time<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        clock_object: &Clock,
        presale_start_timestamp: u64,
        presale_end_timestamp: u64
    ) {
        assert!(presale_start_timestamp >= clock::timestamp_ms(clock_object), EIncorrectTimeStart);
        assert!(presale_end_timestamp >= presale_start_timestamp, EIncorrectTimeEnd);
        round.presale_start_timestamp = presale_start_timestamp;
        round.presale_end_timestamp = presale_end_timestamp;
        event::emit(UpdateRoundStartEndTimeEvent {
            presale_start_timestamp,
            presale_end_timestamp
        });
    }

    public entry fun update_beneficiary_address<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        beneficiary: address
    ) {
        round.beneficiary = beneficiary;
        event::emit(UpdateBeneficiaryEvent {
            beneficiary
        });
    }

    public entry fun update_min_buy<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        min_buy: u64
    ) {
        round.min_buy = min_buy;
        event::emit(UpdateMinBuyEvent {
            min_buy
        });
    }

    public entry fun update_max_buy<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        max_buy: u64
    ) {
        round.max_buy = max_buy;
        event::emit(UpdateMaxBuyEvent {
            max_buy
        });
    }

    public entry fun add_fund<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        fund: Coin<SHT>
    ) {
        let b = coin::into_balance(fund);
        let fund_amount = balance::value(&b);
        assert!(fund_amount > 0, EInsufficientFund);
        balance::join(&mut round.fund, b);
        event::emit(AddFundEvent {
            fund_amount
        });
    }

    public entry fun claim_back_fund<SHT>(
        _cap: &AdminCap,
        round: &mut Round<SHT>,
        ctx: &mut TxContext
    ) {
        let amount = balance::value(&round.fund);
        assert!(amount > 0, ENoMoreFundLeft);

        let sht = coin::take(&mut round.fund, amount, ctx);
        transfer::public_transfer(sht, tx_context::sender(ctx));
    }

    public entry fun create_new_round<SHT>(
        _cap: &AdminCap,
        ratio: u64,
        min_buy: u64,
        max_buy: u64,
        beneficiary: address,
        ctx: &mut TxContext
    ) {
        transfer::share_object(Round {
            id: object::new(ctx),
            sht_sold: 0,
            ratio,
            is_on: false,
            presale_start_timestamp: 0,
            presale_end_timestamp: 0,
            beneficiary,
            min_buy,
            max_buy,
            referral: table::new<address, vector<ReferralInfo>>(ctx),
            fund: balance::zero<SHT>(),
        });
        event::emit(CreateNewRoundEvent {
            ratio,
            beneficiary,
            min_buy,
            max_buy,
        })
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}