```sh
nix profile install 'github:anakin4747r2d2/nixpkgs#vscode-bitbake'
```

## Test the VS Code extension

```sh
codium --extensions-dir $(nix build 'github:anakin4747r2d2/nixpkgs#vscode-bitbake' --no-link --print-out-paths)/share/vscode/extensions
```
