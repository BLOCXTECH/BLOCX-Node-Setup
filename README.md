# Setup docker in your server using

## Step : 1

```bash
./docker-setup.sh
```

### Note: If you want to set normal node skip to the step 6

## Step : 2

- Generate your keys

```bash
./bin/blocx-deposit-cli --non_interactive --language English new-mnemonic
```

## Step : 3

- Continue with the prompts and do remember the password you have used during the mnemonic generation
- Move the generated keys to proper location

```bash
mkdir -p keys/validator_keys el-cl-genesis-data/jwt && cp -rf validator_keys/* keys/validator_keys
```

## Step : 4

- Generate the keystore secrets

```bash
python3 generate_keys.py --password 'your_password_here'
```

## Step : 5

- Set your fee recipient address

```bash
export FEE_RECIPIENT=0xYourEthereumAddress
```

## Step : 6

- Run the wrapper script and choose `init` option to initialize the node and then `start` option to start the node

```bash
./initExecution.sh
```

- Now to deposit the amount for creating validator go to the staking launchpad at [Launchpad](http://149.102.152.164:3000/) and proceed with all the instructions.
