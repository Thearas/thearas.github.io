MAKEFLAGS += --always-make
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

init:
	pip install git+https:////github.com/Thearas/thumbhash-python.git
	brew install imagemagick pngquant yq

install:
	bundle

run:
	bundle exec jekyll serve

index:
	ALGOLIA_API_KEY=$(ALGOLIA_API_KEY) bundle exec jekyll algolia

# ENV: OUTPUT_FMT, RESIZE
optimize_images:
	bash optimize_images.sh $(ARGS)

%:
	@:
