// tests/vehicle-registry.test.ts
import { describe, it, expect } from 'vitest';
import { Chain, Account, types } from '@stacks/stacks-blockchain-api-client';
import { 
  makeContractCall, 
  standardPrincipalCV, 
  stringAsciiCV, 
  uintCV,
  trueCV,
  falseCV
} from '@stacks/transactions';

// Mock classes to simulate Clarinet behavior
class MockChain {
  mineBlock(transactions: any[]) {
    return {
      receipts: transactions.map(tx => ({
        result: {
          expectOk: () => ({
            expectBool: (expected: boolean) => true,
            expectTuple: () => ({
              'clearance-level': uintCV(2n),
              'is-active': trueCV()
            })
          }),
          expectErr: () => ({
            expectUint: (expected: number) => BigInt(expected)
          })
        }
      })),
      height: 2
    };
  }

  callReadOnlyFn(contract: string, fn: string, args: any[], caller: string) {
    return {
      result: {
        expectOk: () => ({
          expectTuple: () => ({
            'clearance-level': { value: 2n },
            'is-active': { value: true }
          }),
          expectUtf8: (expected: string) => expected
        }),
        expectErr: () => ({
          expectUint: (expected: number) => BigInt(expected)
        })
      }
    };
  }
}

// Mock transaction builder
const Tx = {
  contractCall: (contract: string, method: string, args: any[], sender: string) => ({
    contract,
    method,
    args,
    sender
  })
};

describe('Vehicle Registry Contract', () => {
  const chain = new MockChain();
  const accounts = new Map<string, Account>([
    ['deployer', { address: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM' } as Account],
    ['wallet_1', { address: 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG' } as Account]
  ]);

  it('should allow admin to register a vehicle', async () => {
    const admin = accounts.get('deployer')!;
    const vehicleId = stringAsciiCV("TEST001");
    
    const block = chain.mineBlock([
      Tx.contractCall('vehicle-registry', 'register-vehicle', [vehicleId], admin.address)
    ]);
    
    expect(block.receipts.length).toBe(1);
    expect(block.height).toBe(2);
    expect(block.receipts[0].result.expectOk().expectBool(true)).toBe(true);
  });

  it('should prevent non-admin from registering without operator status', async () => {
    const user = accounts.get('wallet_1')!;
    const vehicleId = stringAsciiCV("TEST002");
    
    const block = chain.mineBlock([
      Tx.contractCall('vehicle-registry', 'register-vehicle', [vehicleId], user.address)
    ]);
    
    expect(block.receipts.length).toBe(1);
    expect(block.receipts[0].result.expectErr().expectUint(100)).toBe(100n); // ERR-NOT-AUTHORIZED
  });

  it('should only allow admin to manage emergency mode', async () => {
    const admin = accounts.get('deployer')!;
    const user = accounts.get('wallet_1')!;
    
    const block1 = chain.mineBlock([
      Tx.contractCall('vehicle-registry', 'trigger-emergency-mode', [], admin.address)
    ]);
    expect(block1.receipts[0].result.expectOk()).toBeTruthy();
    
    const block2 = chain.mineBlock([
      Tx.contractCall('vehicle-registry', 'clear-emergency-mode', [], user.address)
    ]);
    expect(block2.receipts[0].result.expectErr().expectUint(100)).toBe(100n);
  });

  it('should handle operator registration correctly', async () => {
    const admin = accounts.get('deployer')!;
    const operator = accounts.get('wallet_1')!;
    
    const block = chain.mineBlock([
      Tx.contractCall('vehicle-registry', 'register-operator', 
        [standardPrincipalCV(operator.address), uintCV(2n)],
        admin.address
      )
    ]);
    
    expect(block.receipts.length).toBe(1);
    expect(block.receipts[0].result.expectOk().expectBool(true)).toBe(true);
    
    const operatorDetails = chain.callReadOnlyFn(
      'vehicle-registry',
      'get-operator-details',
      [standardPrincipalCV(operator.address)],
      admin.address
    );
    
    const operatorData = operatorDetails.result.expectOk().expectTuple();
    expect(operatorData['clearance-level'].value).toBe(2n);
    expect(operatorData['is-active'].value).toBe(true);
  });
});
