%{
  deps: %{
    blitz: %{
      path: "../blitz",
      github: %{repo: "nshkrdotcom/blitz", branch: "main"},
      hex: "~> 0.3.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane: %{
      path: "../execution_plane/core/execution_plane",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "core/execution_plane"
      },
      hex: "~> 0.1.0",
      default_order: [:github, :hex, :path],
      publish_order: [:hex]
    },
    execution_plane_operator_terminal: %{
      path: "../execution_plane/runtimes/execution_plane_operator_terminal",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "runtimes/execution_plane_operator_terminal"
      },
      hex: "~> 0.1.0",
      default_order: [:github, :hex, :path],
      publish_order: [:hex]
    },
    execution_plane_process: %{
      path: "../execution_plane/runtimes/execution_plane_process",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "runtimes/execution_plane_process"
      },
      hex: "~> 0.1.0",
      default_order: [:github, :hex, :path],
      publish_order: [:hex]
    },
    jido_integration_v2: %{
      path: "../jido_integration/core/platform",
      github: %{repo: "agentjido/jido_integration", branch: "main", subdir: "core/platform"},
      hex: "~> 0.1.0",
      default_order: [:github, :hex, :path],
      publish_order: [:hex]
    }
  }
}
