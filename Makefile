VERSION = $$(git describe --abbrev=0 --tags)
VERSION_DATE = $$(git log -1 --pretty='%ad' --date=format:'%Y-%m-%d' $(VERSION))
COMMIT_REV = $$(git rev-list -n 1 $(VERSION))

all: build

version:
	@echo $(VERSION)

commit_rev:
	@echo $(COMMIT_REV)

start:
	go run main.go

deps/clean:
	go clean -modcache
	rm -rf vendor

deps/download:
	GO111MODULE=on go mod download
	GO111MODULE=on go mod vendor

deps: deps/clean deps/download
vendor: deps

debug:
	DEBUG=1 go run main.go

build:
	@go build -o bin/coind main.go

# http://macappstore.org/upx
build/mac: clean/mac
	env GOARCH=amd64 go build -ldflags "-s -w" -o bin/macos/coind && upx bin/macos/coind

build/linux: clean/linux
	env GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o bin/linux/coind && upx bin/linux/coind

build/multiple: clean
	env GOARCH=amd64 go build -ldflags "-s -w" -o bin/coind64 && upx bin/coind64 && \
	env GOARCH=386 go build -ldflags "-s -w" -o bin/coind32 && upx bin/coind32

clean/mac:
	go clean && \
	rm -rf bin/mac

clean/linux:
	go clean && \
	rm -rf bin/linux

clean:
	go clean && \
	rm -rf bin/

test:
	go test ./...

coind/test:
	go run main.go -test

coind/version:
	go run main.go -version

coind/clean:
	go run main.go -clean

coind/reset:
	go run main.go -reset

snap/clean:
	snapcraft clean
	rm -f coind_*.snap

snap/stage:
	# https://github.com/elopio/go/issues/2
	mv go.mod go.mod~ ;GO111MODULE=off snapcraft stage; mv go.mod~ go.mod

snap/install:
	sudo apt install snapd
	sudo snap install snapcraft --classic

snap/build: snap/clean snap/stage
	snapcraft snap

snap/deploy:
	snapcraft push coind_*.snap --release stable

snap/remove:
	snap remove coind

snap/build-and-deploy: snap/build snap/deploy snap/clean
	@echo "done"

snap: snap/build-and-deploy

flatpak/build:
	flatpak-builder --force-clean build-dir com.github.cdyfng.Coind.json

flatpak/run/test:
	flatpak-builder --run build-dir com.github.cdyfng.coind.json coind

flatpak/repo:
	flatpak-builder --repo=repo --force-clean build-dir com.github.cdyfng.Coind.json

flatpak/add:
	flatpak --user remote-add --no-gpg-verify coind-repo repo

flatpak/remove:
	flatpak --user remote-delete coind-repo

flatpak/install:
	flatpak --user install coind-repo com.github.cdyfng.Coind

flatpak/run:
	flatpak run com.github.cdyfng.Coind

flatpak/update-version:
	xmlstarlet ed --inplace -u '/component/releases/release/@version' -v $(VERSION) .flathub/com.github.cdyfng.Coind.appdata.xml
	xmlstarlet ed --inplace -u '/component/releases/release/@date' -v $(VERSION_DATE) .flathub/com.github.cdyfng.Coind.appdata.xml

rpm/install/deps:
	sudo dnf install -y rpm-build
	sudo dnf install -y dnf-plugins-core

rpm/cp/specs:
	cp .rpm/coind.spec ~/rpmbuild/SPECS/

rpm/build:
	rpmbuild -ba ~/rpmbuild/SPECS/coind.spec

rpm/lint:
	rpmlint ~/rpmbuild/SPECS/coind.spec

rpm/dirs:
	mkdir -p ~/rpmbuild
	mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	chmod -R a+rwx ~/rpmbuild

rpm/download:
	wget https://github.com/cdyfng/coind/archive/$(VERSION).tar.gz -O ~/rpmbuild/SOURCES/$(VERSION).tar.gz

copr/install/cli:
	sudo dnf install -y copr-cli

copr/create-project:
	copr-cli create coind --chroot fedora-rawhide-x86_64

copr/build:
	copr-cli build coind ~/rpmbuild/SRPMS/coind-*.rpm
	rm -rf ~/rpmbuild/SRPMS/coind-*.rpm

copr/deploy: rpm/dirs rpm/cp/specs rpm/download rpm/build copr/build

brew/clean: brew/remove
	brew cleanup --force coind
	brew prune

brew/remove:
	brew uninstall --force coind

brew/build: brew/remove
	brew install --build-from-source coind.rb

brew/audit:
	brew audit --strict coind.rb

brew/test:
	brew test coind.rb

brew/tap:
	brew tap coind/coind https://github.com/cdyfng/coind

brew/untap:
	brew untap coind/coind

git/rm/large:
	java -jar bfg.jar --strip-blobs-bigger-than 200K .

git/repack:
	git reflog expire --expire=now --all
	git fsck --full --unreachable
	git repack -A -d
	git gc --aggressive --prune=now

release:
	rm -rf dist
	VERSION=$(VERSION) goreleaser
