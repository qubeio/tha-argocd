#!/bin/bash
# Crossplane Azure Key Vault Setup Verification Script

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Crossplane Azure Key Vault Setup Verification"
echo "================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl found${NC}"

# Check Crossplane installation
echo ""
echo "Checking Crossplane installation..."
if kubectl get deployment crossplane -n crossplane-system &> /dev/null; then
    CROSSPLANE_READY=$(kubectl get deployment crossplane -n crossplane-system -o jsonpath='{.status.readyReplicas}')
    if [ "$CROSSPLANE_READY" -gt 0 ]; then
        echo -e "${GREEN}✓ Crossplane is installed and ready${NC}"
    else
        echo -e "${YELLOW}⚠ Crossplane is installed but not ready${NC}"
    fi
else
    echo -e "${RED}✗ Crossplane is not installed${NC}"
    exit 1
fi

# Check Azure Provider
echo ""
echo "Checking Azure Key Vault Provider..."
if kubectl get provider provider-azure-keyvault -n crossplane-system &> /dev/null; then
    PROVIDER_INSTALLED=$(kubectl get provider provider-azure-keyvault -o jsonpath='{.status.conditions[?(@.type=="Installed")].status}')
    PROVIDER_HEALTHY=$(kubectl get provider provider-azure-keyvault -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}')
    
    if [ "$PROVIDER_INSTALLED" = "True" ]; then
        echo -e "${GREEN}✓ Provider is installed${NC}"
    else
        echo -e "${RED}✗ Provider is not installed${NC}"
        echo "  Run: kubectl describe provider provider-azure-keyvault"
    fi
    
    if [ "$PROVIDER_HEALTHY" = "True" ]; then
        echo -e "${GREEN}✓ Provider is healthy${NC}"
    else
        echo -e "${YELLOW}⚠ Provider is not healthy${NC}"
        echo "  Run: kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault"
    fi
else
    echo -e "${RED}✗ Azure Key Vault Provider is not installed${NC}"
    echo "  The provider should be installed by ArgoCD"
    exit 1
fi

# Check source credentials
echo ""
echo "Checking Azure credentials in external-secrets-system..."
if kubectl get secret azure-keyvault-credentials -n external-secrets-system &> /dev/null; then
    echo -e "${GREEN}✓ Source credentials found${NC}"
    
    # Check keys
    CLIENT_ID_EXISTS=$(kubectl get secret azure-keyvault-credentials -n external-secrets-system -o jsonpath='{.data.clientId}' 2>/dev/null)
    CLIENT_SECRET_EXISTS=$(kubectl get secret azure-keyvault-credentials -n external-secrets-system -o jsonpath='{.data.clientSecret}' 2>/dev/null)
    TENANT_ID_EXISTS=$(kubectl get secret azure-keyvault-credentials -n external-secrets-system -o jsonpath='{.data.tenantId}' 2>/dev/null)
    
    if [ -n "$CLIENT_ID_EXISTS" ]; then
        echo -e "${GREEN}  ✓ clientId present${NC}"
    else
        echo -e "${RED}  ✗ clientId missing${NC}"
    fi
    
    if [ -n "$CLIENT_SECRET_EXISTS" ]; then
        echo -e "${GREEN}  ✓ clientSecret present${NC}"
    else
        echo -e "${RED}  ✗ clientSecret missing${NC}"
    fi
    
    if [ -n "$TENANT_ID_EXISTS" ]; then
        echo -e "${GREEN}  ✓ tenantId present${NC}"
    else
        echo -e "${RED}  ✗ tenantId missing${NC}"
    fi
else
    echo -e "${RED}✗ Source credentials not found${NC}"
    echo "  Expected: azure-keyvault-credentials in external-secrets-system namespace"
    exit 1
fi

# Check synced credentials
echo ""
echo "Checking synced credentials in crossplane-system..."
if kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system &> /dev/null; then
    echo -e "${GREEN}✓ Crossplane credentials found${NC}"
    
    # Validate JSON structure
    CREDS=$(kubectl get secret azure-keyvault-crossplane-creds -n crossplane-system -o jsonpath='{.data.credentials}' | base64 -d)
    
    if echo "$CREDS" | jq -e . &> /dev/null; then
        echo -e "${GREEN}  ✓ Credentials are valid JSON${NC}"
        
        # Check required fields
        CLIENT_ID=$(echo "$CREDS" | jq -r '.clientId')
        CLIENT_SECRET=$(echo "$CREDS" | jq -r '.clientSecret')
        TENANT_ID=$(echo "$CREDS" | jq -r '.tenantId')
        SUBSCRIPTION_ID=$(echo "$CREDS" | jq -r '.subscriptionId')
        
        if [ -n "$CLIENT_ID" ] && [ "$CLIENT_ID" != "null" ]; then
            echo -e "${GREEN}  ✓ clientId present${NC}"
        else
            echo -e "${RED}  ✗ clientId missing${NC}"
        fi
        
        if [ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != "null" ]; then
            echo -e "${GREEN}  ✓ clientSecret present${NC}"
        else
            echo -e "${RED}  ✗ clientSecret missing${NC}"
        fi
        
        if [ -n "$TENANT_ID" ] && [ "$TENANT_ID" != "null" ]; then
            echo -e "${GREEN}  ✓ tenantId present${NC}"
        else
            echo -e "${RED}  ✗ tenantId missing${NC}"
        fi
        
        if [ -n "$SUBSCRIPTION_ID" ] && [ "$SUBSCRIPTION_ID" != "null" ]; then
            echo -e "${GREEN}  ✓ subscriptionId present${NC}"
        else
            echo -e "${YELLOW}  ⚠ subscriptionId missing (may be needed for some operations)${NC}"
        fi
    else
        echo -e "${RED}  ✗ Credentials are not valid JSON${NC}"
    fi
else
    echo -e "${RED}✗ Crossplane credentials not found${NC}"
    echo "  Run the setup script to create credentials:"
    echo "  cd applications/fleet-manager/crossplane"
    echo "  ./setup-credentials.sh"
fi

# Check ProviderConfig
echo ""
echo "Checking ProviderConfig..."
if kubectl get providerconfig default &> /dev/null; then
    echo -e "${GREEN}✓ ProviderConfig 'default' exists${NC}"
else
    echo -e "${RED}✗ ProviderConfig 'default' not found${NC}"
    exit 1
fi

# Check ArgoCD Application
echo ""
echo "Checking ArgoCD Application..."
if kubectl get application crossplane-config -n argocd &> /dev/null; then
    APP_HEALTH=$(kubectl get application crossplane-config -n argocd -o jsonpath='{.status.health.status}')
    APP_SYNC=$(kubectl get application crossplane-config -n argocd -o jsonpath='{.status.sync.status}')
    
    echo -e "${GREEN}✓ ArgoCD Application exists${NC}"
    
    if [ "$APP_HEALTH" = "Healthy" ]; then
        echo -e "${GREEN}  ✓ Health: ${APP_HEALTH}${NC}"
    else
        echo -e "${YELLOW}  ⚠ Health: ${APP_HEALTH}${NC}"
    fi
    
    if [ "$APP_SYNC" = "Synced" ]; then
        echo -e "${GREEN}  ✓ Sync: ${APP_SYNC}${NC}"
    else
        echo -e "${YELLOW}  ⚠ Sync: ${APP_SYNC}${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ArgoCD Application not found${NC}"
    echo "  This is expected if deploying manually"
fi

# Summary
echo ""
echo "================================================"
echo "Summary"
echo "================================================"

if command -v az &> /dev/null; then
    echo ""
    echo "Azure CLI detected. Getting Key Vault information..."
    
    KEYVAULT_INFO=$(az keyvault show --name qubeio 2>/dev/null || echo "")
    
    if [ -n "$KEYVAULT_INFO" ]; then
        KEYVAULT_ID=$(echo "$KEYVAULT_INFO" | jq -r '.id')
        KEYVAULT_URI=$(echo "$KEYVAULT_INFO" | jq -r '.properties.vaultUri')
        RESOURCE_GROUP=$(echo "$KEYVAULT_INFO" | jq -r '.resourceGroup')
        
        echo -e "${GREEN}✓ Key Vault 'qubeio' found${NC}"
        echo ""
        echo "Key Vault Details:"
        echo "  URI: $KEYVAULT_URI"
        echo "  Resource Group: $RESOURCE_GROUP"
        echo "  Full ID: $KEYVAULT_ID"
        echo ""
        echo "Use this ID in your Secret manifests:"
        echo "  keyVaultId: $KEYVAULT_ID"
    else
        echo -e "${YELLOW}⚠ Key Vault 'qubeio' not found or not accessible${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}Azure CLI not installed. Install it to get Key Vault information.${NC}"
    echo "  See: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
fi

echo ""
echo "Next steps:"
echo "1. Review the QUICKSTART.md for usage examples"
echo "2. Create a test secret: kubectl apply -f crossplane/example-secret.yaml"
echo "3. Monitor resources: kubectl get secrets.keyvault.azure.upbound.io -A"
echo ""
echo "For troubleshooting, run:"
echo "  kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-keyvault"
echo ""

