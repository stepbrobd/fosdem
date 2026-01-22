#import "@preview/cetz:0.4.2": *
#import "@preview/polylux:0.4.0": *

#let title = "eBPF with Nix: laptop to testbed"
#let author = "Yifei Sun"
#let date = datetime(year: 2026, month: 1, day: 31)

#set document(title: title, author: author, date: date)

#set text(size: 20pt)
#set page(paper: "presentation-16-9", margin: 2cm, footer: context [
  #set text(size: 12pt)
  #set align(horizon)
  #date.display("[month repr:long] [day padding:none], [year]")
  #h(1fr)
  #toolbox.slide-number / #toolbox.last-slide-number
])

#slide[
  = #title

  Yifei Sun

  Inria, ENS de Lyon, Université Grenoble Alpes

  #box(image("inria.png", height: 11%))
  #h(1em)
  #box(move(dx: 0pt, dy: 15pt, image("ensl.png", height: 12.5%)))
  #h(1em)
  #box(move(dx: 0pt, dy: 9pt, image("uga.png", height: 11.5%)))
]

#slide[
  == Background

  *I started a project*

  - Multicast caching system for networked FS over XDP
  - Its running late
  - So here I am...
]

#slide[
  == Problem

  - Environment setup and collboration
    - Headers, compiler, editor...
    - KConfig, QEMU, ... (what if multiple machine is needed?)
  - Development, deployment and benchmark
    - Cluster boot, data collection, ...
  - Peer review
    - Ease of result reproduction
]

#slide[
  == What worked for me

  *NixOS VM tests*
  - Basically Nix + Python + QEMU
  - Multi-machines, different kernels, networking
  - Binary cache, and benefits from using Nix

  *NixOS Compose*
  - Deployment tool (Grid'5000 \@ SLICES-FR)
  - Substitute with your own stuff
]

// only very slightly introduce how to get compiler and other userspace tooling
// should be within 15sec
#slide[
  == Userspace tooling

  ```nix
  devShells.x86_64-linux.default = pkgs.mkShell {
    inputsFrom = [ ];
    packages = [ ];
  };
  ```
]

// briefly introduce module system here
#slide[
  == Get a kernel

  #toolbox.side-by-side[
    #set text(size: 14pt)
    ```nix
    kernel = {
      version = "6.19.0-rc5+multikernel";
      modDirVersion = "6.19.0-rc5";
      stdenv = pkgs.gcc13Stdenv;

      # or ./. or fileset ...
      src = fetchFromGitHub {
        owner = "multikernel";
        repo = "linux";
        rev = "a3b4530cc04fe16ddef6b251baac488df3cae79";
        hash = "sha256-mum7rTLU5xUS2qex7br+EotjPyp0...";
      };

      kernelPatches = [ ... ];

      structuredExtraConfig = {
        MULTIKERNEL = lib.kernel.yes;
      };
    };
    ```
  ][
    #set text(size: 15pt)
    ```nix
    boot.kernelPackages = pkgs.linuxPackagesFor (
      pkgs.callPackage (
        { buildLinux, fetchFromGitHub, ... } @ args:
        buildLinux (
          args
          //
          kernel # <--
          //
          (args.argsOverride or { })
        )
      )
      { }
    );
    ```
  ]
]

#slide[
  == One machine

  ```nix
  pkgs.testers.runNixOSTest {
    name = "one-machine-test";

    nodes.machine1 = {
      imports = [ nixosModules.kernel ];
      services.scx.enable = true;
    };

    testScript = ''
      machine1.wait_for_unit("default.target")
      machine1.succeed("")
      machine1.fail("")
    '';
  }
  ```
]

#slide[
  == More machines?

  ```nix
  pkgs.testers.runNixOSTest {
    name = "lots-of-machine-test";

    nodes.machine1.imports = [ nixosModules.grafana ];
    nodes.machine2.imports = with nixosModules; [
      kernel exporter ebpf benchmark
    ];

    testScript = ''
      start_all()
      machine1...
      machine2...
    '';
  }
  ```
]

#slide[
  == What's in there?

  #toolbox.side-by-side[
    ```nix
    nix-repl> test = pkgs.testers.runNixOSTest { ... }
    nix-repl> :p test.
    test.config             test.name
    test.driver             test.nodes
    test.driverInteractive  ...
    ```

    Node closure:

    `<test>.nodes.<name>.system.build.toplevel`

    Driver:

    `<test>.driver` (run `testScript`)

    `<test>.driverInteractive` (Python shell)
  ][
    Python test driver (was Perl \~2009)
    - Nodes
      - `qemu`
    - VLANs
      - `vde_switch`
  ]
]

#slide[
  == Mock syscall

  Say we want to troll ourselves:

  ```c
  SEC("kretsyscall/statx")
  int BPF_KRETPROBE(kretsyscall_statx, long ret) {
    struct context *context = bpf_map_lookup_elem(...);
    struct statx_timestamp ts = {0, 0};
    bpf_probe_write_user(&context->statxbuf->stx_atime, &ts, sizeof(ts));
    // ...                        stx_btime, stx_ctime, stx_mtime
  }
  ```

  And count how many times we've footgun-de ourselves

  With a regular counter and histogram
]

#slide[
  == Declarative userspace program

  - Auto-load the the program (feat. `ebpf_exporter`)
  - Collect the metrics and plot them (feat. Prometheus & Grafana)
  - Local testing (feat. NixOS VM test)
  - Deployment (feat. NixOS-Compose)
]

#slide[
  == Straight to prod
]
