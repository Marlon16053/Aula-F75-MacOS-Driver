.PHONY: help macos-build macos-app macos-run macos-dmg macos-test clean

help:
	@echo "AULA F75 Studio (macOS Driver)"
	@echo ""
	@echo "Targets:"
	@echo "  make macos-build   Build release binary (Swift 6 / AppKit + SwiftUI)"
	@echo "  make macos-app     Package 'build/Aula F75 Driver.app'"
	@echo "  make macos-run     Build and launch 'Aula F75 Driver.app'"
	@echo "  make macos-dmg     Create distributable 'build/Aula-F75-Driver-macOS.dmg'"
	@echo "  make macos-test    Run AulaCore unit tests"
	@echo "  make clean         Remove build artifacts"

macos-build:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-build.sh

macos-app:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-app.sh

macos-run:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-run.sh

macos-dmg:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-dmg.sh

macos-test:
	@chmod +x scripts/macos/*.sh
	@./scripts/macos/macos-app.sh
	@"./build/Aula F75 Driver.app/Contents/MacOS/AulaF75Driver" --self-test

clean:
	rm -rf .build build
