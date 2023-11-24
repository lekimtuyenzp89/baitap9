module lesson9::liquidity_pool {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::math;
    use sui::tx_context::{Self, TxContext};

    const E_ZERO_AMOUNT: u64 = 0;
    const E_WRONG_FEE: u64 = 1;
    const E_RESERVES_EMPTY: u64 = 2;
    const E_SHARE_EMPTY: u64 = 3;
    const E_POOL_FULL: u64 = 4;

    const FEE_SCALING: u128 = 10000;
    const MAX_POOL_VALUE: u64 = 18446744073709551615 / 10000;

    struct LiquidityProviderToken<PhantomP, PhantomT> has drop {}

    struct Pool<PhantomP, PhantomT> has key {
        id: UID,
        sui_balance: Balance<SUI>,
        token_balance: Balance<T>,
        lsp_supply: Supply<LiquidityProviderToken<PhantomP, PhantomT>>,
        fee_percent: u64,
    }

    #[allow(unused_function)]
    fun initialize(_: &mut TxContext) {}

    fun create_liquidity_pool<PhantomP: drop, PhantomT>(
        _: PhantomP,
        token: Coin<T>,
        sui: Coin<SUI>,
        fee_percent: u64,
        ctx: &mut TxContext,
    ) -> Coin<LiquidityProviderToken<PhantomP, PhantomT>> {
        let sui_amount = coin::value(&sui);
        let token_amount = coin::value(&token);

        assert!(sui_amount > 0 && token_amount > 0, E_ZERO_AMOUNT);
        assert!(sui_amount < MAX_POOL_VALUE && token_amount < MAX_POOL_VALUE, E_POOL_FULL);
        assert!(fee_percent >= 0 && fee_percent < 10000, E_WRONG_FEE);

        let share = math::sqrt(sui_amount) * math::sqrt(token_amount);
        let lsp_supply = balance::create_supply(LiquidityProviderToken {});
        let lsp = balance::increase_supply(&mut lsp_supply, share);

        transfer::share_object(Pool {
            id: object::new(ctx),
            token_balance: coin::into_balance(token),
            sui_balance: coin::into_balance(sui),
            lsp_supply,
            fee_percent,
        });

        coin::from_balance(lsp, ctx)
    }

    entry fun swap_sui_to_token<PhantomP, PhantomT>(
        pool: &mut Pool<PhantomP, PhantomT>,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        transfer::public_transfer(
            swap_sui_to_token(pool, sui, ctx),
            tx_context::sender(ctx),
        )
    }

    fun swap_sui_to_token<PhantomP, PhantomT>(
        pool: &mut Pool<PhantomP, PhantomT>,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ) -> Coin<T> {
        assert!(coin::value(&sui) > 0, E_ZERO_AMOUNT);

        let sui_balance = coin::into_balance(sui);
        let (sui_reserve, token_reserve, _) = get_pool_amounts(pool);

        assert!(sui_reserve > 0 && token_reserve > 0, E_RESERVES_EMPTY);

        let output_amount = calculate_output_amount(
            balance::value(&sui_balance),
            sui_reserve,
            token_reserve,
            pool.fee_percent,
        );

        balance::join(&mut pool.sui_balance, sui_balance);
        coin::take(&mut pool.token_balance, output_amount, ctx)
    }

    entry fun swap_token_to_sui<PhantomP, PhantomT>(
        pool: &mut Pool<PhantomP, PhantomT>,
        token: Coin<T>,
        ctx: &mut TxContext,
    ) {
        transfer::public_transfer(
            swap_token_to_sui(pool, token, ctx),
            tx_context::sender(ctx),
        )
    }

    fun swap_token_to_sui<PhantomP, PhantomT>(
        pool: &mut Pool<PhantomP, PhantomT>,
        token: Coin<T>,
        ctx: &mut TxContext,
    ) -> Coin<SUI> {
        assert!(coin::value(&token) > 0, E_ZERO_AMOUNT);

        let token_balance = coin::into_balance(token);
        let (sui_reserve, token_reserve, _) = get_pool_amounts(pool);

        assert!(sui_reserve > 0 && token_reserve > 0, E_RESERVES_EMPTY);

        let output_amount = calculate_output_amount(
            balance::value(&token_balance),
            token_reserve,
            sui_reserve,
            pool.fee_percent,
        );

        balance::join(&mut pool.token_balance, token_balance);
        coin::take(&mut pool.sui_balance, output_amount, ctx)
    }

    // Other functions remain unchanged...
}
