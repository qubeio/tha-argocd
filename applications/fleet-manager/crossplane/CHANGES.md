# Crossplane Setup - Changes Summary

## What Changed

Based on user feedback, the setup was simplified from an automated sync job to a one-time manual credential setup. This better reflects lab usage and production patterns where credentials are managed outside of GitOps.

### Files Removed

- ❌ `secret-sync-job.yaml` - Automated Job with RBAC that ran on every ArgoCD sync

### Files Added

- ✅ `setup-credentials.sh` - One-time manual script to copy credentials

### Files Modified

- 📝 `kustomization.yaml` - Removed sync job reference
- 📝 `provider-config.yaml` - Removed Secret definition (created manually now), adjusted sync wave
- 📝 `README.md` - Updated to reflect manual credential setup
- 📝 `SETUP_SUMMARY.md` - Updated deployment steps and architecture
- 📝 `verify-setup.sh` - Removed sync job checks

## Before (Automated)

```
ArgoCD Sync → Job Runs → Credentials Synced → ProviderConfig Created
                ↓
          (Runs every sync)
```

**Pros:**
- Automated credential sync
- Always up-to-date

**Cons:**
- Runs on every ArgoCD sync (unnecessary after first time)
- More complex RBAC requirements
- Overkill for lab environment

## After (Manual)

```
Manual Script (once) → Credentials Created → Deploy via ArgoCD → ProviderConfig Uses Credentials
```

**Pros:**
- Simple and clear
- Runs only once
- No RBAC complexity
- Matches production pattern (credentials outside GitOps)
- Better for lab environments

**Cons:**
- Requires manual step (but only once)

## Migration from Old to New

If you already have the sync job deployed:

```bash
# Delete the old job and RBAC
kubectl delete job sync-azure-credentials -n crossplane-system
kubectl delete serviceaccount crossplane-secret-sync -n crossplane-system
kubectl delete role crossplane-secret-sync -n external-secrets-system
kubectl delete role crossplane-secret-sync -n crossplane-system
kubectl delete rolebinding crossplane-secret-sync -n external-secrets-system
kubectl delete rolebinding crossplane-secret-sync -n crossplane-system

# The credential secret is already created, so no need to run setup-credentials.sh
# Just update your Git repository with the new files
```

## Usage

### One-Time Setup

```bash
cd /home/andreas/source/repos/argo/applications/fleet-manager/crossplane
./setup-credentials.sh
```

This script:
1. Reads credentials from `external-secrets-system/azure-keyvault-credentials`
2. Formats them as JSON
3. Creates `crossplane-system/azure-keyvault-crossplane-creds`
4. Verifies the secret was created correctly

### When to Re-run

Only re-run if you need to update credentials:

```bash
# Delete old secret
kubectl delete secret azure-keyvault-crossplane-creds -n crossplane-system

# Re-run setup
./setup-credentials.sh
```

## Documentation Updates

All documentation has been updated to reflect the manual approach:

- **README.md**: Architecture section updated, sync job removed
- **QUICKSTART.md**: No changes needed (focuses on usage, not setup)
- **DEPLOYMENT.md**: Will need updates (not yet done)
- **SETUP_SUMMARY.md**: Complete rewrite for manual approach
- **verify-setup.sh**: Removed sync job verification

## Deployment Steps

1. **Setup credentials** (one-time):
   ```bash
   cd /home/andreas/source/repos/argo/applications/fleet-manager/crossplane
   ./setup-credentials.sh
   ```

2. **Commit and push**:
   ```bash
   cd /home/andreas/source/repos/argo
   git add applications/fleet-manager/crossplane/
   git add applications/fleet-manager/crossplane-config.yaml
   git commit -m "Simplify Crossplane credential setup to manual script"
   git push origin main
   ```

3. **Verify**:
   ```bash
   cd applications/fleet-manager/crossplane
   ./verify-setup.sh
   ```

## Production Considerations

This manual approach is actually **closer to production patterns** where:

- Credentials are created once during infrastructure bootstrap
- They're managed outside of GitOps (via Vault, Sealed Secrets, etc.)
- ArgoCD manages configuration, not secrets
- Credential rotation is a separate, controlled process

For production, you would:
1. Use External Secrets Operator to fetch credentials from Azure Key Vault
2. Or use Azure Workload Identity (credential-less authentication)
3. Or use Sealed Secrets to encrypt credentials in Git
4. But never commit plaintext credentials to Git!

## Summary

✅ **Simpler**: One script instead of Job + RBAC + sync logic  
✅ **Clearer**: Manual step makes it obvious what's happening  
✅ **Lab-Friendly**: No unnecessary automation for one-time setup  
✅ **Production-Like**: Matches real-world credential management patterns  
✅ **Maintainable**: Less code, easier to understand and debug

