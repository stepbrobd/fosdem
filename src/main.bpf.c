#include <vmlinux.h>

#include <bpf/bpf_core_read.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

SEC("ksyscall/statx")
int BPF_KSYSCALL(ksyscall_statx, int dirfd, const char *path, int flags,
                 unsigned int mask, struct statx *statxbuf) {
  return 0;
}

SEC("kretsyscall/statx")
int BPF_KRETPROBE(kretsyscall_statx, long ret) { return 0; }

char LICENSE[] SEC("license") = "GPL";
