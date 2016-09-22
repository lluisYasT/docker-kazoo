NS = vp
NAME = kazoo
APP_VERSION = 4.0
IMAGE_VERSION = 2.0
VERSION = $(APP_VERSION)-$(IMAGE_VERSION)
LOCAL_TAG = $(NS)/$(NAME):$(VERSION)

REGISTRY = callforamerica
ORG = vp
REMOTE_TAG = $(REGISTRY)/$(NAME):$(VERSION)

GITHUB_REPO = docker-kazoo
DOCKER_REPO = kazoo
BUILD_BRANCH = master


.PHONY: all build test release shell run start stop rm rmi default

all: build

checkout:
	@git checkout $(BUILD_BRANCH)

build:
	@docker build -t $(LOCAL_TAG) --rm .
	$(MAKE) tag

tag:
	@docker tag $(LOCAL_TAG) $(REMOTE_TAG)

rebuild:
	@docker build -t $(LOCAL_TAG) --rm --no-cache .

test:
	@rspec ./tests/*.rb

commit:
	@git add -A .
	@git commit

push:
	@git push origin master

shell:
	@docker exec -ti $(NAME) /bin/bash

run:
	@docker run -it --rm --name $(NAME) --entrypoint bash $(LOCAL_TAG)

launch-deps:
	-cd ../docker-rabbitmq && make launch-net
	-cd ../docker-bigcouch && make launch-net

kill-deps:
	-cd ../docker-rabbitmq && make kill && make rm
	-cd ../docker-bigcouch && make kill && make rm

launch:
	@docker run -d --name $(NAME) -h $(NAME) -p "8000:8000" $(LOCAL_TAG)

launch-net:
	@docker run -d --name $(NAME) -h $(NAME).local -e "BIGCOUCH_HOST=bigcouch.local" -e "KAZOO_LOG_LEVEL=debug" -p "8000:8000" --network=local --net-alias=$(NAME).local $(LOCAL_TAG)

create-network:
	@docker network create -d bridge local

init-account:
	@docker exec $(NAME) sup crossbar_maintenance create_account valuphone localhost admin test

init-apps:
	@docker exec $(NAME) sup crossbar_maintenance init_apps /var/www/html/monster-ui/apps http://localhost:8000/v2

get-master-account:
	@docker exec $(NAME) sup crossbar_maintenance find_account_by_name valuphone

logs:
	@docker logs $(NAME)

logsf:
	@docker logs -f $(NAME)

start:
	@docker start $(NAME)

kill:
	@docker kill $(NAME)

stop:
	@docker stop $(NAME)

rm:
	@docker rm $(NAME)

rmi:
	@docker rmi $(LOCAL_TAG)
	@docker rmi $(REMOTE_TAG)

kube-deploy-service:
	@kubectl create -f kubernetes/$(NAME)-service.yaml

kube-deploy:
	@kubectl create -f kubernetes/$(NAME)-deployment.yaml --record

kube-deploy-edit:
	@kubectl edit deployment/$(NAME)
	$(NAME) kube-rollout-status

kube-deploy-rollback:
	@kubectl rollout undo deployment/$(NAME)

kube-rollout-status:
	@kubectl rollout status deployment/$(NAME)

kube-rollout-history:
	@kubectl rollout history deployment/$(NAME)

kube-delete-deployment:
	@kubectl delete deployment/$(NAME)

kube-delete-service:
	@kubectl delete svc $(NAME)

kube-apply-service:
	@kubectl apply -f kubernetes/$(NAME)-service.yaml

kube-logsf:
	@kubectl logs -f $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1)

kube-logsft:
	@kubectl logs -f --tail=25 $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1)

kube-shell:
	@kubectl exec -ti $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- bash

kazoo-maint-nodes:
	@kubectl exec $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- sup -h "$$(shell hostname)" kazoo_maintenance nodes

default: build