{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
  unzip,
  vscode-utils,
}:

let
  version = "2.9.0";

  vsixSrc = fetchurl {
    url = "https://github.com/yoctoproject/vscode-bitbake/releases/download/v${version}/yocto-bitbake-${version}.vsix";
    hash = "sha256-7Mawp+mEkjniQmKe1fZPcLibcZ6d9xIHJh243LIzU1w=";
  };

  serverTgz = fetchurl {
    url = "https://github.com/yoctoproject/vscode-bitbake/releases/download/v${version}/language-server-bitbake-${version}.tgz";
    hash = "sha256-pRPP3rDrEo5sh0tGmTh9BDcTK6QZTWK4en60Zb55+jU=";
  };

  # The standalone server tgz ships pre-compiled JS, wasm grammars, docs, and
  # SPDX data but no node_modules. The vsix includes server/node_modules so we
  # extract them from there and combine with the server tgz.
  languageServer = stdenvNoCC.mkDerivation {
    pname = "language-server-bitbake";
    inherit version;

    srcs = [ serverTgz vsixSrc ];
    sourceRoot = ".";

    nativeBuildInputs = [
      makeWrapper
      unzip
    ];

    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack

      # Unpack server tgz (extracts to package/)
      tar xf ${serverTgz}
      mv package server

      # Unpack vsix (it is a zip) to extract server/node_modules
      unzip -q ${vsixSrc} "extension/server/node_modules/*" -d vsix

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/language-server-bitbake $out/bin

      cp -r server/. $out/lib/language-server-bitbake/
      cp -r vsix/extension/server/node_modules $out/lib/language-server-bitbake/

      makeWrapper ${lib.getExe nodejs} $out/bin/language-server-bitbake \
        --add-flags "$out/lib/language-server-bitbake/out/server.js" \
        --set NODE_PATH "$out/lib/language-server-bitbake/node_modules"

      runHook postInstall
    '';

    meta = {
      description = "BitBake language server (standalone)";
      homepage = "https://github.com/yoctoproject/vscode-bitbake";
      license = lib.licenses.mit;
      mainProgram = "language-server-bitbake";
      platforms = lib.platforms.all;
    };
  };
in

vscode-utils.buildVscodeExtension {
  pname = "vscode-bitbake";
  inherit version;

  vscodeExtPublisher = "yocto-project";
  vscodeExtName = "yocto-bitbake";
  vscodeExtUniqueId = "yocto-project.yocto-bitbake";

  src = vsixSrc;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # Point the extension's server binary at our Nix-managed derivation.
    ln -sf ${languageServer}/bin/language-server-bitbake \
      "$out/$installPrefix/server/out/server.js"

    # Expose the language server binary on PATH.
    mkdir -p $out/bin
    ln -s ${languageServer}/bin/language-server-bitbake $out/bin/language-server-bitbake
  '';

  passthru = {
    inherit languageServer;
  };

  meta = {
    description = "Yocto Project BitBake language support for Visual Studio Code";
    homepage = "https://github.com/yoctoproject/vscode-bitbake";
    changelog = "https://github.com/yoctoproject/vscode-bitbake/releases/tag/v${version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
