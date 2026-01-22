project('fosdem', 'c', version: '2026.131.0')

host = host_machine.cpu_family()
target = {
    'aarch64': 'aarch64',
    'arm': 'arm',
    'arm64': 'aarch64',
    'i386': 'x86',
    'loongarch64': 'loongarch64',
    'ppc64': 'powerpc',
    'ppc64le': 'powerpc',
    'riscv': 'riscv64',
    'riscv64': 'riscv64',
    's390x': 's390x',
    'x86_64': 'x86',
}.get(
    host,
)

clang = find_program('clang', required: true)
libbpf = dependency('libbpf')

flags = [
    '-g',
    '-O2',
    '-Wall',
    '-target',
    'bpf',
    '-D__TARGET_ARCH_' + target,
    '-I' + meson.current_source_dir() / 'include',
    '-I' + meson.current_source_dir() / 'include' / 'vmlinux' / target,
]

main = custom_target(
    'main.bpf.o',
    input: 'src/main.bpf.c',
    output: 'main.bpf.o',
    command: [clang, flags, '-c', '@INPUT@', '-o', '@OUTPUT@'],
    install: true,
    install_dir: get_option('libexecdir') / 'main.bpf.o',
)
