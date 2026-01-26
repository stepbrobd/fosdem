#include <vmlinux.h>

#include <bpf/bpf_core_read.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#include <helper/maps.bpf.h>

#ifndef S_IFREG
#define S_IFREG 0100000
#endif
#ifndef STATX_BASIC_STATS
#define STATX_BASIC_STATS 0x000007ffU
#endif

#define FSD_MAX_SLOTS 27
#define FSD_TARGET_PATH "/tmp/override"

struct fsd_statx_key {
  u64 bucket;
};

struct fsd_statx_entry {
  u64 start;
  struct statx *statxbuf;
};

// tracking
struct {
  __uint(type, BPF_MAP_TYPE_HASH);
  __uint(max_entries, 10240);
  __type(key, u64); // pid_tgid
  __type(value, struct fsd_statx_entry);
} fsd_statx_pending SEC(".maps");

// histogram
struct {
  __uint(type, BPF_MAP_TYPE_HASH);
  __uint(max_entries, FSD_MAX_SLOTS + 1);
  __type(key, struct fsd_statx_key);
  __type(value, u64);
} fsd_statx_latency SEC(".maps");

SEC("ksyscall/statx")
int BPF_KSYSCALL(fsd_statx_entry, int dirfd, const char *path, int flags,
                 unsigned int mask, struct statx *statxbuf) {
  u64 tid = bpf_get_current_pid_tgid();
  struct fsd_statx_entry entry = {
      .start = bpf_ktime_get_ns(),
      .statxbuf = statxbuf,
  };
  bpf_map_update_elem(&fsd_statx_pending, &tid, &entry, BPF_ANY);

  char target[] = FSD_TARGET_PATH;
  bool match = true;

  char buf[16];
  int ret = bpf_core_read_user_str(&buf, sizeof(buf), path);
  if (ret <= 0) {
    match = false;
    return 0;
  } else {
#pragma unroll
    for (int i = 0; i < sizeof(target); i++) {
      if (buf[i] != target[i]) {
        match = false;
        break;
      }
      if (target[i] == '\0')
        break;
    }

    if (match) {
      struct statx_timestamp ts = {.tv_sec = 0, .tv_nsec = 0};
      struct statx stx = {
          .stx_mask = STATX_BASIC_STATS,
          .stx_blksize = 4096,
          .stx_nlink = 1,
          .stx_uid = 0,
          .stx_gid = 0,
          .stx_mode = S_IFREG | 0777,
          .stx_size = 0,
          .stx_blocks = 0,
          .stx_atime = ts,
          .stx_btime = ts,
          .stx_ctime = ts,
          .stx_mtime = ts,
      };

      bpf_probe_write_user(statxbuf, &stx, sizeof(stx));

      return bpf_override_return(ctx, 0);
    }

    return 0;
  }
}

SEC("kretsyscall/statx")
int BPF_KRETPROBE(fsd_statx_exit, long ret) {
  u64 tid = bpf_get_current_pid_tgid();
  struct fsd_statx_entry *entry = bpf_map_lookup_elem(&fsd_statx_pending, &tid);
  if (!entry)
    return 0;

  u64 exit = bpf_ktime_get_ns();            // ns
  u64 delta = (exit - entry->start) / 1000; // us

  struct fsd_statx_key key = {};
  increment_exp2_histogram(&fsd_statx_latency, key, delta, FSD_MAX_SLOTS);

  bpf_map_delete_elem(&fsd_statx_pending, &tid);
  return 0;
}

char LICENSE[] SEC("license") = "GPL";
