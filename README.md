
Setup BLOCX-Node in your server using
=====================================

Step : 1
--------
```bash
./docker-setup.sh
```

### Note: If you want to set normal node skip to the step 6

Step : 2
--------

*   Generate your keys
```bash
./bin/blocx-deposit-cli new-mnemonic --eth1_withdrawal_address 'your eth withdrawal address'
```
    

Step : 3
--------

*   Continue with the prompts and do remember the password you have used during the mnemonic generation
    
*   Move the generated keys to proper location
```bash
mkdir -p keys/validator_keys el-cl-genesis-data/jwt && cp -rf validator_keys/* keys/validator_keys
```    

Step : 4
--------

*   Generate the keystore secrets
```bash
python3 generate_keys.py --password 'your_password_here'
```

Step : 5
--------

*   Set your fee recipient address
```bash
export FEE_RECIPIENT=0xYourEthereumAddress
```

Step : 6
--------

*   Run the wrapper script and choose `init` option to initialize the node and then `start` option to start the node
```bash
./initExecution.sh
```    

* * *

**Note:** Before submitting your `deposit.json` file to the staking launchpad, ensure your node is **fully synced with the network**. If your validator gets approved while your node is not synced, you may receive penalties.

* * *

Now to deposit the amount for creating validator go to the staking launchpad at [Launchpad](https://launchpad.blocxscan.com/) and proceed with all the instructions.

* * *
