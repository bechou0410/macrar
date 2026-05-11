SHELL := /bin/bash
SCHEME := MacRAR
WORKSPACE := MacRAR.xcworkspace
PROJECT := MacRAR.xcodeproj
APP := build/Release/MacRAR.app

.PHONY: help project clean universal build sign install verify dmg test rarkit register all

help:
	@echo "MacRAR build targets:"
	@echo "  project    — Generate Xcode project from project.yml (xcodegen)"
	@echo "  universal  — lipo arm64+x86_64 unrar → Vendor/unrar/universal/unrar"
	@echo "  build      — xcodebuild Release"
	@echo "  sign       — ad-hoc codesign the .app bundle"
	@echo "  verify     — sanity-check signatures"
	@echo "  dmg        — package signed .app into DMG (Phase 10)"
	@echo "  test       — run XCTest + Swift Package tests"
	@echo "  rarkit     — build RarKit Swift package standalone"
	@echo "  clean      — wipe build/ + DerivedData"
	@echo "  all        — project + universal + build + sign"

project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "Install: brew install xcodegen"; exit 1; }
	xcodegen generate

universal:
	bash Scripts/build-universal-binaries.sh

build: universal
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath build/DerivedData \
		CONFIGURATION_BUILD_DIR=$(PWD)/build/Release \
		build | xcbeautify --quiet || xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath build/DerivedData \
		CONFIGURATION_BUILD_DIR=$(PWD)/build/Release \
		build

sign:
	bash Scripts/sign-adhoc.sh $(APP)

install:
	bash Scripts/install-to-applications.sh $(APP)

verify:
	bash Scripts/verify-signatures.sh $(APP)

register:
	bash Scripts/register-services.sh /Applications/MacRAR.app

test:
	cd Packages/RarKit && swift test
	# xcodebuild test -project $(PROJECT) -scheme $(SCHEME) (added once UI tests exist)

rarkit:
	cd Packages/RarKit && swift build

clean:
	rm -rf build/ DerivedData/ MacRAR.xcodeproj
	cd Packages/RarKit && swift package clean

all: project universal build sign verify
