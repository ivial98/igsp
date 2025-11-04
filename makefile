# ==========================
# iGSP Docs Makefile
# ==========================

# Default target
.DEFAULT_GOAL := serve

# Start local Jekyll server
serve:
	@echo "🚀 Starting local Jekyll server..."
	bundle exec jekyll serve --livereload --incremental

# Clean generated site
clean:
	@echo "🧹 Cleaning _site and cache..."
	rm -rf _site .jekyll-cache .sass-cache

# Install dependencies
install:
	@echo "📦 Installing Ruby gems..."
	bundle install

# Update dependencies
update:
	@echo "⬆️  Updating Ruby gems..."
	bundle update

# Debug build (without livereload)
build:
	@echo "🏗️  Building site..."
	bundle exec jekyll build

# Show help
help:
	@echo ""
	@echo "Usage:"
	@echo "  make serve    - Run local Jekyll server with live reload"
	@echo "  make build    - Build static site into _site/"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make install  - Install Ruby dependencies"
	@echo "  make update   - Update Ruby dependencies"
	@echo ""