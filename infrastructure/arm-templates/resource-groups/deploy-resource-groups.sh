#!/bin/bash

###############################################################################
# Azure Resource Group Deployment Script
# 
# Purpose: Deploy Azure Resource Groups for KBudget GPT environments
# Features:
#   - Idempotent deployments
#   - Detailed logging
#   - Follows naming conventions
#   - Supports dev, staging, and prod environments
#
# Usage:
#   ./deploy-resource-groups.sh <environment>
#   
# Examples:
#   ./deploy-resource-groups.sh dev
#   ./deploy-resource-groups.sh staging
#   ./deploy-resource-groups.sh prod
#   ./deploy-resource-groups.sh all
#
###############################################################################

set -e  # Exit on error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/resource-group.json"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create logs directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Log file for this execution
LOG_FILE="${LOG_DIR}/deployment_${TIMESTAMP}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Logging Functions
###############################################################################

log() {
    local message="$1"
    echo -e "${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

###############################################################################
# Validation Functions
###############################################################################

check_azure_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        log_info "Visit: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    log_success "Azure CLI is installed"
}

check_azure_login() {
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    local account_name=$(az account show --query name -o tsv)
    local subscription_id=$(az account show --query id -o tsv)
    log_success "Logged in to Azure"
    log_info "Account: ${account_name}"
    log_info "Subscription ID: ${subscription_id}"
}

validate_environment() {
    local env="$1"
    case "${env}" in
        dev|staging|prod|all)
            return 0
            ;;
        *)
            log_error "Invalid environment: ${env}"
            log_info "Valid options: dev, staging, prod, all"
            return 1
            ;;
    esac
}

###############################################################################
# Deployment Functions
###############################################################################

deploy_resource_group() {
    local environment="$1"
    local params_file="${SCRIPT_DIR}/parameters.${environment}.json"
    
    log_info "=========================================="
    log_info "Deploying Resource Group: ${environment}"
    log_info "=========================================="
    
    # Check if parameters file exists
    if [[ ! -f "${params_file}" ]]; then
        log_error "Parameters file not found: ${params_file}"
        return 1
    fi
    
    # Extract resource group name from parameters file
    local rg_name=$(grep -A1 '"resourceGroupName"' "${params_file}" | grep "value" | cut -d'"' -f4)
    local location=$(grep -A1 '"location"' "${params_file}" | grep "value" | cut -d'"' -f4)
    
    log_info "Resource Group Name: ${rg_name}"
    log_info "Location: ${location}"
    log_info "Parameters File: ${params_file}"
    log_info "Template File: ${TEMPLATE_FILE}"
    
    # Create deployment name with timestamp
    local deployment_name="rg-deployment-${environment}-${TIMESTAMP}"
    
    log_info "Starting deployment: ${deployment_name}"
    
    # Deploy using Azure CLI (subscription-level deployment)
    if az deployment sub create \
        --name "${deployment_name}" \
        --location "${location}" \
        --template-file "${TEMPLATE_FILE}" \
        --parameters "@${params_file}" \
        --output json >> "${LOG_FILE}" 2>&1; then
        
        log_success "Resource group '${rg_name}' deployed successfully"
        
        # Display resource group details
        log_info "Resource Group Details:"
        az group show --name "${rg_name}" --output table | tee -a "${LOG_FILE}"
        
        # Display deployment outputs
        log_info "Deployment Outputs:"
        az deployment sub show \
            --name "${deployment_name}" \
            --query properties.outputs \
            --output json | tee -a "${LOG_FILE}"
        
        return 0
    else
        log_error "Failed to deploy resource group '${rg_name}'"
        return 1
    fi
}

###############################################################################
# Main Script
###############################################################################

main() {
    log_info "=========================================="
    log_info "Azure Resource Group Deployment"
    log_info "KBudget GPT Project"
    log_info "=========================================="
    log_info "Execution started at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file: ${LOG_FILE}"
    log_info ""
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    check_azure_cli
    check_azure_login
    log_info ""
    
    # Validate input
    if [[ $# -eq 0 ]]; then
        log_error "No environment specified"
        echo ""
        echo "Usage: $0 <environment>"
        echo ""
        echo "Environments:"
        echo "  dev      - Deploy development resource group"
        echo "  staging  - Deploy staging resource group"
        echo "  prod     - Deploy production resource group"
        echo "  all      - Deploy all resource groups"
        echo ""
        exit 1
    fi
    
    local environment="$1"
    
    if ! validate_environment "${environment}"; then
        exit 1
    fi
    
    # Deploy based on environment parameter
    local deployment_failed=0
    
    if [[ "${environment}" == "all" ]]; then
        log_info "Deploying all environments..."
        log_info ""
        
        for env in dev staging prod; do
            if ! deploy_resource_group "${env}"; then
                deployment_failed=1
            fi
            log_info ""
        done
    else
        if ! deploy_resource_group "${environment}"; then
            deployment_failed=1
        fi
    fi
    
    # Summary
    log_info "=========================================="
    if [[ ${deployment_failed} -eq 0 ]]; then
        log_success "All deployments completed successfully!"
    else
        log_error "Some deployments failed. Check the log file for details."
    fi
    log_info "Execution completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Log file: ${LOG_FILE}"
    log_info "=========================================="
    
    exit ${deployment_failed}
}

# Run main function with all arguments
main "$@"
