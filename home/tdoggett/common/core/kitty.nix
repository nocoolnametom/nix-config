{
  programs.kitty = {
    enable = true;
    shellIntegration.enableBashIntegration = true;
    settings = { };
    #TODO I may be able to handle this with Stylix instead of explicitly!
    theme = "Molokai";
    font.name = "FiraCode";
    font.size = 12;
  };
}
