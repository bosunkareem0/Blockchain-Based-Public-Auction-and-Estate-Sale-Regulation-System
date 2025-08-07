# Blockchain-Based Public Auction and Estate Sale Regulation System

A comprehensive smart contract system built on the Stacks blockchain to regulate public auctions, estate sales, and related services. This system ensures transparency, compliance, and proper licensing for all participants in the auction and estate sale ecosystem.

## System Overview

This regulation system consists of five interconnected smart contracts that manage different aspects of auction and estate sale operations:

### 1. Auctioneer Licensing Contract (`auctioneer-licensing.clar`)
- Issues and manages professional auctioneer licenses
- Tracks license status, expiration dates, and compliance history
- Handles license renewals and revocations
- Maintains a registry of certified auctioneers

### 2. Auction Advertising Compliance Contract (`auction-advertising.clar`)
- Ensures accurate and truthful auction advertising
- Prevents deceptive marketing practices
- Validates advertising content before publication
- Tracks advertising violations and penalties

### 3. Consignment Tracking Contract (`consignment-tracking.clar`)
- Manages consignment sales relationships
- Ensures proper payment distribution to consigners
- Tracks item ownership and sale history
- Handles dispute resolution for consignment issues

### 4. Estate Sale Permitting Contract (`estate-sale-permitting.clar`)
- Issues permits for residential estate sales and garage sales
- Manages permit applications and approvals
- Tracks sale locations and dates
- Ensures compliance with local regulations

### 5. Antique Authentication Contract (`antique-authentication.clar`)
- Regulates authentication services for valuable items
- Maintains a registry of certified authenticators
- Tracks authentication certificates and their validity
- Handles disputes over item authenticity

## Key Features

### Transparency
- All licensing, permitting, and authentication activities are recorded on-chain
- Public access to license and permit status information
- Immutable audit trail for all regulatory actions

### Compliance Management
- Automated compliance checking and violation tracking
- Penalty assessment and collection mechanisms
- License and permit renewal notifications

### Stakeholder Protection
- Consigner payment protection through escrow mechanisms
- Authentication certificate validation
- Dispute resolution frameworks

### Regulatory Oversight
- Administrative controls for regulatory authorities
- Fee collection and management
- Violation reporting and enforcement tools

## Contract Architecture

Each contract operates independently while maintaining data consistency across the system:

- **Data Types**: Utilizes Clarity's native data types (uint, principal, string-ascii, bool)
- **Access Control**: Role-based permissions for administrators and users
- **Error Handling**: Comprehensive error codes and validation
- **State Management**: Efficient storage using maps and variables

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Run tests:
   \`\`\`bash
   npm test
   \`\`\`

4. Deploy contracts:
   \`\`\`bash
   clarinet deploy
   \`\`\`

## Usage Examples

### Applying for an Auctioneer License
\`\`\`clarity
(contract-call? .auctioneer-licensing apply-for-license "John Doe Auctions" "Professional auctioneer with 10 years experience")
\`\`\`

### Registering a Consignment Item
\`\`\`clarity
(contract-call? .consignment-tracking register-consignment 'SP1234...CONSIGNER "Antique Vase" u50000)
\`\`\`

### Applying for Estate Sale Permit
\`\`\`clarity
(contract-call? .estate-sale-permitting apply-for-permit "123 Main St" u20240315 u20240317)
\`\`\`

## Testing

The system includes comprehensive tests using Vitest:

- Unit tests for each contract function
- Integration tests for cross-contract workflows
- Edge case and error condition testing
- Performance and gas optimization tests

Run the test suite:
\`\`\`bash
npm test
\`\`\`

## Regulatory Compliance

This system is designed to support various regulatory requirements:

- **Licensing Requirements**: Ensures only licensed professionals conduct auctions
- **Advertising Standards**: Prevents false or misleading auction advertisements
- **Consumer Protection**: Protects consigners and buyers through transparent processes
- **Record Keeping**: Maintains immutable records for regulatory audits

## Security Considerations

- **Access Control**: Multi-level permission system
- **Input Validation**: Comprehensive parameter checking
- **State Protection**: Guards against unauthorized state changes
- **Audit Trail**: Complete transaction history for all operations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support, please open an issue in the repository or contact the development team.
