"""Rules for defining toolchains"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    ":private/actions/compile.bzl",
    "compile_binary",
    "compile_library",
)
load(
    ":private/actions/link.bzl",
    "link_binary",
    "link_library_dynamic",
    "link_library_static",
)
load(":private/actions/package.bzl", "package")
load(":private/set.bzl", "set")

_GHC_BINARIES = ["ghc", "ghc-pkg", "hsc2hs", "haddock", "ghci"]

def _run_ghc(hs, cc, inputs, outputs, mnemonic, arguments, params_file = None, env = None, progress_message = None):
    if not env:
        env = hs.env

    args = hs.actions.args()
    args.add([hs.tools.ghc])
    args.add([
        # GHC uses C compiler for assemly, linking and preprocessing as well.
        "-pgma",
        cc.tools.cc,
        "-pgmc",
        cc.tools.cc,
        "-pgml",
        cc.tools.cc,
        "-pgmP",
        cc.tools.cc,
        # Setting -pgm* flags explicitly has the unfortunate side effect
        # of resetting any program flags in the GHC settings file. So we
        # restore them here. See
        # https://ghc.haskell.org/trac/ghc/ticket/7929.
        "-optc-fno-stack-protector",
        "-optP-E",
        "-optP-undef",
        "-optP-traditional",
    ])

    extra_inputs = [
        hs.tools.ghc,
        # Depend on the version file of the Haskell toolchain,
        # to ensure the version comparison check is run first.
        hs.toolchain.version_file,
    ] + cc.files
    if params_file:
        command = '${1+"$@"} $(< %s)' % params_file.path
        extra_inputs.append(params_file)
    else:
        command = '${1+"$@"}'

    if type(inputs) == type(depset()):
        inputs = depset(extra_inputs, transitive = [inputs])
    else:
        inputs += extra_inputs

    hs.actions.run_shell(
        inputs = inputs,
        outputs = outputs,
        command = command,
        mnemonic = mnemonic,
        progress_message = progress_message,
        env = env,
        arguments = [args] + arguments,
    )

    return args

def _haskell_toolchain_impl(ctx):
    for tool in _GHC_BINARIES:
        if tool not in [t.basename for t in ctx.files.tools]:
            fail("Cannot find {} in {}".format(tool, ctx.attr.tools.label))

    # Store the binaries of interest in ghc_binaries.
    ghc_binaries = {}
    for tool in ctx.files.tools:
        if tool.basename in _GHC_BINARIES:
            ghc_binaries[tool.basename] = tool

    # Run a version check on the compiler.
    version_file = ctx.actions.declare_file("ghc-version")
    ghc = ghc_binaries["ghc"]
    ctx.actions.run_shell(
        inputs = [ghc],
        outputs = [version_file],
        mnemonic = "HaskellVersionCheck",
        command = """
{ghc} --numeric-version > {version_file}
if [[ "{expected_version}" != "$(< {version_file})" ]]
then
    echo ERROR: GHC version does not match expected version.
    echo Your haskell_toolchain specifies {expected_version},
    echo but you have $(< {version_file}) in your environment.
exit 1
fi
        """.format(
            ghc = ghc.path,
            version_file = version_file.path,
            expected_version = ctx.attr.version,
        ),
    )

    # Get the versions of every prebuilt package.
    ghc_pkg = ghc_binaries["ghc-pkg"]
    pkgdb_file = ctx.actions.declare_file("ghc-global-pkgdb")
    ctx.actions.run_shell(
        inputs = [ghc_pkg],
        outputs = [pkgdb_file],
        mnemonic = "HaskellPackageDatabaseDump",
        command = "{ghc_pkg} dump --global > {output}".format(
            ghc_pkg = ghc_pkg.path,
            output = pkgdb_file.path,
        ),
    )

    if ctx.attr.c2hs != None:
        ghc_binaries["c2hs"] = ctx.file.c2hs

    tools_struct_args = {
        name.replace("-", "_"): file
        for name, file in ghc_binaries.items()
    }

    locale_archive = None

    if ctx.attr.locale_archive != None:
        locale_archive = ctx.file.locale_archive

    return [
        platform_common.ToolchainInfo(
            name = ctx.label.name,
            tools = struct(**tools_struct_args),
            compiler_flags = ctx.attr.compiler_flags,
            repl_ghci_args = ctx.attr.repl_ghci_args,
            haddock_flags = ctx.attr.haddock_flags,
            locale = ctx.attr.locale,
            locale_archive = locale_archive,
            mode = ctx.var["COMPILATION_MODE"],
            actions = struct(
                compile_binary = compile_binary,
                compile_library = compile_library,
                link_binary = link_binary,
                link_library_dynamic = link_library_dynamic,
                link_library_static = link_library_static,
                package = package,
                run_ghc = _run_ghc,
            ),
            is_darwin = ctx.attr.is_darwin,
            version = ctx.attr.version,
            # Pass through the version_file, that it can be required as
            # input in _run_ghc, to make every call to GHC depend on a
            # successful version check.
            version_file = version_file,
            global_pkg_db = pkgdb_file,
        ),
    ]

_haskell_toolchain = rule(
    _haskell_toolchain_impl,
    attrs = {
        "tools": attr.label(
            doc = "GHC and executables that come with it",
            mandatory = True,
        ),
        "compiler_flags": attr.string_list(
            doc = "A collection of flags that will be passed to GHC on every invocation.",
        ),
        "repl_ghci_args": attr.string_list(
            doc = "A collection of flags that will be passed to GHCI on repl invocation. It extends the `compiler_flags` collection. Flags set here have precedance over `compiler_flags`.",
        ),
        "haddock_flags": attr.string_list(
            doc = "A collection of flags that will be passed to haddock.",
        ),
        "c2hs": attr.label(
            doc = "c2hs executable",
            allow_single_file = True,
        ),
        "version": attr.string(
            doc = "Version of your GHC compiler. It has to match the version reported by the GHC used by bazel.",
            mandatory = True,
        ),
        "is_darwin": attr.bool(
            doc = "Whether compile on and for Darwin (macOS).",
            mandatory = True,
        ),
        "locale": attr.string(
            default = "en_US.UTF-8",
            doc = "Locale that will be set during compiler invocations.",
        ),
        "locale_archive": attr.label(
            allow_single_file = True,
            doc = """
Label pointing to the locale archive file to use. Mostly useful on NixOS.
""",
        ),
    },
)

def haskell_toolchain(
        name,
        version,
        tools,
        compiler_flags = [],
        repl_ghci_args = [],
        haddock_flags = [],
        **kwargs):
    """Declare a compiler toolchain.

    You need at least one of these declared somewhere in your `BUILD` files
    for the other rules to work. Once declared, you then need to *register*
    the toolchain using `register_toolchains` in your `WORKSPACE` file (see
    example below).

    Example:

      In a `BUILD` file:

      ```bzl
      haskell_toolchain(
          name = "ghc",
          version = '1.2.3'
          tools = ["@sys_ghc//:bin"],
          compiler_flags = ["-Wall"],
          c2hs = "@c2hs//:bin", # optional
      )
      ```

      where `@ghc` is an external repository defined in the `WORKSPACE`,
      e.g. using:

      ```bzl
      nixpkgs_package(
          name = 'sys_ghc',
          attribute_path = 'haskell.compiler.ghc822'
      )

      register_toolchains("//:ghc")
      ```

      and for `@c2hs`:

      ```bzl
      nixpkgs_package(
          name = "c2hs",
          attribute_path = "haskell.packages.ghc822.c2hs",
      )
      ```
    """
    impl_name = name + "-impl"
    corrected_ghci_args = repl_ghci_args + ["-no-user-package-db"]
    _haskell_toolchain(
        name = impl_name,
        version = version,
        tools = tools,
        compiler_flags = compiler_flags,
        repl_ghci_args = corrected_ghci_args,
        haddock_flags = haddock_flags,
        visibility = ["//visibility:public"],
        is_darwin = select({
            "@bazel_tools//src/conditions:darwin": True,
            "//conditions:default": False,
        }),
        **kwargs
    )

    native.toolchain(
        name = name,
        toolchain_type = "@io_tweag_rules_haskell//haskell:toolchain",
        toolchain = ":" + impl_name,
        exec_compatible_with = [
            "@bazel_tools//platforms:x86_64",
        ],
        target_compatible_with = [
            "@bazel_tools//platforms:x86_64",
        ],
    )
