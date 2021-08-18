load("@rules_cc//cc:action_names.bzl", "CPP_LINK_STATIC_LIBRARY_ACTION_NAME")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain")


def _cc_static_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    output_file = ctx.actions.declare_file(ctx.label.name + ".a")

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset(direct = [
            cc_common.create_library_to_link(
                actions = ctx.actions,
                feature_configuration = feature_configuration,
                cc_toolchain = cc_toolchain,
                static_library = output_file,
            ),
        ]),
    )
    compilation_context = cc_common.create_compilation_context()
    linking_context = cc_common.create_linking_context(linker_inputs = depset(direct = [linker_input]))

    archiver_path = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
    )
    archiver_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        output_file = output_file.path,
        is_using_linker = False,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        variables = archiver_variables,
    )
    args = ctx.actions.args()
    args.add_all(command_line)

    env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        variables = archiver_variables,
    )

    ctx.actions.run(
        executable = archiver_path,
        arguments = [args],
        env = env,
        inputs = depset(
            transitive = [
                cc_toolchain.all_files,
            ],
        ),
        outputs = [output_file],
    )

    cc_info = cc_common.merge_cc_infos(cc_infos = [
        CcInfo(compilation_context = compilation_context, linking_context = linking_context),
    ] + [dep[CcInfo] for dep in ctx.attr.deps])
    return [cc_info]

cc_static_library = rule(
    implementation = _cc_static_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [CcInfo]),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    fragments = ["cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    incompatible_use_toolchain_transition = True,
)
