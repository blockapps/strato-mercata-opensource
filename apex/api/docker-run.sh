#!/usr/bin/env sh
set -e
set -x

# TODO: Set POSTGRES vars defaults here, remove default from docker-compose.yml, rename postgres vars using uppercase
PROMETHEUS_HOST=${PROMETHEUS_HOST:-'prometheus:9090'}
STRATO_HOSTNAME=${STRATO_HOSTNAME:-strato}
STRATO_PORT_API=${STRATO_PORT_API:-3000}
STRATO_PORT_VAULT_PROXY=${STRATO_PORT_VAULT_PROXY:-8013}

source set-aux-env-vars.sh

# Validate required environment variables
REQUIRED_VARS=(
  "postgres_user"
  "postgres_password"
  "postgres_host"
  "postgres_port"
)

echo "Validating required environment variables..."
for VAR_NAME in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR_NAME}" ]; then
    echo "ERROR: ${VAR_NAME} is not set but is required"
    exit 1
  fi
done

# Validate blockchain gas configuration environment variables if provided
if [ ! -z "${BLOCKCHAIN_GAS_LIMIT}" ]; then
  if ! [[ "${BLOCKCHAIN_GAS_LIMIT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: BLOCKCHAIN_GAS_LIMIT must be a valid integer"
    exit 1
  fi
  echo "Using BLOCKCHAIN_GAS_LIMIT: ${BLOCKCHAIN_GAS_LIMIT}"
fi

if [ ! -z "${BLOCKCHAIN_GAS_PRICE}" ]; then
  if ! [[ "${BLOCKCHAIN_GAS_PRICE}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: BLOCKCHAIN_GAS_PRICE must be a valid integer"
    exit 1
  fi
  echo "Using BLOCKCHAIN_GAS_PRICE: ${BLOCKCHAIN_GAS_PRICE}"
fi

# Set postgres configurations
sed -i -e 's|__apex_postgres_user__|'"${postgres_user}"'|g' config/config.json
sed -i -e 's|__apex_postgres_password__|'"${postgres_password}"'|g' config/config.json
sed -i -e 's|__apex_postgres_host__|'"${postgres_host}"'|g' config/config.json
sed -i -e 's|__apex_postgres_port__|'"${postgres_port}"'|g' config/config.json

sed -i -e 's|__bloc_postgres_user__|'"${postgres_user}"'|g' models/strato/bloc22/config.json
sed -i -e 's|__bloc_postgres_password__|'"${postgres_password}"'|g' models/strato/bloc22/config.json
sed -i -e 's|__bloc_postgres_host__|'"${postgres_host}"'|g' models/strato/bloc22/config.json
sed -i -e 's|__bloc_postgres_port__|'"${postgres_port}"'|g' models/strato/bloc22/config.json

sed -i -e 's|__strato_postgres_user__|'"${postgres_user}"'|g' models/strato/eth/config.js
sed -i -e 's|__strato_postgres_password__|'"${postgres_password}"'|g' models/strato/eth/config.js
sed -i -e 's|__strato_postgres_host__|'"${postgres_host}"'|g' models/strato/eth/config.js
sed -i -e 's|__strato_postgres_port__|'"${postgres_port}"'|g' models/strato/eth/config.js

echo 'Waiting for strato to be available...'
until curl --silent --output /dev/null --fail --location ${stratoRoot}/stats/totaltx
do
  echo "Check at $(date)"
  sleep 1
done
echo 'strato is available'

echo 'Waiting for postgres to be available...'
until pg_isready -h ${postgres_host} -p ${postgres_port}
do
    echo "Check at $(date)"
    sleep 1
done
echo 'postgres is available'

npm run start:prod
