{ lib, ... }: 
let
  jellyfinTubeDirectory = "/mnt/cirdan/smb/Jellyfin/TV_Shows/Tube";
  newsDirectory = "${jellyfinTubeDirectory}/News";
  generalDirectory = "${jellyfinTubeDirectory}/General";
  documentatryDirectory = "${jellyfinTubeDirectory}/Documentaries";
  politicsDirectory = "${jellyfinTubeDirectory}/Politics";
  my = {
    base = "mybase";
    short_term = "My Short Terms";
    tv_show = "My TV Show";
    collection = "My TV Show Collection";
  };
in {
  services.ytdl-sub.instances.bert.enable = lib.mkDefault true;
  services.ytdl-sub.instances.bert.schedule = lib.mkDefault "daily";
  services.ytdl-sub.instances.bert.config.configuration.umask: "002";
  services.ytdl-sub.instances.bert.config.presets.no_shorts.match_filters.filters = [ "original_url!*=/shorts/" ];
  services.ytdl-sub.instances.bert.config.presets.sponsorblock.chapters.sponsorblock_categories = [
    "outro"
    "selfpromo"
    "preview"
    "interaction"
    "sponsor"
    "music_offtopic"
    "intro"
  ];
  services.ytdl-sub.instances.bert.config.presets.sponsorblock.chapters.remove_sponsorblock_categories = "all";
  services.ytdl-sub.instances.bert.config.presets.sponsorblock.chapters.force_key_frames = "False";
  services.ytdl-sub.instances.bert.config.presets.sponsorblock_wait.presets = [ "sponsorblock" ];
  services.ytdl-sub.instances.bert.config.presets.sponsorblock_wait.date_range.before = "today-2days";
  services.ytdl-sub.instances.bert.config.presets."${my.base}" = {
    preset = [ "no_shorts" ];
    embed_thumbnail = "True";
    chapters.embed_chapters = "True";
    subtitles.enable = "True";
    subtitles.embed_subtitles = "True";
    subtitles.allow_auto_generated_subtitles = "True";
    ytdl_options.format = "";
    overrides.tv_show_directory = generalDirectory;
  };
  services.ytdl-sub.instances.bert.config.presets."${my.short_term}" = {
    overrides.only_recent_date_range = "2weeks";
    presets = [
      "Jellyfin TV Show by Date"
      "sponsorblock"
      my.base
    ];
  };
  services.ytdl-sub.instances.bert.config.presets."${my.tv_show}" = {
    overrides.only_recent_date_range = "6months";
    preset = [
      "Jellyfin TV Show by Date"
      "sponsorblock_wait"
      my.base
    ];
  };
  services.ytdl-sub.instances.bert.config.presets."${my.collection}" = {
    only_recent_date_range = "1year";
    preset = [
      "Jellyfin TV Show Collection"
      "sponsorblock_wait"
      my.base
    ];
  };
  services.ytdl-sub.instances.bert.config.presets."YouTube Playlist" = {
    download = "{subscription_value}";
    output_options = {
      output_directory = "YouTube";
      file_name = "{channel}/{playlist_title}/{playlist_index_padded}_{title}.{ext}";
      maintain_download_archive = true;
    };
  };
  services.ytdl-sub.instances.bert.subscriptions = {
    # Only past two weeks if recent
    "${my.short_term}" = {
      "= News | = TV-MA | Only Recent" = {
        "~HasanAbi" = {
          s01_name = "HasanAbi";
          s01_url = "https://www.youtube.com/playlist?list=PLxqasMrbxJeY_wS01sdAknM-b6tjDtvvd";
          date_range = "2weeks";
        };
        "Some More News" = "https://www.youtube.com/playlist?list=PLkJemc4T5NYZpiVwtRDxXfZvcLzovtITo";
      };
      "= News | = TV-14 | Only Recent" = {
        "Skepchick" = "https://www.youtube.com/channel/UCFJxE0l3cVYU4kHzi4qVEkw";
      };
      "= News | = TV-PG | Only Recent" = {
        "~TLDR News" = {
          s01_name = "Daily";
          s01_url = "https://www.youtube.com/@tldrdaily";
          s02_name = "Global";
          s02_url = "https://www.youtube.com/@TLDRnewsGLOBAL";
        };
        "GenericArtDad" = "https://www.youtube.com/@genericartdad";
        "LegalEagle" = "https://www.youtube.com/@legaleagle";
        "Maklelan" = "https://www.youtube.com/@maklelan";
      };
    };
    # Only past six months if recent
    "${my.tv_show}" = {
      "= Science | = TV-PG" = {
        "xkcd's What If?" = "https://www.youtube.com/@xkcd_whatif";
        "Kurzgesagt" = "https://www.youtube.com/@kurzgesagt";
      };
      "= Science | = TV-PG | Only Recent" = {
        "TED-Ed" = "https://www.youtube.com/playlist?list=PLJicmE8fK0EiEzttYMD1zYkT-SmNf323z";
      };
      "= Cartoons | = TV-14 | Only Recent" = {
        "CarbotAnimations" = "https://www.youtube.com/playlist?list=PL0QrZvg7QIgp2aJi4IIn8vfsTUFbLAgm-";
        "illymation" = "https://www.youtube.com/playlist?list=PL5KT1haMqErMH9NfVHluM1RWH9-OwYAa2";
      };
    };
    # Only past year if recent
    "${my.collection}" = {
      "= Science | = TV-PG" = {
        "~CGP Grey" = {
          s01_name = "Best Videos";
          s01_url = "https://www.youtube.com/playlist?list=PLqs5ohhass_STBfubAdle9dsyWrqu6G6r";
          s02_name = "Most Popular";
          s02_name = "https://www.youtube.com/playlist?list=PLqs5ohhass_RugObMuXClrZh7dP0g4e5l";
          s03_url = "Productivity";
          s03_url = "https://www.youtube.com/playlist?list=PLqs5ohhass_Qa4fHeDxUtJCsJiBwK5j5x";
        };
      };
      "= Comedy | = TV-14" = {
        "~Comedians" = {
          s01_name = "ProZD Skits";
          s01_url = "https://www.youtube.com/playlist?list=PLhyHc3W8oSov-ucuA2YzzFMTJPZ6GNXJy";
          s02_name = "Randy Feltface Compilations";
          s02_url = "https://www.youtube.com/playlist?list=PLvy4k8z5JQrzTqmwzP_885Zc20YXeTWrv";
          s03_name = "Randy Feltface Full Specials";
          s03_url = "https://www.youtube.com/playlist?list=PLvy4k8z5JQrxw3C77tePfm0Ofk7Jp8wZN";
        };
      };
      "= Cartoons | = TV-14" = {
        "~Glitch" = {
          s01_name = "The Amazing Digital Circus";
          s01_url = "https://www.youtube.com/playlist?list=PLHovnlOusNLgvAbnxluXCVB3KLj8e4QB-";
        };
      };
      "= Science | = TV-PG | Only Recent" = {
        "PBS Terra: Weathered" = "https://www.youtube.com/playlist?list=PLnNZYWyBGJ1GLPmb55WQAln2Q7rZn5AFX";
        "Veritasium" = "https://www.youtube.com/@Veritasium";
        "PBS Space Time" = "https://www.youtube.com/@pbsspacetime";
        "Practical Engineering" = "https://www.youtube.com/@practicalengineering";
        "MinuteEarth" = "https://www.youtube.com/playlist?list=PLElB7nLNHZvhSor-RW0mv1FE_IDi9ZuiA";
        "minutephysics" = "https://www.youtube.com/playlist?list=PLED25F943F8D6081C";
      };
    };
  };
}
