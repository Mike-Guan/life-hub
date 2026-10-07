.PHONY: project open test coverage lint format hooks check art art-check screenshots

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

# Regenerate RunnerArt.swift and KuroArt.swift from their layered SVGs in docs/03 Product/companion/.
art:
	node Packages/CompanionKit/Tools/gen-runner-art.mjs
	node Packages/CompanionKit/Tools/gen-runner-art.mjs --kuro

# Fail if the generated art is out of date with the SVGs.
art-check: art
	git diff --exit-code -- Packages/CompanionKit/Sources/CompanionKit/RunnerArt.swift \
		Packages/CompanionKit/Sources/CompanionKit/KuroArt.swift

# Redraw the README images in docs/screenshots/ (iOS simulator + Mac window, one per mode).
screenshots:
	scripts/screenshots.sh
