MAKEFLAGS += --always-make

init:
	pip3 install thumbhash-python
	brew install imagemagick pngquant yq

install:
	bundle

run:
	bundle exec jekyll serve

run-prod:
	JEKYLL_ENV=production bundle exec jekyll serve

index:
	ALGOLIA_API_KEY=$(ALGOLIA_API_KEY) bundle exec jekyll algolia

optimize_images:
	bash optimize_images.sh
