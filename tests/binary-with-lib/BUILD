load(
    "@io_tweag_rules_haskell//haskell:haskell.bzl",
    "haskell_library",
    "haskell_test",
)

package(default_testonly = 1)

haskell_library(
    name = "lib",
    srcs = glob(["src/*.hs"]),
    src_strip_prefix = "src",
)

haskell_test(
    name = "binary-with-lib",
    srcs = ["Main.hs"],
    visibility = ["//visibility:public"],
    deps = [
        ":lib",
        "@hackage//:base",
    ],
)
