PROJECT   := Fuel Tracker.xcodeproj
SCHEME    := Fuel Tracker
BUNDLE_ID := com.todd-li.Fuel-Tracker
APP       := build/Build/Products/Debug-iphoneos/Fuel Tracker.app
SIMULATOR ?= iPhone 16

# Pick the device kind with an extra goal: `make deploy iphone` or
# `make deploy ipad`. With neither, use an iPhone, or an iPad if there's no
# iPhone. A device counts if it's plugged in or paired over the network.
# Override with: make deploy DEVICE=<udid>
KIND      := $(firstword $(filter iphone ipad,$(MAKECMDGOALS)))
KIND_NAME := $(if $(filter iphone,$(KIND)),iPhone,$(if $(filter ipad,$(KIND)),iPad,iPhone or iPad))
UDID_RE   := [0-9A-F]{8}-([0-9A-F]{16}|[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})
DEVICE ?= $(shell xcrun devicectl list devices 2>/dev/null | \
	awk -v kind="$(KIND)" '/connected|available \(paired\)/ { \
	         if (/iPhone/ && !phone) phone = $$0; else if (/iPad/ && !pad) pad = $$0 } \
	     END { print (kind == "iphone" ? phone : kind == "ipad" ? pad : phone ? phone : pad) }' | \
	grep -oE '$(UDID_RE)')

.PHONY: deploy build test devices clean check-device iphone ipad

## Build, install and launch on the connected iPhone or iPad
deploy: build
	xcrun devicectl device install app --device "$(DEVICE)" "$(APP)"
	xcrun devicectl device process launch --terminate-existing --device "$(DEVICE)" $(BUNDLE_ID)

## Build a signed app for the connected iPhone or iPad
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
	@test -n "$(DEVICE)" || { echo "No $(KIND_NAME) found. Plug one in, or pass DEVICE=<udid>."; exit 1; }

# Only select the device kind for other goals; they do nothing on their own.
iphone ipad:
	@:
