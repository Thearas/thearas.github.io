install:
	bundle

run:
	bundle exec jekyll serve

run-prod:
	JEKYLL_ENV=production bundle exec jekyll serve
