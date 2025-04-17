import os
import json
import yaml
import argparse

# Argparse
parser = argparse.ArgumentParser(description="Generate validator definitions and secrets.")
parser.add_argument("--password", required=True, help="Password to use for validator keystore secrets.")
args = parser.parse_args()

# Paths
validator_keys_dir = "keys/validator_keys"
validator_keys_secrets_dir = "keys/validator_keys_secrets"
output_yaml_file = "keys/validator_keys/validator_definitions.yml"
validator_password = args.password

# Ensure the secrets directory exists
os.makedirs(validator_keys_secrets_dir, exist_ok=True)

# Prepare the list for YAML file
validator_definitions = []

# Process each JSON file in the `validator_keys` directory
for file_name in os.listdir(validator_keys_dir):
    if file_name.startswith("keystore-m") and file_name.endswith(".json"):
        file_path = os.path.join(validator_keys_dir, file_name)
        
        # Read the JSON file
        with open(file_path, "r") as json_file:
            data = json.load(json_file)
        
        # Extract the public key and description
        pubkey = data.get("pubkey", "")
        description = data.get("description", "")
        
        # Create the validator definition
        validator_definition = {
            "enabled": True,
            "voting_public_key": "0x{}".format(pubkey),
            "description": description,
            "type": "local_keystore",
            "voting_keystore_path": "/validator_keys/{}".format(file_name),
            "voting_keystore_password_path": "/validator_keys_secrets/0x{}".format(pubkey),
        }
        validator_definitions.append(validator_definition)
        
        # Create the secrets file
        secret_file_path = os.path.join(validator_keys_secrets_dir, "0x{}".format(pubkey))
        with open(secret_file_path, "w") as secret_file:
            secret_file.write(validator_password)

# Write the validator definitions to a YAML file
with open(output_yaml_file, "w") as yaml_file:
    yaml.dump(validator_definitions, yaml_file, default_flow_style=False)

print("Validator definitions saved to {}".format(output_yaml_file))
print("Secrets saved to {}".format(validator_keys_secrets_dir))