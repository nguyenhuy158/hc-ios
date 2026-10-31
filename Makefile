SIM ?= iPhone 15
BUNDLE := dev.nguyenhuy158.hcios
DERIVED := build
APP := $(DERIVED)/Build/Products/Debug-iphonesimulator/HcIOS.app

.PHONY: project build test e2e sim shot shots pair clean

project:
	xcodegen generate

build: project
	xcodebuild -project HcIOS.xcodeproj -scheme HcIOS -configuration Debug \
		-destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DERIVED) -onlyUsePackageVersionsFromResolvedFile build

test: project
	xcodebuild -project HcIOS.xcodeproj -scheme HcIOS -configuration Debug \
		-destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DERIVED) -onlyUsePackageVersionsFromResolvedFile -only-testing:HcIOSTests test

e2e:
	sh scripts/e2e.sh

sim: build
	xcrun simctl boot '$(SIM)' 2>/dev/null || true
	open -a Simulator
	xcrun simctl install booted $(APP)
	xcrun simctl launch --terminate-running-process booted $(BUNDLE) $(ARGS)

shot:
	xcrun simctl io booted screenshot $(OUT)

shots: sim
	sh scripts/shots.sh $(OUT)

pair:
	python3 integrations/pair/hc-pair.py

clean:
	rm -rf $(DERIVED) HcIOS.xcodeproj
