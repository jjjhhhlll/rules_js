load("@bazel_skylib//lib:unittest.bzl", "asserts", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//js/private:js_library.bzl", "js_library")
load("@rules_nodejs//nodejs:providers.bzl", "DeclarationInfo")

# Files + targets generated for use in tests
def _js_library_test_suite_data():
    write_file(
        name = "importing_js",
        out = "importing.js",
        content = ["import { dirname } from 'path'; export const dir = dirname(__filename);"],
        tags = ["manual"],
    )
    write_file(
        name = "importing_dts",
        out = "importing.d.ts",
        content = ["export const dir: string;"],
        tags = ["manual"],
    )


# Tests
def _declaration_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # declarations should only have the source declarations 
    declarations = target_under_test[DeclarationInfo].declarations.to_list()
    asserts.equals(env, 1, len(declarations))
    asserts.true(env, declarations[0].path.find("/importing.d.ts") != -1)

    # transitive_declarations should contain the direct declaration and more indirect deps
    transitive_declarations = target_under_test[DeclarationInfo].transitive_declarations.to_list()
    asserts.true(env, len(transitive_declarations) > len(declarations))
    asserts.true(env, transitive_declarations.index(declarations[0]) != -1)

    # types OutputGroupInfo should be the same as direct declarations
    asserts.equals(env, declarations, target_under_test[OutputGroupInfo].types.to_list())

    return analysistest.end(env)

def _declaration_info_empty_srcs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # declarations should only have the source declarations, in this case 0
    declarations = target_under_test[DeclarationInfo].declarations.to_list()
    asserts.equals(env, 0, len(declarations))

    # transitive_declarations should contain additional indirect deps
    transitive_declarations = target_under_test[DeclarationInfo].transitive_declarations.to_list()
    asserts.true(env, len(transitive_declarations) > len(declarations))

    # types OutputGroupInfo should be the same as direct declarations
    asserts.equals(env, declarations, target_under_test[OutputGroupInfo].types.to_list())

    return analysistest.end(env)


# Test declarations
_declaration_info_test = analysistest.make(_declaration_info_test_impl)
_declaration_info_empty_srcs_test = analysistest.make(_declaration_info_empty_srcs_test_impl)


def js_library_test_suite(name):
    """ Test suite including all tests and data"""
    _js_library_test_suite_data()

    # Declarations in srcs + deps
    js_library(
        name = "transitive_type_deps",
        srcs = ["importing.js", "importing.d.ts"],
        deps = [
            "//:node_modules/@types/node",
        ],
        tags = ["manual"],
    )
    _declaration_info_test(
        name = "transitive_type_deps_test",
        target_under_test = "transitive_type_deps",
    )

    # Empty srcs, declarations in deps
    js_library(
        name = "transitive_type_deps_empty_srcs",
        deps = [":transitive_type_deps"],
        tags = ["manual"],
    )
    _declaration_info_empty_srcs_test(
        name = "transitive_type_deps_empty_srcs_test",
        target_under_test = "transitive_type_deps_empty_srcs",
    )

    native.test_suite(
        name = name,
        tests = [
            ":transitive_type_deps_test",
            ":transitive_type_deps_empty_srcs_test",
        ],
    )