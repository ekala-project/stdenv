{ lib, stdenv
, fetchurl
, shared ? !stdenv.hostPlatform.isStatic
, static ? true
# If true, a separate .static ouput is created and the .a is moved there.
# In this case `pkg-config` auto detection does not currently work if the
# .static output is given as `buildInputs` to another package (#66461), because
# the `.pc` file lists only the main output's lib dir.
# If false, and if `{ static = true; }`, the .a stays in the main output.
, splitStaticOutput ? shared && static
, testers ? null
, minizip ? null
}:

# Without either the build will actually still succeed because the build
# system makes an arbitrary choice, but we shouldn't be so indecisive.
assert shared || static;

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

assert splitStaticOutput -> static;

stdenv.mkDerivation (finalAttrs: {
  pname = "zlib";
  version = "1.3.1";

  src = let
    inherit (finalAttrs) version;
  in fetchurl {
    urls = [
      # This URL works for 1.2.13 only; hopefully also for future releases.
      "https://github.com/madler/zlib/releases/download/v${version}/zlib-${version}.tar.gz"
      # Stable archive path, but captcha can be encountered, causing hash mismatch.
      "https://www.zlib.net/fossils/zlib-${version}.tar.gz"
    ];
    hash = "sha256-mpOyt9/ax3zrpaVYpYDnRmfdb+3kWFuR7vtg8Dty3yM=";
  };

  postPatch = lib.optionalString stdenv.hostPlatform.isDarwin ''
    substituteInPlace configure \
      --replace '/usr/bin/libtool' '${stdenv.cc.targetPrefix}ar' \
      --replace 'AR="libtool"' 'AR="${stdenv.cc.targetPrefix}ar"' \
      --replace 'ARFLAGS="-o"' 'ARFLAGS="-r"'
  '';

  strictDeps = true;
  outputs = [ "out" "dev" ]
    ++ lib.optional splitStaticOutput "static";
  setOutputFlags = false;
  outputDoc = "dev"; # single tiny man3 page

  dontConfigure = stdenv.hostPlatform.isMinGW;

  preConfigure = lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    export CHOST=${stdenv.hostPlatform.config}
  '';

  # For zlib's ./configure (as of version 1.2.11), the order
  # of --static/--shared flags matters!
  # `--shared --static` builds only static libs, while
  # `--static --shared` builds both.
  # So we use the latter order to be able to build both.
  # Also, giving just `--shared` builds both,
  # giving just `--static` builds only static,
  # and giving nothing builds both.
  # So we have 3 possible ways to build both:
  # `--static --shared`, `--shared` and giving nothing.
  # Of these, we choose `--static --shared`, for clarity and simpler
  # conditions.
  configureFlags = lib.optional static "--static"
                   ++ lib.optional shared "--shared";
  # We do the right thing manually, above, so don't need these.
  dontDisableStatic = true;
  dontAddStaticConfigureFlags = true;

  # Note we don't need to set `dontDisableStatic`, because static-disabling
  # works by grepping for `enable-static` in the `./configure` script
  # (see `pkgs/stdenv/generic/setup.sh`), and zlib's handwritten one does
  # not have such.
  # It wouldn't hurt setting `dontDisableStatic = static && !splitStaticOutput`
  # here (in case zlib ever switches to autoconf in the future),
  # but we don't do it simply to avoid mass rebuilds.

  postInstall = lib.optionalString splitStaticOutput ''
    moveToOutput lib/libz.a "$static"
  ''
    # jww (2015-01-06): Sometimes this library install as a .so, even on
    # Darwin; others time it installs as a .dylib.  I haven't yet figured out
    # what causes this difference.
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    for file in $out/lib/*.so* $out/lib/*.dylib* ; do
      ${stdenv.cc.bintools.targetPrefix}install_name_tool -id "$file" $file
    done
  ''
    # Non-typical naming confuses libtool which then refuses to use zlib's DLL
    # in some cases, e.g. when compiling libpng.
  + lib.optionalString (stdenv.hostPlatform.isMinGW && shared) ''
    ln -s zlib1.dll $out/bin/libz.dll
  '';

  env = lib.optionalAttrs (!stdenv.hostPlatform.isDarwin) {
    # As zlib takes part in the stdenv building, we don't want references
    # to the bootstrap-tools libgcc (as uses to happen on arm/mips)
    NIX_CFLAGS_COMPILE = "-static-libgcc";
  } // lib.optionalAttrs (stdenv.hostPlatform.linker == "lld") {
    # lld 16 enables --no-undefined-version by defualt
    # This makes configure think it can't build dynamic libraries
    # this may be removed when a version is packaged with https://github.com/madler/zlib/issues/960 fixed
    NIX_LDFLAGS = "--undefined-version";
  };

  # We don't strip on static cross-compilation because of reports that native
  # stripping corrupted the target library; see commit 12e960f5 for the report.
  dontStrip = stdenv.hostPlatform != stdenv.buildPlatform && static;
  configurePlatforms = [];

  installFlags = lib.optionals stdenv.hostPlatform.isMinGW [
    "BINARY_PATH=$(out)/bin"
    "INCLUDE_PATH=$(dev)/include"
    "LIBRARY_PATH=$(out)/lib"
  ];

  enableParallelBuilding = true;
  doCheck = true;

  makeFlags = [
    "PREFIX=${stdenv.cc.targetPrefix}"
  ] ++ lib.optionals stdenv.hostPlatform.isMinGW [
    "-f" "win32/Makefile.gcc"
  ] ++ lib.optionals shared [
    # Note that as of writing (zlib 1.2.11), this flag only has an effect
    # for Windows as it is specific to `win32/Makefile.gcc`.
    "SHARED_MODE=1"
  ];

  passthru.tests = {
    pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
    # uses `zlib` derivation:
    inherit minizip;
  };

  meta = with lib; {
    homepage = "https://zlib.net";
    description = "Lossless data-compression library";
    license = licenses.zlib;
    platforms = platforms.all;
    pkgConfigModules = [ "zlib" ];
  };
})
