.PHONY: project open test

project:
	xcodegen generate

open: project
	open LifeHub.xcodeproj

test:
	swift test --package-path Packages/HubCore
