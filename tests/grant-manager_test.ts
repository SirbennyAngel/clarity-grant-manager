Clarinet.test({
    name: "Test milestone amount validation with enhanced checks",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Test empty milestone list
        let block = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant-with-milestones', [
                types.principal(wallet1.address),
                types.uint(3000),
                types.utf8("Empty milestone list"),
                types.list([]),
                types.list([])
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(109); // ERR_EMPTY_MILESTONE_LIST
        
        // Test zero amount milestone
        block = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant-with-milestones', [
                types.principal(wallet1.address),
                types.uint(3000),
                types.utf8("Zero amount milestone"),
                types.list([types.uint(0), types.uint(3000)]),
                types.list([
                    types.utf8("Phase 1"),
                    types.utf8("Phase 2")
                ])
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(110); // ERR_ZERO_MILESTONE_AMOUNT
    }
});

[... rest of the tests remain unchanged ...]
