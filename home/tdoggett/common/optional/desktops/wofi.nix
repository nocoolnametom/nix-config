{
  programs.wofi = {
    settings = {
      location = "bottom-right";
      allow_markup = true;
      width = 250;
    };
    style = ''
      * {
        font-family: monospace;
      }

      window {
        background-color: #7c818c;
      }
    '';
  };
}
