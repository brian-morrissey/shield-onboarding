#!/bin/bash

# Source functions used by this script
source ./helpers/functions.sh

echo -e "\033[32mRunning pre-install validation...\033[0m"

#
# check for yq already installed or use bundled arm/amd binaries with alias
#
if ! command -v yq &> /dev/null; then
  arch=$(uname -m)
  if [[ "$arch" == "x86_64" ]]; then
    yq() {
      ./helpers/yq_linux_amd64 "$@"
    }
    echo -e "\033[32myq is installed.\033[0m"
  elif [[ "$arch" == "aarch64" ]]; then
    yq() {
      ./helpers/yq_linux_arm64 "$@"
    }
    echo -e "\033[32myq is installed.\033[0m"
  else
    echo -e "\033[31mUnsupported platform type: $arch. Please install yq manually.\033[0m"
    exit 1
  fi
fi

# Run preinstall Checks
chmod +x ./helpers/pre-install-validation.sh
./helpers/pre-install-validation.sh

# Check the exit code of pre-install-validation.sh
if [ $? -ne 0 ]; then
    echo -e "\e[31mPre-install validation FAILED.\e[0m"
    while true; do
        read -p "Do you still want to continue with the installation? (yes/no): " CONTINUE_AFTER_FAILURE
        if [[ "$CONTINUE_AFTER_FAILURE" == "yes" || "$CONTINUE_AFTER_FAILURE" == "no" ]]; then
            break
        else
            echo "Please enter 'yes' or 'no'."
        fi
    done
    if [[ "$CONTINUE_AFTER_FAILURE" != "yes" ]]; then
        echo "Installation aborted by the user due to pre-install validation failure."
        exit 1
    fi
fi

# Extract values from cluster-specific-values.yaml
SHIELD_CHART_VERSION=$(grep '# Shield Chart:' cluster-specific-values.yaml | awk '{print $4}')

# Check if the values exist, if not, error out
if [[ -z "$SHIELD_CHART_VERSION" ]]; then
    echo "Error: Shield Chart version not found in cluster-specific-values.yaml"
    exit 1
fi

# Assume if change_me is in the file they need to update values so dont prompt
if grep -q "CHANGE_ME" cluster-specific-values.yaml; then
 UPDATE_VALUES='yes'
else
    while true; do
        read -p "Do you want to update the values in cluster-specific-values.yaml? (yes/no): " UPDATE_VALUES
        if [[ "$UPDATE_VALUES" == "yes" || "$UPDATE_VALUES" == "no" ]]; then
            break
        else
            echo "Please enter 'yes' or 'no'."
        fi
    done
fi

if [[ "$UPDATE_VALUES" == "yes" ]]; then
    update_sysdig_accesskey  # Get Access Key and Set as Variable
    update_vz_vastid         # Get vz-vastid and Update Values
    update_vz_vsadid         # Get vz-vsadid and Update Values   
    update_cluster_name      # Get Cluster Name and Update Values
    update_proxy_settings    # Get Proxy Settings and Update Values
    update_priority_class    # Get Priority Class and Update Values
    update_resource_sizing   # Get Resource Sizing and Update Values
else
    echo "Skipping updates to cluster-specific-values.yaml per user."
    echo
fi

# Check to see if access key was specified in cluster-specific-values.yaml
ACCESS_KEY=$(grep 'access_key:' cluster-specific-values.yaml | awk '{print $2}' | tr -d '"')

if [[ -z "$ACCESS_KEY" && -z "$SYSDIG_ACCESS_KEY" ]]; then
    update_sysdig_accesskey
fi

# Get the namespace from the user
update_namespace

# Call the function to confirm values
confirm_values

# Start Sysdig Install
helm upgrade --install --create-namespace \
    -n $NAMESPACE \
    -f ./helpers/base-values.yaml -f cluster-specific-values.yaml  \
    --set sysdig_endpoint.access_key=$SYSDIG_ACCESS_KEY \
    sysdig-shield \
    $SHIELD_CHART_VERSION

# Run post-install validation
echo
echo "Sleeping for 5 minutes to allow for pods to start..."
sleep 300
chmod +x ./helpers/post-install-validation.sh
./helpers/post-install-validation.sh $NAMESPACE
