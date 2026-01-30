#import "@preview/cetz:0.4.2": *
#import "@preview/muchpdf:0.1.2": muchpdf
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

  Yifei Sun - PhD Student at

  Inria, ENS de Lyon, Université Grenoble Alpes

  #box(image("inria.png", height: 11%))
  #h(1em)
  #box(move(dx: 0pt, dy: 15pt, image("ensl.png", height: 12.5%)))
  #h(1em)
  #box(move(dx: 0pt, dy: 9pt, image("uga.png", height: 11.5%)))

  // add a funny image
  // mention there will be a demo
  #v(7em)
  - Website: #link("https://0.0.9.5.f.2.0.6.2.ip6.arpa")
  - Email: #link("fosdem@0.0.9.5.f.2.0.6.2.ip6.arpa")
]

#slide[
  == Goals

  #item-by-item[
    - DevOps
    - Demonstrate how I use Nix to do BPF related work
  ]

  // add a picture here
  // from my laptop developing here
  // and deploying to the actual testbed for experiments and benchmark
  #show: later
  #set align(center)
  #muchpdf(read("cycle.pdf", encoding: none), scale: 2.5)

  // add name to the VMs in box, and add another one above testbed
  // name the testbed
]

#slide[
  == Background

  *I started a project*

  #item-by-item[
    - Multicast caching system for networked FS over XDP
    - Its running late
    - So here I am...
  ]
]

#slide[
  == Background

  *Nix*

  #image("nix.jpg", height: 20%)
  #item-by-item[
    - *Declarative* & functional
    - Source code $arrow$ Derivations #footnote(numbering: _ => "1")[https://zero-to-nix.com/concepts/derivations/] $arrow$ Closure #footnote(numbering: _ => "2")[https://zero-to-nix.com/concepts/closures/]
    - NixOS: operating system as closure
    - Nix and NixOS devroom \@ UA2.118 (Henriot)
  ]

  // also mention module system in to concepts
]

#slide[
  == Background

  *Testbed* (Grid'5000 \@ SLICES-FR)

  #box(image("grid5000.png", height: 20%))
  #h(1em)
  #box(image("slices.jpg", height: 20%))

  - Academic HPC cluster, reservation required
  - *Ephemeral* bare metal machines
]

#slide[
  == Background

  #set align(center)
  #box(muchpdf(read("cycle.pdf", encoding: none), scale: 1))
  #box(image("g5k.png", height: 91%))
]

#slide[
  == Problem

  // what's the actual problem in one sentence (the global pov)

  #item-by-item[
    - Environment setup and collaboration
      - Headers, compiler, editor...
      - KConfig, QEMU, ... (what if multiple machines are needed?)
    - Development, deployment and benchmark
      - Cluster boot, data collection, ...
    - Peer review
      - Reproducing benchmark results
    // for g5k, minimizing the impact of external states on the benchmark
    // the factors for reproducibility: sw, hw, and states
    // different "reproducibility", reproducibility of sw vs benchmark results in eval
  ]
]

#slide[
  == What worked for me

  *NixOS VM tests*
  - Basically Nix + Python + QEMU
  - Multi-machines, different kernels, networking
  - Binary cache, and benefits from using Nix

  *NixOS Compose*
  #h(1em)
  #box(image("nxc.png", height: 4%))

  - Multi-flavor deployment tool for *ephemeral* experiments
    - systemd-nspawn
    - Docker
    - Bare metal
    - ...
  - Substitute with your own stuff
]

// only very slightly introduce how to get compiler and other userspace tooling
// should be within 15sec
#slide[
  == Userspace tooling

  Pull packages from pinned `nixpkgs`

  ```nix
  devShells.x86_64-linux.default = pkgs.mkShell {
    inputsFrom = [ <derivations> ];
    packages = with pkgs.llvmPackages; [ clang-unwrapped libllvm ];
  };
  ```

  - Compilers
  - Libraries
  - ...
]

// briefly introduce module system here
#slide[
  == Get a kernel

  // mention multikernel in footnote
  // also this is a declarative appraoch to swap
  // whatever you want, and ordering does not matter

  #toolbox.side-by-side[
    #set text(size: 14pt)
    #reveal-code(lines: (4, 12, 14, 18))[```nix
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
    ```]
  ][
    #show: later
    #show: later
    #show: later
    #show: later
    #set text(size: 14pt)
    ```nix
    {
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
    }
    ```
  ]
]

// stress that nixos test wraps two paragims
// functional for nodes config
// imperitive for the test script

#slide[
  == One machine

  // add scx to footnote

  // add arrows for the slides
  // arrows pointing to closure generation
  // arrows pointing to generating python script
  #toolbox.side-by-side[
    #set text(size: 16pt)
    #reveal-code(lines: (2, 7))[```nix
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
    ```]
  ][
    - Boilerplate
    #v(2em)
    #show: later
    - Declarative NixOS closure generation
    #v(3em)
    #show: later
    - Imperative Python stmts to invoke tests
  ]
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

    #show: later
    Node closure:

    `<test>.nodes.<name>.system.build.toplevel`

    #show: later
    Driver:

    `<test>.driver` (run `testScript`)

    `<test>.driverInteractive` (Python repl)
  ][
    #show: later
    Python test driver
    - Nodes
      - `qemu`
    - VLANs
      - `vde_switch`
  ]
]

// also add a figure on how the program is built and
// how does it comes in place and loadded
// modify the kernel slide and vm test slides
// to support the infra for the ebpf program we are running
#slide[
  == Mock syscall

  Say we want to troll ourselves:

  ```c
  SEC("ksyscall/statx")
  int BPF_KSYSCALL(fsd_statx_entry, ... statx(2) args) {
    // generate a map entry to collect start timestamp
    // check path, if not match return
    // else override with a static statx content
    struct statx stx = { ... };
    bpf_probe_write_user(statxbuf, &stx, sizeof(stx));
    return bpf_override_return(ctx, 0);
  }
  ```

  And count how many times we can footgun ourselves

  With a counter and a histogram
]

// add a picture illustrating the experiment
// a laptop, which node is running modified kernel
// and which ones is running grafana
// and testbed

#slide[
  == Declarative userspace program

  - Auto-load the the program (feat. `ebpf_exporter`)
  - Collect the metrics and plot them (feat. Prometheus & Grafana)
  - Local testing (feat. NixOS VM test)
  - Deployment (feat. NixOS-Compose)
]

#slide[
  == How? // maybe change the title

  #set align(center)
  #muchpdf(read("flow.pdf", encoding: none), scale: 1.845)
  // add labels
  // separate arrows for vm and physical
  // levels? pkg level os level deployment level?
]

#slide[
  == Local testing

  For simplicity

  - We will be using a readily available userspace tool
    - Loading the program
    - Read the map and re-expose the content over Prometheus

  Complication is fast

  - Build once and its immutable
  - Push cache to server (or have a CI server build it)
  - SBOM

  Debugging is easy

  - SSH backdoor enable with a knob
]

#slide[
  == Demo

  // use the flow figure and highlight the part we are doing

  - Build interactive driver closure

    `nom build .#checks.x86_64-linux.default.driverInteractive`

  - Start the driver

  ```console
  $ ./result/bin/nixos-test-driver
  start vlan
  running vlan (pid 3859017; ctl /run/user/1000/vde1.ctl)
  SSH backdoor enabled, the machines can be accessed like this:
      collector:  ssh -o User=root vsock/3
      exporter:   ssh -o User=root vsock/4
  ```
]

#slide[
  == Straight to prod

  Bit-perfect reproducibility (\*: for some store paths)

  Everything is in closure
  - Deployment harness is easy to write
]

#slide[
  == Demo

  // see above

  - Build deployment closure (instrumented with NixOS test)

    `nxc build`

  - Schedule couple machines and deploy the closure to cluster
]

// add a slides on evaluation
// e.g. lines of code to get this running
#slide[
  == Conclusion

  #toolbox.side-by-side[
    Less than 250 LoC (Nix)

    - Portable modules
    - Composable with other services
    - Adding new programs to deployment only adds a couple characters
  ][
    #set text(size: 18pt)
    ```nix
    services.prometheus.exporters.ebpf = {
      enable = true;
      # bpf object file names
      names = [
        "oomkill"
        "softirq-latency"
        ...
      ];
    };
    ```
  ]

  // add link
]

#slide[
  == Questions?

  #set text(size: 20pt)
  #v(2em)

  #toolbox.side-by-side[
    - Code: #link("https://git.sr.ht/~stepbrobd/fosdem")[git.sr.ht/\~stepbrobd/fosdem]
    - https://team.inria.fr/datamove
    - https://numpex.org
  ][
    - Website: #link("https://0.0.9.5.f.2.0.6.2.ip6.arpa")
    - Email: #link("fosdem@0.0.9.5.f.2.0.6.2.ip6.arpa")
  ]

  #v(2em)
  #set text(size: 24pt)
  #set align(center)
  Our team is hiring!
]
