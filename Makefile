.PHONY: build run image vm

include *.inc

all: build run

build:
	@echo "Building docker image..."
	docker build -t mikemackintosh/dashboard-bakery .

run:
	docker run --privileged \
		-v $$PWD:/pkgs \
		-it mikemackintosh/dashboard-bakery \
		make image

image:
	#./make_img.sh -t -b raspi2 -d 15.10
	./pibuilder.sh -v

vm:
	vagrant up --provider virtualbox
	vagrant ssh
