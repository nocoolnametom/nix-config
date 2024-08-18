{ config, ... }:
{
  sops.secrets."deluge-auth" = { };
  # Deluge Server
  services.deluge.enable = true;
  services.deluge.declarative = false;
  services.deluge.config = {
    add_paused = false;
    allow_remote = false;
    auto_manage_prefer_seeds = false;
    auto_managed = true;
    cache_expiry = 60;
    cache_size = 512;
    copy_torrent_file = true;
    daemon_port = 58846;
    del_copy_torrent_file = false;
    dht = false;
    dont_count_slow_torrents = false;
    download_location = "/media/g_drive/Deluge/Downloads";
    download_location_paths_list = [ ];
    enabled_plugins = [ ];
    enc_in_policy = 1;
    enc_level = 2;
    enc_out_policy = 1;
    geoip_db_location = "/usr/share/GeoIP/GeoIP.dat";
    ignore_limits_on_local_network = true;
    info_sent = 0.0;
    listen_interface = "";
    listen_ports = [
      6881
      6891
    ];
    listen_random_port = 53484;
    listen_reuse_port = true;
    listen_use_sys_port = false;
    lsd = true;
    max_active_downloading = 5;
    max_active_limit = 10;
    max_active_seeding = 3;
    max_connections_global = 200;
    max_connections_per_second = 20;
    max_connections_per_torrent = -1;
    max_download_speed = -1.0;
    max_download_speed_per_torrent = -1;
    max_half_open_connections = 50;
    max_upload_slots_global = 4;
    max_upload_slots_per_torrent = -1;
    max_upload_speed = -1.0;
    max_upload_speed_per_torrent = -1;
    move_completed = true;
    move_completed_path = "/media/g_drive/Deluge/Finished";
    move_completed_paths_list = [ ];
    natpmp = true;
    new_release_check = false;
    outgoing_interface = "tun-protonvpn";
    outgoing_ports = [
      0
      0
    ];
    path_chooser_accelerator_string = "Tab";
    path_chooser_auto_complete_enabled = true;
    path_chooser_max_popup_rows = 20;
    path_chooser_show_chooser_button_on_localhost = true;
    path_chooser_show_hidden_files = false;
    peer_tos = "0x00";
    plugins_location = "/var/lib/deluge/.config/deluge/plugins";
    pre_allocate_storage = false;
    prioritize_first_last_pieces = false;
    queue_new_to_top = false;
    random_outgoing_ports = true;
    random_port = true;
    rate_limit_ip_overhead = true;
    remove_seed_at_ratio = false;
    seed_time_limit = 180;
    seed_time_ratio_limit = 7.0;
    send_info = false;
    sequential_download = false;
    share_ratio_limit = 2.0;
    shared = false;
    stop_seed_at_ratio = false;
    stop_seed_ratio = 2.0;
    super_seeding = false;
    torrentfiles_location = "/media/g_drive/Deluge/BlackHole";
    upnp = true;
    utpex = true;
  };
  services.deluge.authFile = config.sops.secrets."deluge-auth".path;

  # Deluge Web Server
  services.deluge.web.enable = true;
}
