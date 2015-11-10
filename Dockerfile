FROM ubuntu:latest
MAINTAINER Mike Mackintosh <mike@signalsciences.com>

RUN   apt-get update
RUN   apt-get install -y build-essential
RUN   apt-get install -y git
RUN   apt-get install -y debootstrap
RUN   apt-get install -y qemu-user-static
RUN   apt-get install -y kpartx
RUN   apt-get install -y whois
RUN   apt-get install -y dosfstools
#RUN   apt-get install -y tmux
RUN   apt-get install -y wget
#RUN   apt-get install -y ntp
RUN   apt-get install -y binfmt-support
#RUN   apt-get install -y qemu qemu-user-static
#RUN   apt-get install -y lvm2
RUN   apt-get install -y apt-cacher-ng
RUN   apt-get install -y unzip
#RUN   apt-get install -y vmdebootstrap

RUN   mkdir             /build
COPY  Makefile*         /build/
COPY  pibuilder.sh      /build/
COPY  firmware/         /build/firmware/
COPY  skel/             /build/skel/
COPY  firmware-master/  /build/firmware-master/

RUN   chmod +x /build/pibuilder.sh

WORKDIR /build/

CMD ["make"]
