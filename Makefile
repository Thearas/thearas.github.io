MAKEFLAGS += --always-make

install:
	bundle

run:
	bundle exec jekyll serve

run-prod:
	JEKYLL_ENV=production bundle exec jekyll serve

index:
	ALGOLIA_API_KEY=$(ALGOLIA_API_KEY) bundle exec jekyll algolia
