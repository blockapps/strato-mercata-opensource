REPO_URL ?= 
ifeq ($(REPO),private)
  REPO_URL=registry-aws.blockapps.net:5000/blockapps/
endif
ifeq ($(REPO),public)
  REPO_URL=registry-aws.blockapps.net:5000/blockapps-repo/
endif
$(info REPO_URL is "${REPO_URL}" (REPO: "${REPO}"))
REPO_AWS_ECR_URL=406773134706.dkr.ecr.us-east-1.amazonaws.com/strato/
$(info REPO_AWS_ECR_URL is "${REPO_AWS_ECR_URL}")

STACK_RESOLVER=$(shell cat strato/stack.yaml | grep "resolver:" | awk '{print $$2}')
FAKEROOT=$(shell pwd)/.docker-work
HIGHWAYDIR=${FAKEROOT}/highway
STRATODIR=${FAKEROOT}/strato
VAULTDIR=${FAKEROOT}/vault-wrapper
IDENTITYDIR=${FAKEROOT}/identity-provider

ifndef VERSION
  ifeq ($(REPO),public)
    VERSION = `cat VERSION`
    $(info Using version tag from VERSION file)
  else
    VERSION = `cat VERSION`-`git rev-parse --short HEAD`
  endif
else
  $(info VERSION is "${VERSION}" (overriden with env var))
endif

$(info )

all: build_all docker-compose eks

all_develop: build_develop docker-compose eks

build_all: strato apex highway highway-nginx nginx postgrest prometheus smd marketplace-backend marketplace-ui vault-wrapper vault-nginx identity-provider identity-nginx payment-server payment-server-nginx notification-server notification-server-nginx

build_develop: develop apex highway highway-nginx nginx postgrest prometheus smd marketplace-backend marketplace-ui vault-wrapper vault-nginx identity-provider identity-nginx payment-server payment-server-nginx notification-server notification-server-nginx

.PHONY: strato apex highway highway-nginx nginx postgrest prometheus smd marketplace-backend marketplace-ui vault-wrapper vault-nginx identity-provider identity-nginx payment-server payment-server-nginx notification-server notification-server-nginx build_buildbase build_common build_common_profiled eks

apex:
	@echo Now building apex...
	BASIL_DOCKER_TAG=${REPO_URL}apex:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}apex:${VERSION} STRATO_VERSION=${VERSION} make --directory=apex/

nginx:
	@echo Now building nginx...
	BASIL_DOCKER_TAG=${REPO_URL}nginx:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}nginx:${VERSION} make --directory=nginx-packager/

postgrest:
	@echo Now building postgrest...
	BASIL_DOCKER_TAG=$(REPO_URL)postgrest:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}postgrest:${VERSION} make --directory=postgrest-packager/

prometheus:
	@echo Now building prometheus...
	BASIL_DOCKER_TAG=$(REPO_URL)prometheus:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}prometheus:${VERSION} make --directory=prometheus-packager/

smd:
	@echo building smd...
	BASIL_DOCKER_TAG=${REPO_URL}smd:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}smd:${VERSION} STRATO_VERSION=${VERSION} make --directory=smd-ui/

marketplace-backend:
	@echo Now building marketplace-backend...
	BASIL_DOCKER_TAG=${REPO_URL}marketplace-backend:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}marketplace-backend:${VERSION} make --directory=marketplace/backend/

marketplace-ui:
	@echo Now building marketplace-ui...
	BASIL_DOCKER_TAG=${REPO_URL}marketplace-ui:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}marketplace-ui:${VERSION} make --directory=marketplace/ui/

payment-server:
	@echo Now building payment server...
	BASIL_DOCKER_TAG=${REPO_URL}payment-server:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}payment-server:${VERSION} make --directory=payment-server/

payment-server-nginx:
	@echo Now building payment-server-nginx...
	BASIL_DOCKER_TAG=${REPO_URL}payment-server-nginx:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}payment-server-nginx:${VERSION} make --directory=payment-server-nginx/

notification-server:
	@echo Now building notification server...
	BASIL_DOCKER_TAG=${REPO_URL}notification-server:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}notification-server:${VERSION} make --directory=notification-server/

notification-server-nginx:
	@echo Now building notification-server-nginx...
	BASIL_DOCKER_TAG=${REPO_URL}notification-server-nginx:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}notification-server-nginx:${VERSION} make --directory=notification-server-nginx/

eks:
	@echo Now generating eks manifest files
	cd k8s/eks/strato && sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' strato-platform-manifest.tpl.yaml > strato-platform-manifest.yaml
	cd k8s/eks/vault && sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' eks-vault-deployment.tpl.yaml > eks-vault-deployment.yaml
	#TODO: create eks manifest for identity server
	#cd k8s/eks/identity && sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' eks-identity-deployment.tpl.yaml > eks-identity-deployment.yaml
	#TODO: create eks manifest for highway server
	#TODO: create eks manifest for payment server
	#TODO: create eks manifest for notification server

build_buildbase:
	@echo building buildbase...
	docker build --build-arg STACK_RESOLVER=${STACK_RESOLVER} --tag=strato-buildbase:${STACK_RESOLVER} - < Dockerfile.buildbase

build_formatter:
	@echo building code formatter...
	docker build --build-arg STACK_RESOLVER=${STACK_RESOLVER} --tag=strato-formatter:${STACK_RESOLVER} - < Dockerfile.formatter

build_common: build_buildbase
	@echo building haskell libraries and creating directories
	mkdir -p ${HIGHWAYDIR}
	mkdir -p ${STRATODIR}
	mkdir -p ${VAULTDIR}
	mkdir -p ${IDENTITYDIR}
	cd strato && stack build \
		--test --no-run-tests \
		--copy-bins --local-bin-path=${FAKEROOT}/usr/local/bin

build_common_profiled: build_buildbase
	@echo building haskell libraries and creating directories
	mkdir -p ${HIGHWAYDIR}
	mkdir -p ${STRATODIR}
	mkdir -p ${VAULTDIR}
	mkdir -p ${IDENTITYDIR}
	cd strato && stack build \
		--profile --work-dir .stack-work-profile \
		--copy-bins --local-bin-path=${FAKEROOT}/usr/local/bin

build_common_fast: build_buildbase
	@echo building haskell libraries and creating directories
	mkdir -p ${STRATODIR}
	mkdir -p ${VAULTDIR}
	mkdir -p ${IDENTITYDIR}
	cd strato && stack build \
		--fast --no-run-tests \
		--copy-bins --local-bin-path=${FAKEROOT}/usr/local/bin

pretty: build_formatter
	@echo formatting STRATO Haskell code...
	docker run --rm -v .:/strato-platform strato-formatter:${STACK_RESOLVER} ormolu --mode inplace `git ls-files '*.hs'`

gen-hie: build_formatter develop
	@echo generating hie.yaml file...
	docker run --rm -v .:/strato-platform strato-formatter:${STACK_RESOLVER} `cd strato && gen-hie > hie.yaml`

hoogle_generate: build_buildbase
	@echo generating STRATO documentation...
	cd strato && \
		stack haddock --haddock-internal && \
		stack hoogle generate -- --local
	
hoogle_serve:
	@echo serving the pregenerated STRATO documentation...
	cd strato && \
		stack hoogle -- server --local

hoogle: hoogle_generate hoogle_serve

highway: build_common 
	@echo Now building highway...
	cp strato/highway/doit.sh ${HIGHWAYDIR}
	docker build --target highway --tag ${REPO_URL}highway:${VERSION} --file Dockerfile.multi ${FAKEROOT}
	docker tag ${REPO_URL}highway:${VERSION} ${REPO_AWS_ECR_URL}highway:${VERSION}

highway-nginx:
	@echo Now building highway-nginx...
	BASIL_DOCKER_TAG=${REPO_URL}highway-nginx:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}highway-nginx:${VERSION} make --directory=highway-nginx/

strato: build_common
	@echo Now building core-strato...
	cp -fr strato/extraFiles/* ${STRATODIR}
	docker build --target strato --tag ${REPO_URL}strato:${VERSION} --file Dockerfile.multi ${FAKEROOT}
	docker tag ${REPO_URL}strato:${VERSION} ${REPO_AWS_ECR_URL}strato:${VERSION}

develop: build_common_fast
	@echo Now building core-strato using --fast...
	cp -fr strato/extraFiles/* ${STRATODIR}
	docker build --target strato --tag ${REPO_URL}strato:${VERSION} --file Dockerfile.multi ${FAKEROOT}
	docker tag ${REPO_URL}strato:${VERSION} ${REPO_AWS_ECR_URL}strato:${VERSION}

profile: build_common_profiled
	@echo Now building core-strato using --profile...
	cp -fr strato/extraFiles/* ${STRATODIR}
	docker build --target strato --tag ${REPO_URL}strato:${VERSION} --file Dockerfile.multi ${FAKEROOT}
	docker tag ${REPO_URL}strato:${VERSION} ${REPO_AWS_ECR_URL}strato:${VERSION}

vault-wrapper: build_common
	@echo Now building vault-wrapper...
	cp strato/vault/doit.sh ${VAULTDIR}
	docker build --target vault-wrapper --tag ${REPO_URL}vault-wrapper:${VERSION} --file Dockerfile.multi ${FAKEROOT}
	docker tag ${REPO_URL}vault-wrapper:${VERSION} ${REPO_AWS_ECR_URL}vault-wrapper:${VERSION}

vault-nginx:
	@echo Now building vault-nginx...
	BASIL_DOCKER_TAG=${REPO_URL}vault-nginx:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}vault-nginx:${VERSION} make --directory=vault-nginx/

identity-provider: build_common
	@echo Now building Identity Server...
	cp strato/identity-provider/doit.sh ${IDENTITYDIR}
	docker build --target identity-provider --tag ${REPO_URL}identity-provider:${VERSION} --file Dockerfile.multi ${FAKEROOT}
	docker tag ${REPO_URL}identity-provider:${VERSION} ${REPO_AWS_ECR_URL}identity-provider:${VERSION}

identity-nginx:
	@echo Now building identity-nginx...
	BASIL_DOCKER_TAG=${REPO_URL}identity-nginx:${VERSION} ECR_DOCKER_TAG=${REPO_AWS_ECR_URL}identity-nginx:${VERSION} make --directory=identity-nginx/

docker-compose:
	@echo Now generating docker-compose yml files...
	@echo Creating the image-push-ready docker-compose.push.yml...
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.tpl.yml > docker-compose.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.tpl.yml > docker-compose.push.ecr.yml
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.vault.tpl.yml > docker-compose.vault.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.vault.tpl.yml > docker-compose.vault.push.ecr.yml
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.identity.tpl.yml > docker-compose.identity.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.identity.tpl.yml > docker-compose.identity.push.ecr.yml
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.highway.tpl.yml > docker-compose.highway.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.highway.tpl.yml > docker-compose.highway.push.ecr.yml
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.payment.tpl.yml > docker-compose.payment.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.payment.tpl.yml > docker-compose.payment.push.ecr.yml
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.oracle.tpl.yml > docker-compose.oracle.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.oracle.tpl.yml > docker-compose.oracle.push.ecr.yml
	sed -e 's|<REPO_URL>|'"${REPO_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.notification.tpl.yml > docker-compose.notification.push.yml
	sed -e 's|<REPO_URL>|'"${REPO_AWS_ECR_URL}"'|g' -e 's|<VERSION>|'"${VERSION}"'|g' docker-compose.notification.tpl.yml > docker-compose.notification.push.ecr.yml

	@echo Creating the final docker-compose.yml...
	awk '/build: ./{getline} 1' docker-compose.push.yml > docker-compose.yml
	awk '/build: ./{getline} 1' docker-compose.push.ecr.yml > docker-compose.ecr.yml
	awk '/build: ./{getline} 1' docker-compose.vault.push.yml > docker-compose.vault.yml
	awk '/build: ./{getline} 1' docker-compose.vault.push.ecr.yml > docker-compose.vault.ecr.yml
	awk '/build: ./{getline} 1' docker-compose.identity.push.yml > docker-compose.identity.yml
	awk '/build: ./{getline} 1' docker-compose.identity.push.ecr.yml > docker-compose.identity.ecr.yml
	awk '/build: ./{getline} 1' docker-compose.highway.push.yml > docker-compose.highway.yml
	awk '/build: ./{getline} 1' docker-compose.highway.push.ecr.yml > docker-compose.highway.ecr.yml
	awk '/build: ./{getline} 1' docker-compose.payment.push.yml > docker-compose.payment.yml
	awk '/build: ./{getline} 1' docker-compose.payment.push.ecr.yml > docker-compose.payment.ecr.yml
	awk '/build: ./{getline} 1' docker-compose.oracle.push.yml > docker-compose.oracle.yml
	awk '/build: ./{getline} 1' docker-compose.oracle.push.ecr.yml > docker-compose.oracle.ecr.yml
    # Oracle uses the payment server docker image - not pushing oracle image separately
	rm -rf docker-compose.oracle.push.yml docker-compose.oracle.push.ecr.yml
	awk '/build: ./{getline} 1' docker-compose.notification.push.yml > docker-compose.notification.yml
	awk '/build: ./{getline} 1' docker-compose.notification.push.ecr.yml > docker-compose.notification.ecr.yml

docker-build:
	cp -fr strato/extraFiles/* ${STRATODIR}
	docker build --target strato --tag ${REPO_URL}strato:${VERSION} --file Dockerfile.multi ${FAKEROOT}

test:
	@echo ${VERSION}

docker-clean:
	rm -rf ${FAKEROOT}
