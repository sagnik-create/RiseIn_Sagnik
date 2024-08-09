module 0x354d9d144f0e0150e62ac8bc56cfbbcde193f2860bfcfe2e6a229e95df4c39c1::MultiSigWallet {
    use std::signer;
    use std::vector;
    use std::map;
    use std::option;
    use std::coin;

    /// Represents a wallet controlled by multiple signers.
    struct Wallet has key {
        signers: vector<address>,
        threshold: u8,
        approvals: map<address, bool>,
        transaction: option::Option<PendingTransaction>,
    }

    /// Represents a transaction pending approval.
    struct PendingTransaction has store {
        to: address,
        amount: u64,
        approvals_count: u8,
    }

    /// Initializes a new multi-sig wallet with the given signers and threshold.
    public fun initialize(
        account: &signer,
        signers: vector<address>,
        threshold: u8
    ) {
        assert!(threshold > 0, 1);
        assert!(threshold <= vector::length(&signers), 2);
        let wallet = Wallet {
            signers: signers,
            threshold: threshold,
            approvals: map::new(),
            transaction: option::none<PendingTransaction>(),
        };
        move_to(account, wallet);
    }

    /// Proposes a new transaction to be executed once enough approvals are gathered.
    public fun propose_transaction(
        sender: &signer,
        to: address,
        amount: u64
    ) {
        let wallet = borrow_global_mut<Wallet>(signer::address_of(sender));
        assert!(option::is_none(&wallet.transaction), 3);

        let transaction = PendingTransaction {
            to: to,
            amount: amount,
            approvals_count: 0,
        };
        wallet.transaction = option::some(transaction);

        // Automatically approve the transaction by the proposer
        approve_transaction(sender);
    }

    /// Approves the current transaction pending in the wallet.
    public fun approve_transaction(sender: &signer) {
        let wallet = borrow_global_mut<Wallet>(signer::address_of(sender));
        assert!(option::is_some(&wallet.transaction), 4);

        let sender_address = signer::address_of(sender);
        let transaction = option::borrow_mut(&mut wallet.transaction).unwrap().as_mut().unwrap();

        let signer_found = vector::contains(&wallet.signers, &sender_address);
        assert!(signer_found, 5);

        let already_approved = map::contains_key(&wallet.approvals, &sender_address);
        assert!(!already_approved, 6);

        // Record approval
        map::insert(&mut wallet.approvals, sender_address, true);
        transaction.approvals_count = transaction.approvals_count+1;

        // Execute transaction if approvals threshold is met
        if transaction.approvals_count >= wallet.threshold {
            coin::transfer(&signer::borrow_global_mut<coin::Coin>(transaction.to), transaction.amount);
            wallet.transaction = option::none();
            wallet.approvals = map::new(); // Reset approvals
        }
    }
}
