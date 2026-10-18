{
  description = "YukkuriMovieMaker4 を Linux + Wine で動かすための d2d1 / winex11 パッチ";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # ビルド済み成果物のキャッシュ (Cachix)。温まっていればビルドではなくダウンロードになる。
  # flake の nixConfig は accept-flake-config が無いと確認を求められるので、
  # 手元では併せて `cachix use ymm4-wine` を実行しておくとよい。
  nixConfig = {
    extra-substituters = [ "https://ymm4-wine.cachix.org" ];
    extra-trusted-public-keys = [
      "ymm4-wine.cachix.org-1:8z00/GI/7aQ8FYH72uQhxr0XaogjYZoX8e+DWeWiMPc="
    ];
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];

      eachSystem =
        f: nixpkgs.lib.genAttrs systems (system: f system (import nixpkgs { inherit system; }));
    in
    {
      # パッチを当てた Wine 本体。
      #   nix build                  -> ./result/bin/wine
      #   nix build .#wine           -> 同上
      # フルビルドなので初回は数十分かかる。d2d1.dll だけ差し替えたいときは
      # nix develop してから scripts/build-d2d1.sh を使うほうが速い。
      packages = eachSystem (
        system: pkgs:
        let
          wine = pkgs.callPackage ./nix/wine-ymm4.nix { };
        in
        {
          default = wine;
          inherit wine;
        }
      );

      # wine-11.20 のソースを .wine-src/ に展開し、ビルド依存を揃える。
      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.callPackage ./nix/devshell.nix {
            wine = self.packages.${system}.wine;
          };
        }
      );

      # パッチがまだ当たるかだけを検証する (フルビルド不要)。
      checks = eachSystem (
        system: pkgs: {
          patches-apply = pkgs.callPackage ./nix/patches-check.nix { };
        }
      );

      # NixOS の configuration.nix から使う場合:
      #   imports = [ inputs.wine-ymm4.overlays.default ];
      #   environment.systemPackages = [ pkgs.wine-ymm4 ];
      overlays.default = final: _prev: {
        wine-ymm4 = final.callPackage ./nix/wine-ymm4.nix { };
      };

      formatter = eachSystem (system: pkgs: pkgs.nixfmt);
    };
}
