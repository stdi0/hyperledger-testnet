const { FileSystemWallet, Gateway, X509WalletMixin } = require('fabric-network');

const fs = require('fs');
const path = require('path');

const ccpPath = path.resolve(__dirname, 'connection.json');
const ccpJSON = fs.readFileSync(ccpPath, 'utf8');
const ccp = JSON.parse(ccpJSON);

const userName = 'alice';

async function main() {
    const wallet = new FileSystemWallet(`../identity/user/${userName}/wallet`);

    const credPath = './crypto-config/peerOrganizations/org1.example.com/users/User1@org1.example.com/msp'

    const privateKeyFile = fs.readdirSync(credPath + '/keystore')[0];

    const cert = fs.readFileSync(path.join(credPath, '/signcerts/User1@org1.example.com-cert.pem')).toString();
    const key = fs.readFileSync(path.join(credPath, '/keystore/', privateKeyFile)).toString();

    const identityLabel = 'User1@org1.example.com';
    const identity = X509WalletMixin.createIdentity('Org1MSP', cert, key);

    await wallet.import(identityLabel, identity);

    const gateway = new Gateway();
    await gateway.connect(ccp, { wallet, identity: 'User1@org1.example.com' });

    const network = await gateway.getNetwork("mychannel");

    const contract = network.getContract('cc');
    const result = await contract.evaluateTransaction("get");
    console.log(`Transaction has been evaluated, result is: ${result}`);
}

main()