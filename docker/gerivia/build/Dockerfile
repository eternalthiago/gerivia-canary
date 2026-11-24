# syntax=docker/dockerfile:1.7
# Gerivia: compila o Canary desta branch sem o cache NuGet do upstream (que exige token).
# As dependências do vcpkg são compiladas do zero na primeira vez (demora) e ficam em cache.
#   docker build -f docker/gerivia/build/Dockerfile -t gerivia-canary:build .
FROM ubuntu:24.04 AS build
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
	apt-get update && apt-get install -y --no-install-recommends cmake git \
	unzip build-essential ca-certificates curl zip tar pkg-config ninja-build \
	autoconf automake autoconf-archive libtool python3 tzdata linux-libc-dev
WORKDIR /opt
COPY vcpkg.json /opt/
RUN vcpkgCommitId=$(grep '.builtin-baseline' vcpkg.json | awk -F: '{print $2}' | tr -d '," ' | tr -d '\r\n') \
	&& git clone https://github.com/microsoft/vcpkg.git && cd vcpkg \
	&& git checkout "$vcpkgCommitId" && ./bootstrap-vcpkg.sh -disableMetrics
WORKDIR /opt/vcpkg_manifest
COPY vcpkg.json vcpkg-configuration.json /opt/vcpkg_manifest/
COPY vcpkg-registry /opt/vcpkg_manifest/vcpkg-registry
COPY cmake/triplets /opt/vcpkg_manifest/cmake/triplets
RUN --mount=type=cache,target=/opt/vcpkg/downloads \
	--mount=type=cache,target=/root/.cache/vcpkg \
	/opt/vcpkg/vcpkg install --x-manifest-root=/opt/vcpkg_manifest --x-install-root=/opt/vcpkg_installed \
	--triplet=x64-linux --host-triplet=x64-linux --clean-after-build
COPY CMakeLists.txt CMakePresets.json /srv/
COPY cmake /srv/cmake
COPY src /srv/src
COPY tests /srv/tests
COPY vcpkg.json vcpkg-configuration.json /srv/
WORKDIR /srv
RUN --mount=type=cache,target=/srv/build \
	export VCPKG_ROOT=/opt/vcpkg/ \
	&& cmake --preset linux-release -DTOGGLE_BIN_FOLDER=ON -DVCPKG_MANIFEST_INSTALL=OFF -DVCPKG_INSTALLED_DIR=/opt/vcpkg_installed \
	&& cmake --build --preset linux-release -j"$(nproc)" \
	&& cp build/linux-release/bin/canary /canary-bin

# Runtime: mesmo formato da imagem publicada (start.sh baixa o mapa e configura o banco)
FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
VOLUME [ "/data" ]
RUN apt-get update && apt-get install -y --no-install-recommends mariadb-client curl ca-certificates tzdata \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=build /canary-bin /bin/canary
WORKDIR /canary
COPY LICENSE *.sql key.pem /canary/
COPY data /canary/data
COPY data-canary /canary/data-canary
COPY data-otservbr-global /canary/data-otservbr-global
COPY config.lua.dist /canary/config.lua
COPY docker/data/01-test_account.sql docker/data/02-test_account_players.sql /canary/
COPY --chmod=755 docker/data/start.sh /canary/start.sh
ENTRYPOINT ["/canary/start.sh"]
