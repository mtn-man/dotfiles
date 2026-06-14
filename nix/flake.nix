{
  description = "NixOS configuration — ThinkPad T14 Gen 1";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/thinkpad
        home-manager.nixosModules.home-manager
        {
          # useGlobalPkgs: HM modules use the system nixpkgs instance
          # useUserPackages: packages go into /etc/profiles/per-user rather than ~/.nix-profile
          home-manager.useGlobalPkgs    = true;
          home-manager.useUserPackages  = true;
          home-manager.users.eli        = import ./home;
        }
      ];
    };
  };
}
