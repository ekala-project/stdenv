{ lib, stdenv, fetchurl, m4, perl, texinfo }:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

stdenv.mkDerivation rec {
  pname = "autoconf";
  version = "2.72";
  outputs = [ "out" "doc" ];

  src = fetchurl {
    url = "mirror://gnu/autoconf/autoconf-${version}.tar.xz";
    hash = "sha256-uohcExlXjWyU1G6bDc60AUyq/iSQ5Deg28o/JwoiP1o=";
  };

  strictDeps = true;
  nativeBuildInputs = [ m4 perl texinfo ];
  buildInputs = [ m4 ];
  postBuild = "
    make html
  ";

  postInstall = "
    make install-html
  ";

  # Work around a known issue in Cygwin.  See
  # http://thread.gmane.org/gmane.comp.sysutils.autoconf.bugs/6822 for
  # details.
  # There are many test failures on `i386-pc-solaris2.11'.
  doCheck = ((!stdenv.isCygwin) && (!stdenv.isSunOS));

  # Don't fixup "#! /bin/sh" in Autoconf, otherwise it will use the
  # "fixed" path in generated files!
  dontPatchShebangs = true;

  enableParallelBuilding = true;

  # Make the Autotest test suite run in parallel.
  preCheck =''
    export TESTSUITEFLAGS="-j$NIX_BUILD_CORES"
  '';

  meta = {
    homepage = "https://www.gnu.org/software/autoconf/";
    description = "Part of the GNU Build System";

    longDescription = ''
      GNU Autoconf is an extensible package of M4 macros that produce
      shell scripts to automatically configure software source code
      packages.  These scripts can adapt the packages to many kinds of
      UNIX-like systems without manual user intervention.  Autoconf
      creates a configuration script for a package from a template
      file that lists the operating system features that the package
      can use, in the form of M4 macro calls.
    '';

    license = lib.licenses.gpl3Plus;

    platforms = lib.platforms.all;
  };
}

