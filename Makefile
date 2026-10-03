.PHONY: project open test coverage lint format hooks check

project:
	xcodegen generate

open: project
	open LifeHub.xcodeproj

test:
	swift test --package-path Packages/HubCore
	swift test --package-path Packages/CompanionKit

coverage:
	swift test --package-path Packages/HubCore --enable-code-coverage
	scripts/coverage-gate.py Packages/HubCore 80

format:
	swift format format --in-place --recursive Apps Packages

lint:
	swift format lint --strict --recursive Apps Packages

# Run the same checks as CI before pushing.
check: lint coverage
	swift test --package-path Packages/CompanionKit

hooks:
	git config core.hooksPath scripts/git-hooks
