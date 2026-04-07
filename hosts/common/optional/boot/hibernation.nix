{ ... }:
{
  # suspend to RAW (deep) rather than `s2idle`
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  # suspend-then-hibernate
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "30m";
    SuspendState = "mem";
  };
}
