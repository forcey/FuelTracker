PROJECT   := Fuel Tracker.xcodeproj
SCHEME    := Fuel Tracker
BUNDLE_ID := com.todd-li.Fuel-Tracker
APP       := build/Build/Products/Debug-iphoneos/Fuel Tracker.app
SIMULATOR ?= iPhone 16

# First connected iPhone. Override with: make deploy DEVICE=<udid>
DEVICE ?= $(shell xcrun devicectl list devices 2>/dev/null | grep connected | grep iPhone | \
	grep -oE '[0-9A-F]{8}-([0-9A-F]{16}|[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})' | head -1)

.PHONY: deploy build test devices clean check-device

## Build, install and launch on the connected iPhone
deploy: build
	xcrun devicectl device install app --device "$(DEVICE)" "$(APP)"
	xcrun devicectl device process launch --terminate-existing --device "$(DEVICE)" $(BUNDLE_ID)

## Build a signed app for the connected iPhone
build: check-device
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug \
		-destination "id=$(DEVICE)" -derivedDataPath build -allowProvisioningUpdates build

## Run unit and UI tests in the simulator
test:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination "platform=iOS Simulator,name=$(SIMULATOR)" test

## List connected devices
devices:
	xcrun devicectl list devices

clean:
	rm -rf build

check-device:
	@test -n "$(DEVICE)" || { echo "No connected iPhone found. Plug one in, or pass DEVICE=<udid>."; exit 1; }
