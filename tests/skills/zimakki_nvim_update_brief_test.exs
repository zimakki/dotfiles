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
        git_for(fixture, {:error, "offline"})
      )

    plugin = hd(manifest["lazy"])
    assert plugin["target"] == fixture.locked
    refute plugin["candidate"]
    assert Enum.any?(plugin["warnings"], &String.contains?(&1, "offline"))
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
    brief_home = Path.join(root, "brief")
    locked = String.duplicate("1", 40)
    remote = String.duplicate("2", 40)

    File.mkdir_p!(config)
    File.mkdir_p!(plugin_dir)
    File.mkdir_p!(receipt_dir)

    write_json!(Path.join(config, "lazy-lock.json"), %{
      "snacks.nvim" => %{"branch" => "main", "commit" => locked}
    })

    write_json!(Path.join(receipt_dir, "mason-receipt.json"), %{
      "name" => "stylua",
      "schema_version" => "2.0",
      "source" => %{"id" => "pkg:github/johnnymorganz/stylua@v2.5.0"}
    })

    %{
      root: root,
      config: config,
      data_home: data_home,
      plugin_dir: plugin_dir,
      brief_home: brief_home,
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

  defp git_for(fixture, remote_result \\ nil) do
    fn
      ["remote", "get-url", "origin"], cwd when cwd == fixture.plugin_dir ->
        {:ok, "git@github.com:folke/snacks.nvim.git\n"}

      ["rev-parse", "HEAD"], cwd when cwd == fixture.plugin_dir ->
        {:ok, fixture.locked <> "\n"}

      ["status", "--porcelain"], cwd when cwd == fixture.plugin_dir ->
        {:ok, ""}

      ["ls-remote", "git@github.com:folke/snacks.nvim.git", "refs/heads/main"], nil ->
        remote_result || {:ok, fixture.remote <> "\trefs/heads/main\n"}
    end
  end
end
