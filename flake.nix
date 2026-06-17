{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            # Terraform uses the Business Source License 1.1, which is not free; permit it.
            allowlistedLicenses = [ nixpkgs.lib.licenses.bsl11 ];
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            awscli2
            kubectl
            terraform
            terraform-docs
          ];
        };
      });
}
