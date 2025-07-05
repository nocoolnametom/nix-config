{ lib, config, ... }:
let
  jellyfinTubeDirectory = "/mnt/cirdan/smb/Jellyfin/TV_Shows/Tube";
  my = rec {
    base = "mybase";
    short_show = "My Short Term Show";
    short_collection = "My Short Collection";
    tv_show = "My TV Show";
    tv_show_recent = "${tv_show} Only Recent";
    tv_show_long_recent = "${tv_show} Long Recent";
    collection = "My TV Show Collection";
  };
  base_config = {
    presets.no_shorts.match_filters.filters = [ "original_url!*=/shorts/" ];
    presets.sponsorblock.chapters.sponsorblock_categories = [
      "outro"
      "selfpromo"
      "preview"
      "interaction"
      "sponsor"
      "music_offtopic"
      "intro"
    ];
    presets.sponsorblock.chapters.remove_sponsorblock_categories = "all";
    presets.sponsorblock.chapters.force_key_frames = false;
    presets.sponsorblock_wait.preset = [ "sponsorblock" ];
    presets.sponsorblock_wait.date_range.before = "today-2days";
    presets."${my.base}" = {
      preset = [ "no_shorts" ];
      embed_thumbnail = true;
      chapters.embed_chapters = true;
      subtitles.enable = true;
      subtitles.embed_subtitles = true;
      subtitles.allow_auto_generated_subtitles = true;
      date_range.breaks = false;
      ytdl_options = {
        break_on_existing = false;
        format = "bestvideo[vcodec=vp9][height<=2160]+bestaudio/bestvideo[vcodec=avc1][height<=2160]+bestaudio/best[height<=2160]";
      };
      output_options.output_directory = "{tv_show_directory}/{tv_show_genre}/{tv_show_name_sanitized}";
      overrides.tv_show_directory = jellyfinTubeDirectory;
      # @TODO I _think_ the following line isn't correct but isn't doing anything; see if we can delete it!
      overrides.output_options.output_directory = "{tv_show_directory}/{tv_show_genre}/{tv_show_name_sanitized}";
    };
    presets."${my.short_show}" = {
      overrides.only_recent_date_range = "2weeks";
      preset = [
        "Jellyfin TV Show by Date"
        "sponsorblock"
        my.base
      ];
    };
    presets."${my.short_collection}" = {
      overrides.only_recent_date_range = "2weeks";
      preset = [
        "Jellyfin TV Show Collection"
        "sponsorblock"
        my.base
      ];
    };
    presets."${my.tv_show}".preset = [
      "Jellyfin TV Show by Date"
      "sponsorblock_wait"
      my.base
    ];
    presets."${my.collection}".preset = [
      "Jellyfin TV Show Collection"
      "sponsorblock_wait"
      my.base
    ];
    presets."${my.tv_show_recent}" = {
      overrides.only_recent_date_range = "6months";
      preset = [
        "Jellyfin TV Show by Date"
        "sponsorblock_wait"
        my.base
        "Only Recent"
      ];
    };
    presets."${my.tv_show_long_recent}" = {
      overrides.only_recent_date_range = "12months";
      preset = [
        "Jellyfin TV Show by Date"
        "sponsorblock_wait"
        my.base
        "Only Recent"
      ];
    };
  };
in
{
  services.ytdl-sub.instances = {
    news = {
      enable = lib.mkDefault true;
      schedule = lib.mkDefault "daily"; # 12am
      config = lib.mkMerge [
        base_config
        { }
      ];
      subscriptions = {
        # Past 2 weeks
        "${my.short_show}" = {
          "= News | = TV-MA" = {
            "Some More News" = "https://www.youtube.com/playlist?list=PLkJemc4T5NYZpiVwtRDxXfZvcLzovtITo";
            "HasanAbi" = "https://www.youtube.com/playlist?list=PLxqasMrbxJeY_wS01sdAknM-b6tjDtvvd";
          };
          "= News | = TV-14" = {
            "Skepchick" = "https://www.youtube.com/channel/UCFJxE0l3cVYU4kHzi4qVEkw";
          };
          "= News | = TV-PG" = {
            "GenericArtDad" = "https://www.youtube.com/@genericartdad";
            "LegalEagle" = "https://www.youtube.com/@legaleagle";
            "Maklelan" = "https://www.youtube.com/@maklelan";
          };
        };
        # Past 2 weeks
        "${my.short_collection}" = {
          "= News | = TV-PG" = {
            "~TLDR News" = {
              s01_name = "Daily";
              s01_url = "https://www.youtube.com/@tldrdaily";
              s02_name = "Global";
              s02_url = "https://www.youtube.com/@TLDRnewsGLOBAL";
            };
          };
        };
      };
    };
    science = {
      enable = lib.mkDefault true;
      schedule = lib.mkDefault "01:00"; # 1am
      config = lib.mkMerge [
        base_config
        { }
      ];
      subscriptions = {
        "${my.tv_show}" = {
          "= Science | = TV-PG" = {
            "xkcd's What If?" = "https://www.youtube.com/@xkcd_whatif";
            "Kurzgesagt" = "https://www.youtube.com/@kurzgesagt";
          };
          "= Science | = TV-PG | Only Recent" = {
            "TED-Ed" = "https://www.youtube.com/playlist?list=PLJicmE8fK0EiEzttYMD1zYkT-SmNf323z";
          };
        };
        "${my.collection}" = {
          "= Science | = TV-PG" = {
            "~CGP Grey" = {
              s01_name = "Best Videos";
              s01_url = "https://www.youtube.com/playlist?list=PLqs5ohhass_STBfubAdle9dsyWrqu6G6r";
              s02_name = "Most Popular";
              s02_url = "https://www.youtube.com/playlist?list=PLqs5ohhass_RugObMuXClrZh7dP0g4e5l";
              s03_name = "Productivity";
              s03_url = "https://www.youtube.com/playlist?list=PLqs5ohhass_Qa4fHeDxUtJCsJiBwK5j5x";
            };
          };
        };
        # Past 12 months
        "${my.tv_show_long_recent}" = {
          "= Science | = TV-14" = {
            "Climate Town" = "https://www.youtube.com/@ClimateTown";
          };
          "= Science | = TV-PG" = {
            "PBS Terra: Weathered" = "https://www.youtube.com/playlist?list=PLnNZYWyBGJ1GLPmb55WQAln2Q7rZn5AFX";
            "Veritasium" = "https://www.youtube.com/@Veritasium";
            "PBS Space Time" = "https://www.youtube.com/@pbsspacetime";
            "Practical Engineering" = "https://www.youtube.com/@practicalengineering";
            "MinuteEarth" = "https://www.youtube.com/playlist?list=PLElB7nLNHZvhSor-RW0mv1FE_IDi9ZuiA";
            "minutephysics" = "https://www.youtube.com/playlist?list=PLED25F943F8D6081C";
          };
        };
      };
    };
    cartoons = {
      enable = lib.mkDefault true;
      schedule = lib.mkDefault "02:00"; # 2am
      config = lib.mkMerge [
        base_config
        { }
      ];
      subscriptions = {
        # Past 6 months
        "${my.tv_show_recent}" = {
          "= Cartoons | = TV-14" = {
            "CarbotAnimations" = "https://www.youtube.com/playlist?list=PL0QrZvg7QIgp2aJi4IIn8vfsTUFbLAgm-";
            "illymation" = "https://www.youtube.com/playlist?list=PL5KT1haMqErMH9NfVHluM1RWH9-OwYAa2";
          };
        };
        "${my.collection}" = {
          "= Cartoons | = TV-14" = {
            "~Glitch" = {
              s01_name = "The Amazing Digital Circus";
              s01_url = "https://www.youtube.com/playlist?list=PLHovnlOusNLgvAbnxluXCVB3KLj8e4QB-";
            };
          };
        };
      };
    };
    faux = {
      enable = lib.mkDefault true;
      schedule = lib.mkDefault "03:00"; # 3am
      config = lib.mkMerge [
        base_config
        { }
      ];
      subscriptions = {
        "${my.collection}" = {
          "= Faux | = TV-14" = {
            "~Mr. Beast" = {
              s01_name = "Most Popular";
              s01_url = "https://www.youtube.com/playlist?list=PLoSWVnSA9vG9hJNdgr-81MG59EYT9eEYn";
              s02_name = "$1 vs $$$";
              s02_url = "https://www.youtube.com/playlist?list=PLoSWVnSA9vG_PuIrGMfUtJ2wwKSUb2CFd";
              s03_name = "Stay to Win";
              s03_url = "https://www.youtube.com/playlist?list=PLoSWVnSA9vG8hI-SUpAimvYJrPh-PRRvp";
              s04_name = "7 Days";
              s04_url = "https://www.youtube.com/playlist?list=PLoSWVnSA9vG8SK6-_45PAu6RVTaP1zXHf";
              s05_name = "Philanthropy";
              s05_url = "https://www.youtube.com/playlist?list=PLoSWVnSA9vG_s-XT40oPKF0iWFGw8pOp2";
            };
          };
        };
      };
    };
    comedy = {
      enable = lib.mkDefault true;
      schedule = lib.mkDefault "03:00"; # 3am
      config = lib.mkMerge [
        base_config
        { }
      ];
      subscriptions = {
        "${my.collection}" = {
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
        };
      };
    };
  };
}
