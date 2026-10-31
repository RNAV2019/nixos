# OpenPencil's CLI and MCP server: `openpencil`, `openpencil-mcp` (stdio, for Claude Code)
# and `openpencil-mcp-http`, which the desktop app looks for on PATH and spawns as its
# automation bridge. To update, bump the version in package.json, then rerun
# `npm install --package-lock-only --ignore-scripts` and `prefetch-npm-deps package-lock.json`.
{buildNpmPackage}:
buildNpmPackage {
  pname = "openpencil-cli";
  version = "0.16.0";
  src = ./.;
  npmDepsHash = "sha256-2y9fJFsrlor8OLmSzOjLxVqb6ZNU1iB4eum+l0lamRs=";
  dontNpmBuild = true;
  npmFlags = ["--ignore-scripts"];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r node_modules $out/lib/
    for bin in openpencil openpencil-mcp openpencil-mcp-http; do
      ln -s $out/lib/node_modules/.bin/$bin $out/bin/$bin
    done
    runHook postInstall
  '';

  meta.mainProgram = "openpencil";
}
