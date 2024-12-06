import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test admin functions and grant creation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('grant-manager', 'is-admin', [], deployer.address),
            Tx.contractCall('grant-manager', 'create-grant', [
                types.principal(wallet1.address),
                types.uint(1000),
                types.utf8("Research on blockchain scalability")
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), true);
        block.receipts[1].result.expectOk().expectUint(0);
    }
});

Clarinet.test({
    name: "Test grant funding and completion",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create grant first
        let block1 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant', [
                types.principal(wallet1.address),
                types.uint(1000),
                types.utf8("Research grant")
            ], deployer.address)
        ]);
        
        // Fund and complete grant
        let block2 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'fund-grant', [
                types.uint(0)
            ], deployer.address),
            Tx.contractCall('grant-manager', 'complete-grant', [
                types.uint(0)
            ], deployer.address)
        ]);
        
        block2.receipts[0].result.expectOk();
        block2.receipts[1].result.expectOk();
        
        // Verify grant details
        let block3 = chain.mineBlock([
            Tx.contractCall('grant-manager', 'get-grant', [
                types.uint(0)
            ], deployer.address)
        ]);
        
        const grant = block3.receipts[0].result.expectOk().expectSome();
        assertEquals(grant['funded'], true);
        assertEquals(grant['completed'], true);
    }
});

Clarinet.test({
    name: "Test unauthorized access",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('grant-manager', 'create-grant', [
                types.principal(wallet1.address),
                types.uint(1000),
                types.utf8("Unauthorized grant")
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(100); // ERR_NOT_AUTHORIZED
    }
});
