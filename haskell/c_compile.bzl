"""C file compilation."""

load(":toolchain.bzl",
     "HaskellPackageInfo",
     "mk_name",
)

load(":tools.bzl",
     "get_compiler",
)

load("@bazel_skylib//:lib.bzl", "paths")

def c_compile_static(ctx):
  """Compile all C files to static object files.

  TODO: We would like to compile these one at a time. This is somewhat
  difficult as they all go into the same object directory and
  therefore share prefix. Possibly we don't care about where in the
  hierarchy they go though so we may be able to just put them in
  separate directory each. Or something.

  Args:
    ctx: Rule context.
  """
  args = ctx.actions.args()
  args.add("-c")
  return _generic_c_compile(ctx, "objects_c", ".o", args)

def c_compile_dynamic(ctx):
  """Compile all C files to dynamic object files.

  TODO: We would like to compile these one at a time. This is somewhat
  difficult as they all go into the same object directory and
  therefore share prefix. Possibly we don't care about where in the
  hierarchy they go though so we may be able to just put them in
  separate directory each. Or something.

  Args:
    ctx: Rule context.
  """
  args = ctx.actions.args()
  args.add(["-c", "-dynamic"])
  return _generic_c_compile(ctx, "objects_c_dyn", ".dyn_o", args)

def _generic_c_compile(ctx, output_dir_template, output_ext, user_args):
  # Directory for objects generated from C files.
  output_dir = ctx.actions.declare_directory(mk_name(ctx, output_dir_template))

  args = ctx.actions.args()
  args.add([
    "-fPIC",
    "-odir", output_dir
  ])

  for opt in ctx.attr.c_options:
    args.add("-optc{0}".format(opt))

  pkg_caches = depset()
  pkg_names = depset()
  for d in ctx.attr.deps:
    if HaskellPackageInfo in d:
      pkg_caches = depset(transitive = [pkg_caches, d[HaskellPackageInfo].caches])
      pkg_names = depset(transitive = [pkg_names, d[HaskellPackageInfo].names])

  # Expose every dependency and every prebuilt dependency.
  for n in depset(transitive = [pkg_names, depset(ctx.attr.prebuilt_dependencies)]).to_list():
    args.add(["-package", n])

  # Point at every package DB we depend on and know of explicitly.
  for c in pkg_caches.to_list():
    args.add(["-package-db", c.dirname])

  # Make all external dependency files available.
  external_files = depset([f for dep in ctx.attr.external_deps
                             for f in dep.files])
  for include_dir in depset([f.dirname for f in external_files.to_list()]).to_list():
    args.add("-I{0}".format(include_dir))

  args.add(ctx.files.c_sources)

  output_files = [ctx.actions.declare_file(paths.join(output_dir.basename, paths.replace_extension(s.path, output_ext)))
                        for s in ctx.files.c_sources]
  ctx.actions.run(
    inputs = ctx.files.c_sources + external_files.to_list() + pkg_caches.to_list(),
    outputs = [output_dir] + output_files,
    use_default_shell_env = True,
    progress_message = "Compiling C dynamic {0}".format(ctx.attr.name),
    executable = get_compiler(ctx),
    arguments = [user_args, args],
  )
  return output_files
