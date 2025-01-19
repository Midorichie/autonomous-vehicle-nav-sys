import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that admin can register a vehicle",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const vehicleId = types.utf8("TEST001");
        
        let block = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'register-vehicle', [vehicleId], admin.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        block.receipts[0].result.expectOk().expectBool(true);
    },
});

Clarinet.test({
    name: "Ensure that non-admin cannot register without operator status",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const user = accounts.get('wallet_1')!;
        const vehicleId = types.utf8("TEST002");
        
        let block = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'register-vehicle', [vehicleId], user.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectErr().expectUint(100); // ERR-NOT-AUTHORIZED
    },
});

Clarinet.test({
    name: "Ensure emergency mode can only be triggered by admin",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const user = accounts.get('wallet_1')!;
        
        // Admin triggers emergency mode
        let block1 = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'trigger-emergency-mode', [], admin.address)
        ]);
        assertEquals(block1.receipts[0].result.expectOk(), true);
        
        // Non-admin tries to clear emergency mode
        let block2 = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'clear-emergency-mode', [], user.address)
        ]);
        block2.receipts[0].result.expectErr().expectUint(100); // ERR-NOT-AUTHORIZED
    },
});

Clarinet.test({
    name: "Ensure operator registration works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const operator = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'register-operator', 
                [types.principal(operator.address), types.uint(2)], 
                admin.address
            )
        ]);
        
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify operator details
        let getOperator = chain.callReadOnlyFn(
            'vehicle-registry',
            'get-operator-details',
            [types.principal(operator.address)],
            admin.address
        );
        
        let operatorData = getOperator.result.expectOk().expectTuple();
        assertEquals(operatorData['clearance-level'], types.uint(2));
        assertEquals(operatorData['is-active'], types.bool(true));
    },
});

Clarinet.test({
    name: "Ensure invalid status updates are rejected",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const admin = accounts.get('deployer')!;
        const vehicleId = types.utf8("TEST003");
        const invalidStatus = types.utf8("invalid_status");
        
        // First register a vehicle
        let block1 = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'register-vehicle', [vehicleId], admin.address)
        ]);
        
        // Try to update with invalid status
        let block2 = chain.mineBlock([
            Tx.contractCall('vehicle-registry', 'update-status', [invalidStatus], admin.address)
        ]);
        
        block2.receipts[0].result.expectErr().expectUint(104); // ERR-INVALID-STATUS
    },
});
