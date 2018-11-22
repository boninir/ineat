SHELL = /bin/bash
.DEFAULT_GOAL := help

PROJECT = ineat
NETWORK = $(PROJECT)_default
DOCKER_COMPOSE = docker-compose
DC_EXEC = $(DOCKER_COMPOSE) exec $(DC_TTY)
DC_WEB = $(DC_EXEC) web
DC_PHP = $(DC_WEB) php -d memory_limit=3g
DC_CONSOLE = $(DC_WEB) bin/console
DC_COMPOSER = $(DC_PHP) /usr/bin/composer

##
## Project environment
## -------------------

build:
	@$(DOCKER_COMPOSE) pull --parallel --ignore-pull-failures 2> /dev/null
	@$(DOCKER_COMPOSE) build --pull

start: ## Start the project
	@$(DOCKER_COMPOSE) up -d --remove-orphans --no-recreate

install: build start vendor ## Install and start the project

update: ## Launches composer update. repo=xxx to update a specific repo
	$(eval repo ?= )
	@$(DC_EXEC) --user www-data php sh -c "composer update $(repo)"

kill:
	$(DOCKER_COMPOSE) kill
	$(DOCKER_COMPOSE) down --volumes --remove-orphans

reset: kill install ## Stop and start a fresh install of the project

ps: ## Shows containers state
	@$(DOCKER_COMPOSE) ps

exec: ## Executes a command in a container
	$(eval app ?= php)
	$(eval user ?= www-data)
	$(eval cmd ?= bash)
	@$(DC_EXEC) --user $(user) $(app) sh -c "$(cmd)"

stop: ## Stop the project
	$(DOCKER_COMPOSE) stop

down: ## Shutdowns a container
	@$(DOCKER_COMPOSE) down -v --remove-orphans

rm: ## Removes a container
	$(eval app ?= mysql php nginx)
	@$(DOCKER_COMPOSE) rm --all -f $(app) 2>&1

destroy: stop rm ## Destroys a container

recreate: destroy up ## Recreates a container

vendor: ## Initialize the project vendors
	@$(DC_COMPOSER) install --no-suggest --no-progress --no-interaction

vendor-update: ## Update one or more vendor
	@$(DC_COMPOSER) update $(vendors)

.PHONY: build start install update kill reset ps exec stop down rm destroy recreate vendor vendor-update

##
## Database
## --------

create-db:
	@$(DC_CONSOLE) doctrine:database:drop --force > /dev/null
	@$(DC_CONSOLE) doctrine:database:create > /dev/null
	@$(DC_CONSOLE) doctrine:migrations:migrate --no-interaction -- latest > /dev/null

install-db: ## Creates the database schema and load fixtures
	@$(DOCKER_COMPOSE) --user www-data php sh -c "bin/console doctrine:schema:create"
	@$(DOCKER_COMPOSE) --user www-data php sh -c "bin/console doctrine:fixtures:load --append"

update-db: ## Updates the database schema
	@$(DC_EXEC) --user www-data php sh -c "bin/console doctrine:schema:update --force"

drop-db: ## Dropes the database
	@$(DC_EXEC) -user www-data php sh -c "bin/console doctrine:database:drop --force --if-exists"

check-db-migrations: create-db ## Validate that migrations are working properly
	@$(DC_CONSOLE) doctrine:migrations:migrate --no-interaction -- first > /dev/null

generate-migration: create-db ## Generate the missing migrations
	@$(DC_CONSOLE) doctrine:migrations:diff

mysql: ## Connects you to the mysql server
	@$(DOCKER_COMPOSE) run --rm mysql mysql ineat -hineat -uineat -pineat

.PHONY: create-db install-db update-db drop-db check-db-migrations generate-migration mysql

##
## General
## -------

wait_app: ## Waits for an app to be starts
	@docker run --rm --net=$(NETWORK) -e TIMEOUT=120 -e TARGETS=nginx:80,mysql:3306 ddn0/wait 2> /dev/null

help: ## Show help
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

.PHONY: wait_app help