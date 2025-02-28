[... existing tests remain unchanged ...]

Clarinet.test({
    name: "Test milestone amount validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Try to create grant with incorrect milestone amounts
        let block = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant-with-milestones', [
                types.principal(wallet1.address),
                types.uint(3000),
                types.utf8("Invalid milestone amounts"),
                types.list([types.uint(1000), types.uint(1000)]), // Sum = 2000, total = 3000
                types.list([
                    types.utf8("Phase 1"),
                    types.utf8("Phase 2")
                ])
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(107); // ERR_INVALID_MILESTONE_AMOUNTS
    }
});
