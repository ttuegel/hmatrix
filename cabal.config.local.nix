let
  nixpkgs = import ./nixpkgs {};
  config = import ./cabal-config-nix/cabal.config.nix { inherit nixpkgs; };
in
  config {
    inputs = pkgs: with pkgs; [ openblasCompat ];
  }
