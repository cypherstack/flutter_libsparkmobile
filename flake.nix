{
  description = "Reproducible native builds for flutter_libsparkmobile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    boost-171 = {
      url = "https://archives.boost.io/release/1.71.0/source/boost_1_71_0.tar.bz2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, boost-171 }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          flutter-libsparkmobile = pkgs.stdenv.mkDerivation {
            pname = "flutter-libsparkmobile";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [ cmake ninja perl pkg-config ];
            buildInputs = with pkgs; [ gmp ];

            env.SOURCE_DATE_EPOCH = "1";

            configurePhase = ''
              runHook preConfigure
              cp -r ${boost-171} boost-src
              chmod -R u+w boost-src
              cmake -S src -B build -G Ninja \
                -DBUILD_FOR_SYSTEM_NAME=linux \
                -DCMAKE_BUILD_TYPE=Release \
                -DFETCHCONTENT_SOURCE_DIR_BOOST="$PWD/boost-src" \
                -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG -g0 -ffile-prefix-map=/build/source=." \
                -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG -g0 -ffile-prefix-map=/build/source=." \
                -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--build-id=none"
              runHook postConfigure
            '';

            buildPhase = ''
              runHook preBuild
              cmake --build build --target flutter_libsparkmobile
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              library="$(find build -name libflutter_libsparkmobile.so -print -quit)"
              test -n "$library"
              install -Dm755 "$library" "$out/lib/libflutter_libsparkmobile.so"
              install -Dm644 src/flutter_libsparkmobile.h \
                "$out/include/flutter_libsparkmobile.h"
              runHook postInstall
            '';
          };

          default = self.packages.${system}.flutter-libsparkmobile;
        });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) flutter-libsparkmobile;
      });
    };
}
