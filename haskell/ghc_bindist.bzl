"""Workspace rules (GHC binary distributions)"""

_GHC_BINS = {
    "8.6.3": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.6.3/ghc-8.6.3-x86_64-deb8-linux.tar.xz", "291ca565374f4d51cc311488581f3279d3167a064fabfd4a6722fe2bd4532fd5"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.6.3/ghc-8.6.3-x86_64-apple-darwin.tar.xz", "79d069a1a7d74cfdd7ac2a2711c45d3ddc6265b988a0cefa342714b24f997fc1"),
    },
    "8.6.2": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.6.2/ghc-8.6.2-x86_64-deb8-linux.tar.xz", "13f96e8b83bb5bb60f955786ff9085744c24927a33be8a17773f84c7c248533a"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.6.2/ghc-8.6.2-x86_64-apple-darwin.tar.xz", "8ec46a25872226dd7e5cf7271e3f3450c05f32144b96e6b9cb44cc4079db50dc"),
    },
    "8.4.4": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.4.4/ghc-8.4.4-x86_64-deb8-linux.tar.xz", "4c2a8857f76b7f3e34ecba0b51015d5cb8b767fe5377a7ec477abde10705ab1a"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.4.4/ghc-8.4.4-x86_64-apple-darwin.tar.xz", "28dc89ebd231335337c656f4c5ead2ae2a1acc166aafe74a14f084393c5ef03a"),
    },
    "8.4.3": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.4.3/ghc-8.4.3-x86_64-deb8-linux.tar.xz", "b9c855754a3007f69db9a434db3e41050d29aa15cba0ec43a942672a9b5f75b7"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.4.3/ghc-8.4.3-x86_64-apple-darwin.tar.xz", "af0b455f6c46b9802b4b48dad996619cfa27cc6e2bf2ce5532387b4a8c00aa64"),
    },
    "8.4.2": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.4.2/ghc-8.4.2-x86_64-deb8-linux.tar.xz", "246f66eb56f4ad0f1c7755502cfc8f9972f2d067dede17e151f6f479c1f76fbd"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.4.2/ghc-8.4.2-x86_64-apple-darwin.tar.xz", "87469222042b9ac23f9db216a8d4e5107297bdbbb99df71eb4d9e7208455def2"),
    },
    "8.4.1": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.4.1/ghc-8.4.1-x86_64-deb8-linux.tar.xz", "427c77a934b30c3f1de992c38c072afb4323fe6fb30dbac919ca8cb6ae98fbd9"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.4.1/ghc-8.4.1-x86_64-apple-darwin.tar.xz", "d774e39f3a0105843efd06709b214ee332c30203e6c5902dd6ed45e36285f9b7"),
    },
    "8.2.2": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.2.2/ghc-8.2.2-x86_64-deb8-linux.tar.xz", "48e205c62b9dc1ccf6739a4bc15a71e56dde2f891a9d786a1b115f0286111b2a"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.2.2/ghc-8.2.2-x86_64-apple-darwin.tar.xz", "f90fcf62f7e0936a6dfc3601cf663729bfe9bbf85097d2d75f0a16f8c2e95c27"),
    },
    "8.0.2": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/8.0.2/ghc-8.0.2-x86_64-deb8-linux.tar.xz", "5ee68290db00ca0b79d57bc3a5bdce470de9ce9da0b098a7ce6c504605856c8f"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/8.0.2/ghc-8.0.2-x86_64-apple-darwin.tar.xz", "ff50a2df9f002f33b9f09717ebf5ec5a47906b9b65cc57b1f9849f8b2e06788d"),
    },
    "7.10.3": {
        "linux_amd64": ("https://downloads.haskell.org/~ghc/7.10.3/ghc-7.10.3-x86_64-deb8-linux.tar.xz", "b478e282afbf489614d0133ef698ba44e901eeb1794f4453c0fb0807cd271b96"),
        "darwin_amd64": ("https://downloads.haskell.org/~ghc/7.10.3/ghc-7.10.3-x86_64-apple-darwin.tar.xz", "852781d43d41cd55d02f818fe798bb4d1f7e52f488408167f413f7948cf1e7df"),
    },
}

_GHC_DEFAULT_VERSION = "8.4.4"

def _execute_fail_loudly(ctx, args):
    """Execute a command and fail loudly if it fails.

    Args:
      ctx: Repository rule context.
      args: Command and its arguments.
    """
    eresult = ctx.execute(args, quiet = False)
    if eresult.return_code != 0:
        fail("{0} failed, aborting creation of GHC bindist".format(" ".join(args)))

def _ghc_bindist_impl(ctx):
    if ctx.os.name == "linux":
        arch = "linux_amd64"
    elif ctx.os.name == "mac os x":
        arch = "darwin_amd64"
    elif ctx.os.name.startswith("windows"):
        arch = "windows_amd64"
    else:
        fail("Operating system {0} is not yet supported.".format(ctx.os.name))

    version = ctx.attr.version
    if _GHC_BINS[version].get(arch) == None:
        fail("Operating system {0} does not have a bindist for GHC version {1}".format(ctx.os.name, ctx.attr.version))
    else:
        url, sha256 = _GHC_BINS[version][arch]

    bindist_dir = ctx.path(".")  # repo path

    ctx.download_and_extract(
        url = url,
        output = ".",
        sha256 = sha256,
        type = "tar.xz",
        stripPrefix = "ghc-" + version,
    )

    _execute_fail_loudly(ctx, ["./configure", "--prefix", bindist_dir.realpath])
    _execute_fail_loudly(ctx, ["make", "install"])

    ctx.template(
        "BUILD",
        Label("//haskell:ghc.BUILD"),
        executable = False,
    )

ghc_bindist = repository_rule(
    _ghc_bindist_impl,
    local = False,
    attrs = {
        "version": attr.string(
            default = _GHC_DEFAULT_VERSION,
            values = _GHC_BINS.keys(),
            doc = "The desired GHC version",
        ),
    },
)
"""Create a new repository from binary distributions of GHC. The
repository exports two targets:

* a `bin` filegroup containing all GHC commands,
* a `threaded-rts` CC library.

These targets are unpacked from a binary distribution specific to your
platform. Only the platforms that have a "binary package" on the GHC
[download page](https://www.haskell.org/ghc/) are supported.

Example:
   In `WORKSPACE` file:

   ```bzl
   load("@io_tweag_rules_haskell//haskell:haskell.bzl", "ghc_bindist")

   # This repository rule creates @ghc repository.
   ghc_bindist(
     name    = "ghc",
     version = "8.2.2",
   )

   # Register the toolchain defined locally in BUILD file:
   register_toolchains("//:ghc")
   ```

   In `BUILD` file:

   ```bzl
   # Use binaries from @ghc//:bin to define //:ghc toolchain.
   haskell_toolchain(
     name = "ghc",
     version = "8.2.2",
     tools = "@ghc//:bin",
   )
   ```
"""
