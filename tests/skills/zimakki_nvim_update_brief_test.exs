ExUnit.start()

script =
  Path.expand(
    "../../.agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs",
    __DIR__
  )

if File.exists?(script) do
  System.put_env("ZIMAKKI_UPDATE_BRIEF_NO_MAIN", "1")
  Code.require_file(script)
end

defmodule Zimakki.NvimUpdateBriefTest do
  use ExUnit.Case, async: true

  alias Zimakki.NvimUpdateBrief, as: Brief

  test "resolves the active v6 paths and honours an explicit config" do
    home = "/tmp/zimakki-brief-home"

    env = %{
      "HOME" => home,
      "NVIM_APPNAME" => "astronvim_v6",
      "XDG_CONFIG_HOME" => Path.join(home, "config"),
      "XDG_DATA_HOME" => Path.join(home, "data")
    }

    assert function_exported?(Brief, :resolve_paths, 2)

    assert %{
             app_name: "astronvim_v6",
             config_dir: config_dir,
             data_dir: data_dir,
             brief_home: brief_home
           } = Brief.resolve_paths([config: Path.join(home, "chosen-v6")], env)

    assert config_dir == Path.join(home, "chosen-v6")
    assert data_dir == Path.join(home, "data/astronvim_v6")
    assert brief_home == Path.join(home, "data/zimakki-nvim-update-brief")
  end

  test "collects Lazy and Mason facts and identifies a new upstream target" do
    fixture = fixture!()

    manifest =
      Brief.build_manifest(
        [config: fixture.config, brief_home: fixture.brief_home],
        fixture.env,
        git_for(fixture)
      )

    assert manifest["schema"] == 1
    assert manifest["runtime"]["app_name"] == "astronvim_v6"

    assert %{
             "component_id" => "lazy:folke/snacks.nvim",
             "repository" => "folke/snacks.nvim",
             "baseline" => baseline,
             "target" => target,
             "candidate" => true
           } = hd(manifest["lazy"])

    assert baseline == fixture.locked
    assert target == fixture.remote

    assert %{
             "component_id" => "mason:stylua",
             "installed_version" => "v2.5.0",
             "candidate" => false
           } = hd(manifest["mason"])

    assert is_binary(manifest["guard"]["lazy_lock_sha256"])
    assert manifest["guard"]["plugins"]["lazy:folke/snacks.nvim"]["status"] == ""
  end

  test "does not repeat a Lazy target already covered by an earlier brief" do
    fixture = fixture!()

    first =
      Brief.build_manifest(
        [config: fixture.config, brief_home: fixture.brief_home],
        fixture.env,
        git_for(fixture)
      )

    config_id = first["runtime"]["config_id"]

    write_json!(Path.join(fixture.brief_home, "state.json"), %{
      "schema" => 1,
      "configs" => %{
        config_id => %{
          "components" => %{
            "lazy:folke/snacks.nvim" => %{"covered" => fixture.remote}
          }
        }
      }
    })

    manifest =
      Brief.build_manifest(
        [config: fixture.config, brief_home: fixture.brief_home],
        fixture.env,
        git_for(fixture)
      )

    plugin = hd(manifest["lazy"])
    assert plugin["baseline"] == fixture.remote
    refute plugin["candidate"]
  end

  test "keeps installed facts pending when an upstream remote is unavailable" do
    fixture = fixture!()

    manifest =
      Brief.build_manifest(
        [config: fixture.config, brief_home: fixture.brief_home],
        fixture.env,
        git_for(fixture, remote: {:error, "offline"})
      )

    plugin = hd(manifest["lazy"])
    assert plugin["target"] == fixture.locked
    refute plugin["candidate"]
    assert Enum.any?(plugin["warnings"], &String.contains?(&1, "offline"))
  end

  test "keeps a locked plugin when its install directory is absent" do
    fixture = fixture!()
    File.rm_rf!(fixture.plugin_dir)

    manifest =
      Brief.build_manifest(
        [config: fixture.config, brief_home: fixture.brief_home],
        fixture.env
      )

    plugin = hd(manifest["lazy"])
    assert plugin["locked_revision"] == fixture.locked
    assert is_nil(plugin["installed_revision"])
    assert plugin["warnings"] != []
  end

  test "falls back to the conventional nvim app name" do
    root = "/tmp/zimakki-default-nvim"
    paths = Brief.resolve_paths([], %{"HOME" => root})

    assert paths.app_name == "nvim"
    assert paths.config_dir == Path.join(root, ".config/nvim")
    assert paths.data_dir == Path.join(root, ".local/share/nvim")
  end

  test "reports a missing lockfile directly" do
    fixture = fixture!()
    File.rm!(Path.join(fixture.config, "lazy-lock.json"))

    assert_raise File.Error, ~r/lazy-lock\.json/, fn ->
      Brief.build_manifest(
        [config: fixture.config, brief_home: fixture.brief_home],
        fixture.env,
        git_for(fixture)
      )
    end
  end

  test "collect writes a manifest only inside the brief run directory" do
    fixture = fixture!()

    assert {:ok, path} =
             Brief.collect(
               [config: fixture.config, brief_home: fixture.brief_home],
               fixture.env,
               git_for(fixture)
             )

    assert Path.dirname(path) == Path.join(fixture.brief_home, "runs")
    assert %{"schema" => 1} = path |> File.read!() |> :json.decode()
  end

  test "complete advances processed coverage and preserves pending components" do
    fixture = fixture!()
    opts = [config: fixture.config, brief_home: fixture.brief_home]
    git = git_for(fixture)
    first = Brief.build_manifest(opts, fixture.env, git)
    config_id = first["runtime"]["config_id"]

    write_json!(Path.join(fixture.brief_home, "state.json"), %{
      "schema" => 1,
      "configs" => %{
        config_id => %{
          "components" => %{
            "mason:stylua" => %{
              "covered" => "v2.4.0",
              "disposition" => "featured"
            }
          },
          "adjacent" => ["github:existing/tool"]
        }
      }
    })

    assert {:ok, run_path} = Brief.collect(opts, fixture.env, git)
    run_manifest = run_path |> File.read!() |> :json.decode()
    assert hd(run_manifest["mason"])["candidate"]

    coverage_path = Path.join(fixture.brief_home, "runs/coverage.json")
    report_path = Path.join(fixture.brief_home, "reports/whats-new.html")

    write_json!(coverage_path, %{
      "processed" => [
        %{
          "component_id" => "lazy:folke/snacks.nvim",
          "through" => fixture.remote,
          "disposition" => "featured"
        }
      ],
      "adjacent" => ["github:new/tool"]
    })

    File.mkdir_p!(Path.dirname(report_path))
    File.write!(report_path, "<!doctype html><html><body>New workflows</body></html>")

    assert :ok = Brief.complete(run_path, coverage_path, report_path, fixture.env, git)

    state = Path.join(fixture.brief_home, "state.json") |> File.read!() |> :json.decode()
    config = state["configs"][config_id]

    assert config["components"]["lazy:folke/snacks.nvim"]["covered"] == fixture.remote
    assert config["components"]["mason:stylua"]["covered"] == "v2.4.0"
    assert config["adjacent"] == ["github:existing/tool", "github:new/tool"]
    assert config["last_report"] == Path.expand(report_path)

    next_manifest = Brief.build_manifest(opts, fixture.env, git)
    refute hd(next_manifest["lazy"])["candidate"]
    assert hd(next_manifest["mason"])["candidate"]
  end

  test "complete refuses lockfile, plugin, and Mason receipt mutations" do
    Enum.each([:lockfile, :plugin, :receipt], fn mutation ->
      fixture = fixture!()
      ready = ready_completion!(fixture)

      git_after =
        case mutation do
          :lockfile ->
            File.write!(fixture.lock_path, "{}")
            git_for(fixture)

          :plugin ->
            git_for(fixture, head: String.duplicate("9", 40))

          :receipt ->
            File.write!(fixture.receipt_path, "{}")
            git_for(fixture)
        end

      assert {:error, message} =
               Brief.complete(
                 ready.run_path,
                 ready.coverage_path,
                 ready.report_path,
                 fixture.env,
                 git_after
               )

      assert message =~ "changed after collection"
      assert File.read!(ready.state_path) == ready.original_state
    end)
  end

  test "complete rejects a missing report without changing state" do
    fixture = fixture!()
    ready = ready_completion!(fixture)
    File.rm!(ready.report_path)

    assert {:error, message} =
             Brief.complete(
               ready.run_path,
               ready.coverage_path,
               ready.report_path,
               fixture.env,
               git_for(fixture)
             )

    assert message =~ "cannot read report"
    assert File.read!(ready.state_path) == ready.original_state
  end

  defp fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "zimakki-nvim-update-brief-#{System.unique_integer([:positive, :monotonic])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)

    config = Path.join(root, "astronvim_v6")
    data_home = Path.join(root, "data")
    data_dir = Path.join(data_home, "astronvim_v6")
    plugin_dir = Path.join(data_dir, "lazy/snacks.nvim")
    receipt_dir = Path.join(data_dir, "mason/packages/stylua")
    receipt_path = Path.join(receipt_dir, "mason-receipt.json")
    brief_home = Path.join(root, "brief")
    lock_path = Path.join(config, "lazy-lock.json")
    locked = String.duplicate("1", 40)
    remote = String.duplicate("2", 40)

    File.mkdir_p!(config)
    File.mkdir_p!(plugin_dir)
    File.mkdir_p!(receipt_dir)

    write_json!(lock_path, %{
      "snacks.nvim" => %{"branch" => "main", "commit" => locked}
    })

    write_json!(receipt_path, %{
      "name" => "stylua",
      "schema_version" => "2.0",
      "source" => %{"id" => "pkg:github/johnnymorganz/stylua@v2.5.0"}
    })

    %{
      root: root,
      config: config,
      data_home: data_home,
      plugin_dir: plugin_dir,
      receipt_path: receipt_path,
      brief_home: brief_home,
      lock_path: lock_path,
      locked: locked,
      remote: remote,
      env: %{
        "HOME" => root,
        "NVIM_APPNAME" => "astronvim_v6",
        "XDG_CONFIG_HOME" => Path.join(root, "config"),
        "XDG_DATA_HOME" => data_home
      }
    }
  end

  defp write_json!(path, value) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, value |> :json.encode() |> IO.iodata_to_binary())
  end

  defp git_for(fixture, opts \\ []) do
    remote_result = Keyword.get(opts, :remote, {:ok, fixture.remote <> "\trefs/heads/main\n"})
    head = Keyword.get(opts, :head, fixture.locked)
    status = Keyword.get(opts, :status, "")

    fn
      ["remote", "get-url", "origin"], cwd when cwd == fixture.plugin_dir ->
        {:ok, "git@github.com:folke/snacks.nvim.git\n"}

      ["rev-parse", "HEAD"], cwd when cwd == fixture.plugin_dir ->
        {:ok, head <> "\n"}

      ["status", "--porcelain"], cwd when cwd == fixture.plugin_dir ->
        {:ok, status}

      ["ls-remote", "git@github.com:folke/snacks.nvim.git", "refs/heads/main"], nil ->
        remote_result
    end
  end

  defp ready_completion!(fixture) do
    state_path = Path.join(fixture.brief_home, "state.json")
    original_state = ~s({"schema":1,"configs":{},"sentinel":"before"})
    File.mkdir_p!(fixture.brief_home)
    File.write!(state_path, original_state)

    assert {:ok, run_path} =
             Brief.collect(
               [config: fixture.config, brief_home: fixture.brief_home],
               fixture.env,
               git_for(fixture)
             )

    coverage_path = Path.join(fixture.brief_home, "runs/coverage.json")
    report_path = Path.join(fixture.brief_home, "reports/whats-new.html")

    write_json!(coverage_path, %{
      "processed" => [
        %{
          "component_id" => "lazy:folke/snacks.nvim",
          "through" => fixture.remote,
          "disposition" => "featured"
        }
      ]
    })

    File.mkdir_p!(Path.dirname(report_path))
    File.write!(report_path, "<!doctype html><html><body>New workflows</body></html>")

    %{
      run_path: run_path,
      coverage_path: coverage_path,
      report_path: report_path,
      state_path: state_path,
      original_state: original_state
    }
  end
end
