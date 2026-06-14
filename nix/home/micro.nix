{ ... }:

# micro has no home-manager module; configs are placed via xdg.configFile.

{
  xdg.configFile = {

    "micro/settings.json".text = builtins.toJSON {
      colorscheme           = "one-dark";
      autosave              = false;
      clipboard             = "external";
      autoreload            = true;
      scrollbar             = true;
      tabstospaces          = false;
      "lsp.server"          = "go=gopls,json=vscode-json-language-server --stdio,jsonc=vscode-json-language-server --stdio";
      "lsp.tabcompletion"   = true;
      "lsp.formatOnSave"    = false;
    };

    "micro/bindings.json".text = builtins.toJSON {
      "Alt-/"         = "lua:comment.comment";
      "CtrlUnderscore" = "lua:comment.comment";
      "Alt-s"         = "Save,Quit";
      "Alt-g"         = "command:term fish -c gcp";
      "Alt-t"         = "command:term fish -c 'go test ./...'";
      "Alt-l"         = "command:term fish -c 'golangci-lint run'";
      "Alt-c"         = "command:term fish -c 'staticcheck ./...'";
    };

    # JSONC syntax definition so micro highlights comments in JSON config files.
    "micro/syntax/jsonc.yaml".source = ./micro/jsonc.yaml;
  };
}
