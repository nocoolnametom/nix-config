{
  config,
  configVars,
  lib,
  pkgs,
  outputs,
  configLib,
  ...
}:
{
  imports = (configLib.scanPaths ./.) ++ (builtins.attrValues outputs.homeModules);

  home = {
    username = lib.mkDefault configVars.username;
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "25.05";
    sessionPath = [
      # Add to the user's $PATH
      # "$HOME/.local/bin"
    ];
    sessionVariables = {
      TERM = "kitty";
      TERMINAL = "kitty";
      EDITOR = "nvim";
    };
  };

  home.packages = builtins.attrValues {
    inherit (pkgs)

      # Packages that don't have custom configs go here
      sops # secrets encryption
      coreutils # basic gnu utils
      nix-tree # nix package tree viewer
      pciutils
      p7zip # compression & encryption
      ripgrep # better grep
      tree # cli dir tree viewer
      unzip # zip extraction
      unrar # rar extraction
      wget # downloader
      zip # zip compression
      gnumake # make
      ;
  };

  # Claude Code AI helper
  programs.claude-code.enable = lib.mkDefault true;
  programs.claude-code.package = lib.mkDefault pkgs.claude-code;

  # JSON pretty printer and manipulator
  programs.jq.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    plugins = with pkgs.vimPlugins; [
      nvim-cmp
      cmp-nvim-lsp
      cmp-path
      nvim-lspconfig
      conform-nvim
      vim-terraform
      vim-nix
      vim-fugitive
      gitsigns-nvim
      diffview-nvim
      jj-nvim
      vim-markdown
      direnv-vim
      trouble-nvim
      copilot-vim
      neo-tree-nvim
      plenary-nvim
      nvim-web-devicons
      nui-nvim
    ];

    extraPackages = with pkgs; [
      intelephense
      typescript
      typescript-language-server
      nixd
      terraform-ls
      yaml-language-server
      marksman
      prettier
      markdownlint-cli
    ];

    initLua = ''
      vim.opt.number = true

      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<C-J>", 'copilot#Accept("<CR>")', { expr = true, replace_keycodes = false })

      local cmp = require("cmp")
      cmp.setup({
        sources = {
          { name = "nvim_lsp" },
          { name = "path" },
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
      })

      require("conform").setup({
        formatters_by_ft = {
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          json = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
        },
        -- Disable format on save for now, since it can be a bit disruptive
        format_on_save = false,
      })

      require("gitsigns").setup({})
      require("trouble").setup({})
      require("neo-tree").setup({})
      vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { silent = true })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local intelephense_settings = {}
      for _, license_file in ipairs({ "~/.intelephense/license.txt", "~/.intelephense/licence.txt" }) do
        local expanded = vim.fn.expand(license_file)
        if vim.fn.filereadable(expanded) == 1 then
          intelephense_settings = {
            intelephense = {
              licenceKey = table.concat(vim.fn.readfile(expanded), "\n"),
            },
          }
          break
        end
      end

      local function configure_and_enable(server, config)
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end

      local ts_enabled = false
      for _, server in ipairs({ "ts_ls", "tsserver" }) do
        if not ts_enabled then
          ts_enabled = pcall(configure_and_enable, server, { capabilities = capabilities })
        end
      end

      configure_and_enable("intelephense", {
        capabilities = capabilities,
        settings = intelephense_settings,
      })
      configure_and_enable("nixd", { capabilities = capabilities })
      configure_and_enable("terraformls", { capabilities = capabilities })
      configure_and_enable("yamlls", { capabilities = capabilities })
      configure_and_enable("marksman", { capabilities = capabilities })
    '';
  };

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  # shell aliases for interactive shells (available via Home Manager)
  programs.bash.initExtra = lib.mkDefault ''
    # Provide ag alias that uses rg so my finger memory continues to work
    alias ag='rg --smart-case'
  '';
  programs.zsh.shellAliases.ag = "rg --smart-case";

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  programs = {
    home-manager.enable = true;
  };

  # Disabling manpage generation avoids a Nix warning about builtins.derivation
  # creating an 'options.json' file that references store paths without proper
  # context (upstream home-manager issue).
  manual.manpages.enable = false;
}
