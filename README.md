# Deployments

## Deploy SHT token
```bash
cd token
sui client publish --gas-budget 50000000
```

## Deploy Presale package
### Step 1
- Change beneficiary address in Move.toml

### Step 2
```bash
cd presale
sui client publish --gas-budget 50000000
```

### Step 3: Add fund
```bash
sui client call --function add_fund --module presale --package 'PACKAGE_ID' --args 'ADMIN_CAP_OBJECT_ID' 'GLOBAL_OBJECT_ID' --type-args SHT_TOKEN_PACKAGE_ID::sht::SHT --gas-budget 50000000
```

Take note FUND_OBJECT_ID created from this transaction

### Step 4: Trigger presale time
```bash
sui client call --function update_presale_time --module presale --package 'PACKAGE_ID' --args 'ADMIN_CAP_OBJECT_ID' 'GLOBAL_OBJECT_ID' 0x6 true $TRIGGER_TIME_IN_MILLISECONDS --gas-budget 50000000
```

### Step 5: Buy
```bash
sui client call --function buy --module presale --package 'PACKAGE_ID' --args 'GLOBAL_OBJECT_ID' 'FUND_OBJECT_ID' 'SUI COIN OBJECT ID' 0x6 'REFERER_ID' --type-args SHT_TOKEN_PACKAGE_ID::sht::SHT --gas-budget 50000000
```