# Backup & Recovery

## Automated Backups

Daily backups run via GitHub Actions at 3 AM UTC:
- Export all secrets from Infisical API
- Encrypt with `age` (public key encryption)
- Upload to Arweave (permanent, decentralized storage)
- Also stored as GitHub artifact (30-day retention)

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `INFISICAL_CLIENT_ID` | Machine identity client ID |
| `INFISICAL_CLIENT_SECRET` | Machine identity secret |
| `INFISICAL_PROJECT_ID` | Infisical project UUID |
| `AGE_PUBLIC_KEY` | Public key for encrypting backups |
| `ARWEAVE_WALLET_JWK` | Arweave wallet JSON for uploads |

### Manual Backup Trigger

```bash
gh workflow run backup.yml \
  --repo wonderwomancode/service-secrets \
  -f environment=production
```

## Finding Backups

### Arweave

Search for backups on Arweave:
```
https://arweave.net/graphql
Query: tags: [{ name: "app", values: ["alternatefutures"] }, { name: "type", values: ["secrets-backup"] }]
```

Or via ArDrive/ViewBlock:
```
https://viewblock.io/arweave/address/<wallet-address>
```

### GitHub Artifacts

1. Go to Actions → Backup Secrets to Arweave
2. Select a workflow run
3. Download the artifact

## Restore Procedure

### 1. Download and Decrypt

```bash
# Get your age private key
export AGE_KEY_FILE=~/.age-key.txt

# Restore from Arweave
./scripts/restore-backup.sh ar://YOUR_TX_ID $AGE_KEY_FILE

# Or from downloaded artifact
age -d -i $AGE_KEY_FILE -o backup.tar.gz backup-xxx.tar.gz.age
tar -xzf backup.tar.gz
```

### 2. Verify Contents

```bash
cat backups/metadata.json
ls -la backups/
```

### 3. Import to Infisical

**Option A: CLI (recommended)**
```bash
infisical login --domain=https://secrets.alternatefutures.ai

# For each path
infisical secrets import \
  --env=production \
  --path=/service-cloud-api \
  backups/secrets__service-cloud-api.json
```

**Option B: API**
```bash
# Get access token
TOKEN=$(curl -s -X POST "https://secrets.alternatefutures.ai/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d '{"clientId":"xxx","clientSecret":"yyy"}' | jq -r '.accessToken')

# Import secrets
for secret in $(jq -c '.[]' backups/secrets__service-cloud-api.json); do
  curl -X POST "https://secrets.alternatefutures.ai/api/v3/secrets/raw" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"workspaceId\": \"$PROJECT_ID\",
      \"environment\": \"production\",
      \"secretPath\": \"/service-cloud-api\",
      \"secretKey\": $(echo $secret | jq '.secretKey'),
      \"secretValue\": $(echo $secret | jq '.secretValue')
    }"
done
```

## Disaster Recovery

### Scenario: Akash deployment lost

1. **Redeploy Infisical** using `deploy-akash.yaml`
   - Generate NEW secrets (ENCRYPTION_KEY, AUTH_SECRET, etc.)
   - Complete first-time setup at https://secrets.alternatefutures.ai

2. **Restore from backup**
   - Download latest backup from Arweave
   - Decrypt with age private key
   - Import secrets via CLI or API

3. **Update DNS** if ingress URL changed
   - Update CNAME for secrets.alternatefutures.ai

4. **Rotate credentials** in dependent services
   - service-cloud-api INFISICAL_CLIENT_SECRET
   - service-auth INFISICAL_CLIENT_SECRET
   - GitHub Actions secrets

### Scenario: ENCRYPTION_KEY lost

If you lose the Infisical ENCRYPTION_KEY:
1. All secrets in the database are **unrecoverable**
2. You must restore from backup
3. Generate new ENCRYPTION_KEY for new deployment
4. Re-import all secrets from backup

**Prevention:** Store ENCRYPTION_KEY in multiple secure locations:
- Encrypted in GitHub Secrets
- Encrypted in 1Password/Bitwarden
- Encrypted backup on Arweave

## Retention Policy

| Storage | Retention |
|---------|-----------|
| Arweave | Permanent (200+ years) |
| GitHub Artifacts | 30 days |

## Backup Verification

Monthly verification checklist:
- [ ] Download latest Arweave backup
- [ ] Decrypt successfully with age key
- [ ] Verify secret count matches production
- [ ] Test restore to staging environment
