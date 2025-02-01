import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test milestone-based grant creation and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create grant with milestones
        let block1 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant-with-milestones', [
                types.principal(wallet1.address),
                types.uint(3000),
                types.utf8("Research project with milestones"),
                types.list([types.uint(1000), types.uint(1000), types.uint(1000)]),
                types.list([
                    types.utf8("Phase 1: Research"),
                    types.utf8("Phase 2: Development"),
                    types.utf8("Phase 3: Testing")
                ])
            ], deployer.address)
        ]);
        
        block1.receipts[0].result.expectOk().expectUint(0);
        
        // Complete and fund first milestone
        let block2 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'complete-milestone', [
                types.uint(0),
                types.uint(0)
            ], deployer.address),
            Tx.contractCall('grant-manager', 'fund-milestone', [
                types.uint(0),
                types.uint(0)
            ], deployer.address)
        ]);
        
        block2.receipts[0].result.expectOk();
        block2.receipts[1].result.expectOk();
        
        // Verify milestone state
        let block3 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'get-milestone', [
                types.uint(0),
                types.uint(0)
            ], deployer.address)
        ]);
        
        const milestone = block3.receipts[0].result.expectOk().expectSome();
        assertEquals(milestone['completed'], true);
        assertEquals(milestone['funded'], true);
    }
});

Clarinet.test({
    name: "Test grant completion requirements",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create grant with milestones
        let block1 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant-with-milestones', [
                types.principal(wallet1.address),
                types.uint(2000),
                types.utf8("Two phase project"),
                types.list([types.uint(1000), types.uint(1000)]),
                types.list([
                    types.utf8("Phase 1"),
                    types.utf8("Phase 2")
                ])
            ], deployer.address)
        ]);
        
        // Try to complete grant before milestones
        let block2 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'complete-grant', [
                types.uint(0)
            ], deployer.address)
        ]);
        
        block2.receipts[0].result.expectErr().expectUint(105); // ERR_MILESTONE_NOT_COMPLETED
    }
});
