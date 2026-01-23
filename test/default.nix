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

    collector.wait_for_unit("grafana.service")
    collector.succeed("curl http://exporter/prometheus/metrics")
    collector.succeed("curl http://exporter/loki/metrics")
  '';
}
