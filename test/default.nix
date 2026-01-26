{
  name = "fosdem-nixos-vm-test";

  interactive.sshBackdoor.enable = true;
  interactive.nodes.exporter.imports = [ ./kernel.nix ];

  nodes.collector.imports = [ ./collector.nix ];

  nodes.exporter.imports = [
    ./kernel.nix
    ./exporter.nix
  ];

  # only meant for interactive driver
  testScript = ''
    start_all()

    exporter.succeed("zcat /proc/config.gz | grep CONFIG_BPF_KPROBE_OVERRIDE=y")
    exporter.succeed("zcat /proc/config.gz | grep CONFIG_FUNCTION_ERROR_INJECTION=y")
    exporter.wait_for_unit("prometheus-ebpf-exporter.service")
    exporter.wait_for_unit("prometheus.service")
    exporter.wait_for_unit("caddy.service")

    collector.wait_for_unit("grafana.service")
    collector.succeed("curl -i http://exporter/prometheus/metrics")
    collector.succeed("curl -i http://exporter/loki/metrics")

    exporter.succeed("touch /tmp/override")
    exporter.succeed("stat /tmp/override | grep '00:00:00.000000000 +0000'")

    exporter.wait_until_succeeds("systemctl stop prometheus-ebpf-exporter.service")
    exporter.succeed("stat /tmp/override | grep $(date -u +%F)")
  '';
}
