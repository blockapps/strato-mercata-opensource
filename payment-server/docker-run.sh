#!/bin/sh
set -e

ORACLE_MODE=${ORACLE_MODE:-false}

# Checking the container mode (payment server or oracle service)
if [ "$ORACLE_MODE" = "true" ]; then
  echo "Running the container in Oracle service mode"
  
  export DOCKERIZED="true"

  export CONFIG_DIR_PATH=/config
  export SERVER_HOST=${SERVER_HOST}
  export STRATO_HOST=${STRATO_HOST}
  export OAUTH_DISCOVERY_URL=${OAUTH_DISCOVERY_URL}
  export OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID}
  export OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET}
  export METALS_USERNAME=${METALS_USERNAME}
  export METALS_PASSWORD=${METALS_PASSWORD}
  export OAUTH_SCOPE=${OAUTH_SCOPE}
  export OAUTH_SERVICE_OAUTH_FLOW=${OAUTH_SERVICE_OAUTH_FLOW}
  export METALS_API_KEY=${METALS_API_KEY}
  export ALCHEMY_API_KEY=${ALCHEMY_API_KEY}
  export SKIP_ORACLE_DEPLOYMENT=${SKIP_ORACLE_DEPLOYMENT:-false}
  export BASE_CODE_COLLECTION=${BASE_CODE_COLLECTION}
  export UPGRADE_ORACLE_CONTRACTS=${UPGRADE_ORACLE_CONTRACTS:-false}

  export ORACLE_FETCH_INTERVAL=${ORACLE_FETCH_INTERVAL:-60000}
  export SALE_UPDATE_INTERVAL=${SALE_UPDATE_INTERVAL:-60000}
  export SILVER_ORACLE_NAME_VALUE=${SILVER_ORACLE_NAME_VALUE:-'Silver'}
  export GOLD_ORACLE_NAME_VALUE=${GOLD_ORACLE_NAME_VALUE:-'Gold'}
  export ETH_ORACLE_NAME_VALUE=${ETH_ORACLE_NAME_VALUE:-'ETH'}
  export USD_ORACLE_NAME_VALUE=${USD_ORACLE_NAME_VALUE:-'USD'}
  export SILVER_ASSET_ADDRESSES=${SILVER_ASSET_ADDRESSES:-''}
  export GOLD_ASSET_ADDRESSES=${GOLD_ASSET_ADDRESSES:-''}

  echo "OAuth OpenID discovery url: $OAUTH_DISCOVERY_URL"

  if [ ! -f "${CONFIG_DIR_PATH}/oracle_config.yaml" ]; then
    # Running container for the first time
  
    cp ./config/template.oracle_config.yaml /tmp/tmp.oracle_config.yaml
  
    # Validate the env vars
    if [ -z "$METALS_API_KEY" ]; then
      echo 'Error: METALS_API_KEY is not set. submit-price script will not run. Exiting.'
      exit 11
    fi
    if [ -z "$ALCHEMY_API_KEY" ]; then
      echo 'Error: ALCHEMY_API_KEY is not set. submit-price script will not run. Exiting'
      exit 12
    fi
    # TODO: in future we can check the other env vars here
  
    # Replace placeholders in Oracle config template
    sed -i 's*<oracleFetchInterval_value>*'"${ORACLE_FETCH_INTERVAL}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<saleUpdateInterval_value>*'"${SALE_UPDATE_INTERVAL}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<silver_oracle_name_value>*'"${SILVER_ORACLE_NAME_VALUE}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<gold_oracle_name_value>*'"${GOLD_ORACLE_NAME_VALUE}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<eth_oracle_name_value>*'"${ETH_ORACLE_NAME_VALUE}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<usd_oracle_name_value>*'"${USD_ORACLE_NAME_VALUE}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<silver_asset_addresses_value>*'"${SILVER_ASSET_ADDRESSES}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<gold_asset_addresses_value>*'"${GOLD_ASSET_ADDRESSES}"'*g' /tmp/tmp.oracle_config.yaml
  
    sed -i 's*<configDirPath_value>*'"${CONFIG_DIR_PATH}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<serverHost_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<node_label_value>*'"${NODE_LABEL}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<node_url_value>*'"${STRATO_HOST}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_appTokenCookieName_value>*'"${OAUTH_APP_TOKEN_COOKIE_NAME}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_openIdDiscoveryUrl_value>*'"${OAUTH_DISCOVERY_URL}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_clientId_value>*'"${OAUTH_CLIENT_ID}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_clientSecret_value>*'"${OAUTH_CLIENT_SECRET}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_scope_value>*'"${OAUTH_SCOPE}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_serviceOAuthFlow_value>*'"${OAUTH_SERVICE_OAUTH_FLOW}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_redirectUri_value>*'"${SERVER_HOST}/login/"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_logoutRedirectUri_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_tokenField_value>*'"${OAUTH_TOKEN_FIELD}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_tokenUsernameProperty_value>*'"${OAUTH_TOKEN_USERNAME_PROPERTY}"'*g' /tmp/tmp.oracle_config.yaml
    sed -i 's*<oauth_tokenUsernamePropertyServiceFlow_value>*'"${OAUTH_TOKEN_USERNAME_PROPERTY_SERVICE_FLOW}"'*g' /tmp/tmp.oracle_config.yaml
  
    mv /tmp/tmp.oracle_config.yaml ./config/generated.oracle_config.yaml
    cp ./config/generated.oracle_config.yaml ${CONFIG_DIR_PATH}/oracle_config.yaml
  
    if [ -f "${CONFIG_DIR_PATH}/oracle_deploy.yaml" ]; then
      cat ${CONFIG_DIR_PATH}/oracle_deploy.yaml
      echo 'oracle_deploy.yaml already exists for oracle but there is no config file. Exiting.'
      exit 152
    else
      if [ "${SKIP_ORACLE_DEPLOYMENT}" != "true" ]; then
        echo 'oracle_deploy.yaml does not exist. Deploying oracle contracts...'
        yarn deploy-oracle
        echo "creating the .deployed flag file"
        touch .deployed
      else
        echo 'SKIP_ORACLE_DEPLOYMENT is true. Skipping oracle deployment...'
      fi
    fi
  else
    echo "Starting with pre-existing oracle_config.yaml"
    if [ ! -f "${CONFIG_DIR_PATH}/oracle_deploy.yaml" ]; then
      echo 'The config file exists but the oracle_deploy file is missing. Exiting.'
      exit 151
    fi
    echo "Found the existing oracle_deploy.yaml"
    if [ ! -f ".deployed" ]; then
      echo "Starting a recreated container with likely updated env vars, but reusing the pre-existing oracle_config.yaml and oracle_deploy.yaml"
      if [ "${UPGRADE_ORACLE_CONTRACTS}" = "true" ]; then
        echo "UPGRADE_ORACLE_CONTRACTS=true - deactivating oracle contracts and deploying again..."
        yarn deactivate-oracle
        yarn deploy-oracle
        echo "creating the .deployed flag file"
        touch .deployed
      fi
    fi
  fi
  
  echo 'Starting the submit-price script...'
  yarn submit-price

else
  echo "Running the container in Payment server mode"
  export DOCKERIZED="true"

  export CONFIG_DIR_PATH=/config
  export SERVER_HOST=${SERVER_HOST}
  export STRATO_HOST=${STRATO_HOST}
  export OAUTH_DISCOVERY_URL=${OAUTH_DISCOVERY_URL}
  export OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID}
  export OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET}
  export OAUTH_SCOPE=${OAUTH_SCOPE}
  export OAUTH_SERVICE_OAUTH_FLOW=${OAUTH_SERVICE_OAUTH_FLOW}
  export SKIP_CONTRACT_VALIDATION=${SKIP_CONTRACT_VALIDATION}
  export SKIP_DEPLOYMENT=${SKIP_DEPLOYMENT:-false}
  export BASE_CODE_COLLECTION=${BASE_CODE_COLLECTION}
  export UPGRADE_CONTRACTS=${UPGRADE_CONTRACTS:-false}
  export STRIPE_SERVICE_NAME_VALUE=${STRIPE_SERVICE_NAME_VALUE:-'Stripe'}
  export STRIPE_ONBOARDING_ROUTE_VALUE=${STRIPE_ONBOARDING_ROUTE_VALUE:-'/stripe/onboard'}
  export STRIPE_ONBOARDING_STATUS_ROUTE_VALUE=${STRIPE_ONBOARDING_STATUS_ROUTE_VALUE:-'/stripe/onboard/status'}
  export STRIPE_ONBOARDING_TEXT_VALUE=${STRIPE_ONBOARDING_TEXT_VALUE:-'Connect Stripe'}
  export STRIPE_CHECKOUT_ROUTE_VALUE=${STRIPE_CHECKOUT_ROUTE_VALUE:-'/stripe/checkout'}
  export STRIPE_CHECKOUT_TEXT_VALUE=${STRIPE_CHECKOUT_TEXT_VALUE:-'Checkout with Stripe'}
  export STRIPE_ORDER_STATUS_ROUTE_VALUE=${STRIPE_ORDER_STATUS_ROUTE_VALUE:-'/stripe/order/status'}
  export STRIPE_IMAGE_URL_VALUE=${STRIPE_IMAGE_URL_VALUE:-'https://assets.ctfassets.net/fzn2n1nzq965/01hMKr6nEEGVfOuhsaMIXQ/c424849423b5f036a8892afa09ac38c7/favicon.ico'}
  export STRIPE_PRIMARY_SALE_FEE_PERCENTAGE_VALUE=${STRIPE_PRIMARY_SALE_FEE_PERCENTAGE_VALUE:-10.0}
  export STRIPE_SECONDARY_SALE_FEE_PERCENTAGE_VALUE=${STRIPE_SECONDARY_SALE_FEE_PERCENTAGE_VALUE:-3.0}
  export METAMASK_SERVICE_NAME_VALUE=${METAMASK_SERVICE_NAME_VALUE:-'MetaMask'}
  export METAMASK_ONBOARDING_ROUTE_VALUE=${METAMASK_ONBOARDING_ROUTE_VALUE:-'/metamask/onboarding'}
  export METAMASK_ONBOARDING_STATUS_ROUTE_VALUE=${METAMASK_ONBOARDING_STATUS_ROUTE_VALUE:-'/metamask/onboarding/status'}
  export METAMASK_ONBOARDING_TEXT_VALUE=${METAMASK_ONBOARDING_TEXT_VALUE:-'Connect MetaMask'}
  export METAMASK_CHECKOUT_ROUTE_VALUE=${METAMASK_CHECKOUT_ROUTE_VALUE:-'/metamask/checkout'}
  export METAMASK_CHECKOUT_TEXT_VALUE=${METAMASK_CHECKOUT_TEXT_VALUE:-'Checkout with MetaMask'}
  export METAMASK_ORDER_STATUS_ROUTE_VALUE=${METAMASK_ORDER_STATUS_ROUTE_VALUE:-'/metamask/order/status'}
  export METAMASK_IMAGE_URL_VALUE=${METAMASK_IMAGE_URL_VALUE:-'https://fileserver.mercata-testnet2.blockapps.net/highway/3fe266f64979ff185364131d9f6f3bc96eb272e98691bbc829ccf31f59d956c9.png'}
  export METAMASK_PRIMARY_SALE_FEE_PERCENTAGE_VALUE=${METAMASK_PRIMARY_SALE_FEE_PERCENTAGE_VALUE:-10.0}
  export METAMASK_SECONDARY_SALE_FEE_PERCENTAGE_VALUE=${METAMASK_SECONDARY_SALE_FEE_PERCENTAGE_VALUE:-3.0}
  export USDST_ADDRESS=${USDST_ADDRESS}
  export USDST_SERVICE_NAME_VALUE=${USDST_SERVICE_NAME_VALUE:-'USDST'}
  export USDST_IMAGE_URL_VALUE=${USDST_IMAGE_URL_VALUE:-'https://blockapps-public-assets.s3.us-east-1.amazonaws.com/icons/stratFinished.png'}
  export USDST_PRIMARY_SALE_FEE_PERCENTAGE_VALUE=${USDST_PRIMARY_SALE_FEE_PERCENTAGE_VALUE:-10.0}
  export USDST_SECONDARY_SALE_FEE_PERCENTAGE_VALUE=${USDST_SECONDARY_SALE_FEE_PERCENTAGE_VALUE:-3.0}
  export USDST_FEE_RECIPIENT=${USDST_FEE_RECIPIENT}
  export REDEMPTIONS_CLOSE_REDEMPTION_ROUTE_VALUE=${REDEMPTIONS_CLOSE_REDEMPTION_ROUTE_VALUE:-'/redemption/close'}
  export REDEMPTIONS_CREATE_CUSTOMER_ADDRESS_ROUTE_VALUE=${REDEMPTIONS_CREATE_CUSTOMER_ADDRESS_ROUTE_VALUE:-'/customer/address'}
  export REDEMPTIONS_CREATE_REDEMPTION_ROUTE_VALUE=${REDEMPTIONS_CREATE_REDEMPTION_ROUTE_VALUE:-'/redemption/create'}
  export REDEMPTIONS_GET_CUSTOMER_ADDRESS_ROUTE_VALUE=${REDEMPTIONS_GET_CUSTOMER_ADDRESS_ROUTE_VALUE:-'/customer/address'}
  export REDEMPTIONS_GET_REDEMPTION_ROUTE_VALUE=${REDEMPTIONS_GET_REDEMPTION_ROUTE_VALUE:-'/redemption'}
  export REDEMPTIONS_IMAGE_URL_VALUE=${REDEMPTIONS_IMAGE_URL_VALUE:-'https://blockapps.net/wp-content/uploads/2022/08/favicon.png'}
  export REDEMPTIONS_INCOMING_REDEMPTIONS_ROUTE_VALUE=${REDEMPTIONS_INCOMING_REDEMPTIONS_ROUTE_VALUE:-'/redemption/incoming'}
  export REDEMPTIONS_OUTGOING_REDEMPTIONS_ROUTE_VALUE=${REDEMPTIONS_OUTGOING_REDEMPTIONS_ROUTE_VALUE:-'/redemption/outgoing'}
  export REDEMPTIONS_REDEEM_TEXT_VALUE=${REDEMPTIONS_REDEEM_TEXT_VALUE:-'Redeem'}
  export REDEMPTIONS_SERVICE_NAME_VALUE=${REDEMPTIONS_SERVICE_NAME_VALUE:-'BlockApps Redemptions'}

  echo "OAuth OpenID discovery url: $OAUTH_DISCOVERY_URL"

  if [ ! -f "${CONFIG_DIR_PATH}/config.yaml" ]; then
    # Running container for the first time
    
    # Generating the ./config/generated.config.yaml - an intermediate step to avoid removing CONFIG var (that would break the non-docker deployment)
    cp ./config/template.config.yaml /tmp/tmp.config.yaml
  
    # Validate the env vars
    # TODO: check if EVERY env var is provided (in the for loop - refactor)
    if [ -z "${SERVER_HOST}" ]; then
      echo "SERVER_HOST is empty but is a required value"
      exit 11
    fi
    if [[ "${SERVER_HOST}" == *"\/" ]]; then
      echo "SERVER_HOST must not contain the trailing slash"
      exit 112
    fi
      
    if [ -z "${OAUTH_CLIENT_ID}" ]; then
      echo "OAUTH_CLIENT_ID is empty but is a required value"
      exit 15
    fi
      
    if [ -z "${OAUTH_CLIENT_SECRET}" ]; then
      echo "OAUTH_CLIENT_SECRET is empty but is a required value"
      exit 16
    fi
  
    if [ -z "${USDST_ADDRESS}" ]; then
      echo "USDST_ADDRESS is empty but is a required value"
      exit 17
    fi

    if [ -z "${USDST_FEE_RECIPIENT}" ]; then
      echo "USDST_FEE_RECIPIENT is empty but is a required value"
      exit 18
    fi
  
    sed -i 's*<configDirPath_value>*'"${CONFIG_DIR_PATH}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<serverHost_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<node_label_value>*'"${NODE_LABEL}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<node_url_value>*'"${STRATO_HOST}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_appTokenCookieName_value>*'"${OAUTH_APP_TOKEN_COOKIE_NAME}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_openIdDiscoveryUrl_value>*'"${OAUTH_DISCOVERY_URL}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_clientId_value>*'"${OAUTH_CLIENT_ID}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_clientSecret_value>*'"${OAUTH_CLIENT_SECRET}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_scope_value>*'"${OAUTH_SCOPE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_serviceOAuthFlow_value>*'"${OAUTH_SERVICE_OAUTH_FLOW}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_redirectUri_value>*'"${SERVER_HOST}/login/"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_logoutRedirectUri_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_tokenField_value>*'"${OAUTH_TOKEN_FIELD}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_tokenUsernameProperty_value>*'"${OAUTH_TOKEN_USERNAME_PROPERTY}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<oauth_tokenUsernamePropertyServiceFlow_value>*'"${OAUTH_TOKEN_USERNAME_PROPERTY_SERVICE_FLOW}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_service_name_value>*'"${STRIPE_SERVICE_NAME_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_service_url_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_onboarding_route_value>*'"${STRIPE_ONBOARDING_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_onboarding_status_route_value>*'"${STRIPE_ONBOARDING_STATUS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_onboarding_text_value>*'"${STRIPE_ONBOARDING_TEXT_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_checkout_route_value>*'"${STRIPE_CHECKOUT_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_checkout_text_value>*'"${STRIPE_CHECKOUT_TEXT_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_order_status_route_value>*'"${STRIPE_ORDER_STATUS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_image_url_value>*'"${STRIPE_IMAGE_URL_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_primary_sale_fee_percentage_value>*'"${STRIPE_PRIMARY_SALE_FEE_PERCENTAGE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<stripe_secondary_sale_fee_percentage_value>*'"${STRIPE_SECONDARY_SALE_FEE_PERCENTAGE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_service_name_value>*'"${METAMASK_SERVICE_NAME_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_service_url_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_onboarding_route_value>*'"${METAMASK_ONBOARDING_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_onboarding_status_route_value>*'"${METAMASK_ONBOARDING_STATUS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_onboarding_text_value>*'"${METAMASK_ONBOARDING_TEXT_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_checkout_route_value>*'"${METAMASK_CHECKOUT_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_checkout_text_value>*'"${METAMASK_CHECKOUT_TEXT_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_order_status_route_value>*'"${METAMASK_ORDER_STATUS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_image_url_value>*'"${METAMASK_IMAGE_URL_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_primary_sale_fee_percentage_value>*'"${METAMASK_PRIMARY_SALE_FEE_PERCENTAGE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<metamask_secondary_sale_fee_percentage_value>*'"${METAMASK_SECONDARY_SALE_FEE_PERCENTAGE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<USDST_USDST_address_value>*'"${USDST_ADDRESS}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<USDST_service_name_value>*'"${USDST_SERVICE_NAME_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<USDST_image_url_value>*'"${USDST_IMAGE_URL_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<USDST_primary_sale_fee_percentage_value>*'"${USDST_PRIMARY_SALE_FEE_PERCENTAGE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<USDST_secondary_sale_fee_percentage_value>*'"${USDST_SECONDARY_SALE_FEE_PERCENTAGE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<USDST_fee_recipient_value>*'"${USDST_FEE_RECIPIENT}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_close_redemption_route_value>*'"${REDEMPTIONS_CLOSE_REDEMPTION_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_create_customer_address_route_value>*'"${REDEMPTIONS_CREATE_CUSTOMER_ADDRESS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_create_redemption_route_value>*'"${REDEMPTIONS_CREATE_REDEMPTION_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_get_customer_address_route_value>*'"${REDEMPTIONS_GET_CUSTOMER_ADDRESS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_get_redemption_route_value>*'"${REDEMPTIONS_GET_REDEMPTION_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_image_url_value>*'"${REDEMPTIONS_IMAGE_URL_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_incoming_redemptions_route_value>*'"${REDEMPTIONS_INCOMING_REDEMPTIONS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_outgoing_redemptions_route_value>*'"${REDEMPTIONS_OUTGOING_REDEMPTIONS_ROUTE_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_redeem_text_value>*'"${REDEMPTIONS_REDEEM_TEXT_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_service_name_value>*'"${REDEMPTIONS_SERVICE_NAME_VALUE}"'*g' /tmp/tmp.config.yaml
    sed -i 's*<redemptions_service_url_value>*'"${SERVER_HOST}"'*g' /tmp/tmp.config.yaml
  
    mv /tmp/tmp.config.yaml ./config/generated.config.yaml
    cp ./config/generated.config.yaml ${CONFIG_DIR_PATH}/config.yaml
  
    if [ -f "${CONFIG_DIR_PATH}/deploy.yaml" ]; then
      cat ${CONFIG_DIR_PATH}/deploy.yaml
      echo 'deploy.yaml already exists but there is no config file. Exiting.'
      exit 52
    else
      if [ "${SKIP_ORACLE_DEPLOYMENT}" != "true" ]; then
        echo 'deploy.yaml does not exist. Deploying payment server contracts...'
        yarn deploy
        echo "Creating the .deployed flag file"
        touch .deployed
      else
        echo 'SKIP_DEPLOYMENT is true. Skipping deployment...'
      fi
    fi
  else
    echo "Starting with pre-existing config.yaml"
    if [ ! -f "${CONFIG_DIR_PATH}/deploy.yaml" ]; then
      echo 'The config file exists but the deploy file is missing. Exiting.'
      exit 51
    fi
    echo "Found the existing deploy.yaml"
    if [ ! -f ".deployed" ]; then
      echo "Starting a recreated container with likely updated env vars, but reusing the pre-existing config.yaml and deploy.yaml"
      if [ "${UPGRADE_CONTRACTS}" = "true" ]; then
        echo '"UPGRADE_CONTRACTS=true - deactivating payment server contracts and deploying again...'
        yarn deactivate
        yarn deploy
        echo "Creating the .deployed flag file"
        touch .deployed
      fi
    fi
  fi

  echo 'Starting payment server...'
  yarn start
fi
