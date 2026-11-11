.PHONY: help macos-build macos-app macos-install macos-run macos-dmg macos-test clean

help:
	@echo "AULA F75 Studio (macOS Driver)"
	@echo ""
	@echo "Targets:"
	@echo "  make macos-build    Build release binary (Swift 6 / AppKit + SwiftUI)"
	@echo "  make macos-app      Package 'build/Aula F75 Driver.app'"
	@echo "  make macos-install  Clean-install into /Applications without duplicates"
	@echo "  make macos-run      Clean-install and launch '/Applications/Aula F75 Driver.app'"
	@echo "  make macos-dmg      Create distributable 'build/Aula-F75-Driver-macOS.dmg'"
	@echo "  make macos-test     Run AulaCore unit tests"
	@echo "  make clean          Remove build artifacts"

macos-build:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-build.sh

macos-app:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-app.sh

macos-install: macos-app
	@rm -rf "/Applications/Aula F75 Driver.app"
	@cp -R "build/Aula F75 Driver.app" "/Applications/Aula F75 Driver.app"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$(CURDIR)/build/Aula F75 Driver.app" 2>/dev/null || true
	@rm -rf "build/Aula F75 Driver.app"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Aula F75 Driver.app"

macos-run: macos-install
	@open "/Applications/Aula F75 Driver.app"

macos-dmg:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-dmg.sh

macos-test:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-app.sh
	@"./build/Aula F75 Driver.app/Contents/MacOS/AulaF75Driver" --self-test

clean:
	rm -rf .build build
