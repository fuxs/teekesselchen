BUILD=teekesselchen.lrplugin
DIST=dist

$(BUILD):
	@mkdir $(BUILD)

.PHONY: build distribution

build: $(shell find src -type f) $(BUILD)
	cp -a src/* $(BUILD)
	cp -a 3rd/exiftool/* $(BUILD)

$(DIST):
	@mkdir $(DIST)

distribution: build $(DIST)
	zip -q -r $(DIST)/teekesselchen.zip $(BUILD)/*
	@shasum -a 256 $(DIST)/teekesselchen.zip | head -c 64 > $(DIST)/teekesselchen.zip.sha256