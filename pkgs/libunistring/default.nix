{
  fetchurl,
  lib,
  stdenv,
  libiconv ? null,
  updateAutotoolsGnuConfigScriptsHook,
  darwin ? null
}:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

stdenv.mkDerivation (finalAttrs: {
  pname = "libunistring";
  version = "1.2";

  src = fetchurl {
    url = "mirror://gnu/libunistring/libunistring-${finalAttrs.version}.tar.gz";
    hash = "sha256-/W1WYvpwZIfEg0mnWLV7wUnOlOxsMGJOyf3Ec86rvI4=";
  };

  outputs = [
    "out"
    "dev"
    "info"
    "doc"
  ];

  strictDeps = true;
  propagatedBuildInputs = lib.optional (!stdenv.isLinux) libiconv;
  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.CoreServices
  ];
  nativeBuildInputs = [ updateAutotoolsGnuConfigScriptsHook ];

  configureFlags = lib.optional (!stdenv.isLinux) "--with-libiconv-prefix=${libiconv}";

  doCheck = false;

  /*
    This seems to cause several random failures like these, which I assume
    is because of bad or missing target dependencies in their build system:

      ./unistdio/test-u16-vasnprintf2.sh: line 16: ./test-u16-vasnprintf1: No such file or directory
      FAIL unistdio/test-u16-vasnprintf2.sh (exit status: 1)

      FAIL: unistdio/test-u16-vasnprintf3.sh
      ======================================

      ./unistdio/test-u16-vasnprintf3.sh: line 16: ./test-u16-vasnprintf1: No such file or directory
      FAIL unistdio/test-u16-vasnprintf3.sh (exit status: 1)
  */
  enableParallelChecking = false;
  enableParallelBuilding = true;

  meta = {
    homepage = "https://www.gnu.org/software/libunistring/";

    description = "Unicode string library";

    longDescription = ''
      This library provides functions for manipulating Unicode strings
      and for manipulating C strings according to the Unicode
      standard.

      GNU libunistring is for you if your application involves
      non-trivial text processing, such as upper/lower case
      conversions, line breaking, operations on words, or more
      advanced analysis of text.  Text provided by the user can, in
      general, contain characters of all kinds of scripts.  The text
      processing functions provided by this library handle all scripts
      and all languages.

      libunistring is for you if your application already uses the ISO
      C / POSIX <ctype.h>, <wctype.h> functions and the text it
      operates on is provided by the user and can be in any language.

      libunistring is also for you if your application uses Unicode
      strings as internal in-memory representation.
    '';

    license = lib.licenses.lgpl3Plus;

    maintainers = [ ];
    platforms = lib.platforms.all;
  };
})
