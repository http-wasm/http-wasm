# sync this with netlify.toml!
hugo          := github.com/gohugoio/hugo@v0.102.3

.PHONY: site
site: ## Serve website content
	@git submodule update --init
	@go run --tags extended $(hugo) server --minify --disableFastRender --baseURL localhost:1313 --cleanDestinationDir -D

