{ lib, pkgs, ... }:
{
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.initrd.supportedFilesystems.zfs = lib.mkForce false;

  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.linuxKernel.kernels.linux_latest.override {
      structuredExtraConfig = with lib.kernel; {
        BPF = lib.mkForce yes;
        BPF_SYSCALL = lib.mkForce yes;
        BPF_JIT = lib.mkForce yes;
        BPF_JIT_ALWAYS_ON = lib.mkForce yes;
        BPF_JIT_DEFAULT_ON = lib.mkForce yes;
        BPF_KPROBE_OVERRIDE = lib.mkForce yes;
        FUNCTION_ERROR_INJECTION = lib.mkForce yes;
      };
    }
  );
}
