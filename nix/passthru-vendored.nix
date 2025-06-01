{

  # Add a passthru derivation to a Rust derivation `package` that generates a
  # CycloneDX SBOM.
  #
  # This could be done much more elegantly if `buildRustPackage` supported
  # finalAttrs. When https://github.com/NixOS/nixpkgs/pull/194475 lands, we can
  # most likely get rid of this.
  rust =
    package:
    {
      pkgs,
      includeBuildtimeDependencies ? false,
    }:
    package.overrideAttrs (previousAttrs: {
      passthru = (previousAttrs.passthru or { }) // {
        bombonVendoredSbom = package.overrideAttrs (previousAttrs: {
          pname = previousAttrs.pname + "-bombon-vendored-sbom";
          nativeBuildInputs = (previousAttrs.nativeBuildInputs or [ ]) ++ [
            pkgs.buildPackages.cargo-cyclonedx
          ];
          outputs = [ "out" ];
          phases = [
            "unpackPhase"
            "patchPhase"
            "configurePhase"
            "buildPhase"
            "installPhase"
          ];

          buildPhase =
            ''
              cargo cyclonedx \
                --spec-version 1.5 \
                --format json \
                --describe binaries \
                --target ${pkgs.stdenv.hostPlatform.rust.rustcTarget} \
            ''
            + pkgs.lib.optionalString (
              builtins.hasAttr "buildNoDefaultFeatures" previousAttrs && previousAttrs.buildNoDefaultFeatures
            ) " --no-default-features"
            + pkgs.lib.optionalString (
              builtins.hasAttr "buildFeatures" previousAttrs && builtins.length previousAttrs.buildFeatures > 0
            ) (" --features " + builtins.concatStringsSep "," previousAttrs.buildFeatures)
            + pkgs.lib.optionalString (!includeBuildtimeDependencies) " --no-build-deps";

          installPhase = ''
            mkdir -p $out

            # Collect all paths to executable files. Cargo has no good support to find this
            # and this method is very robust. The flipside is that we have to build the package
            # to generate a BOM for it.
            mapfile -d "" binaries < <(find ${package} -type f -executable -print0)

            for binary in "''${binaries[@]}"; do
              base=$(basename $binary)

              # Strip binary suffixes
              base=''${base%.exe}
              base=''${base%.efi}

              cdx=$(find . -name "''${base}_bin.cdx.json")

              if [ -f "$cdx" ]; then
                echo "Found SBOM for binary '$binary': $cdx"
                install -m444 "$cdx" $out/
              else
                echo "Failed to find SBOM for binary: $binary"
                exit 1
              fi
            done
          '';

          separateDebugInfo = false;
        });
      };
    });
}
