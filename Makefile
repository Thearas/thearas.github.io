MAKEFLAGS += --always-make

init:
#	npm install thumbhash
#	go install github.com/fogleman/primitive@latest
	brew install imagemagick
	brew reinstall pngquant

install:
	bundle

run:
	bundle exec jekyll serve

run-prod:
	JEKYLL_ENV=production bundle exec jekyll serve

index:
	ALGOLIA_API_KEY=$(ALGOLIA_API_KEY) bundle exec jekyll algolia

image:
	bash optimize_images.sh
