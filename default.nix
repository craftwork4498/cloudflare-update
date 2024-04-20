{ pkgs, ... }:
let
  script-name = "cloudflare-update";
  buildInputs = with pkgs; [ bash curl jq ];
  script = (pkgs.writeScriptBin script-name (builtins.readFile ./cloudflare-update.sh)).overrideAttrs (old: {
    buildCommand = "${old.buildCommand}\n patchShebangs $out";
  });
in
pkgs.symlinkJoin {
  name = script-name;
  paths = [ script ] ++ buildInputs;
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = "wrapProgram $out/bin/${script-name} --prefix PATH : $out/bin";
}

