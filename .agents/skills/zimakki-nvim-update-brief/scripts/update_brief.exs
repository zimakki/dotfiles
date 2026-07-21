defmodule Zimakki.NvimUpdateBrief do
  @moduledoc false

  @schema 1

  def resolve_paths(opts, env) do
    home = Map.fetch!(env, "HOME")
    app_name = Map.get(env, "NVIM_APPNAME", "nvim")
    config_home = Map.get(env, "XDG_CONFIG_HOME", Path.join(home, ".config"))
    data_home = Map.get(env, "XDG_DATA_HOME", Path.join(home, ".local/share"))

    %{
      app_name: app_name,
      config_dir: Path.expand(opts[:config] || Path.join(config_home, app_name)),
      data_dir: Path.expand(Path.join(data_home, app_name)),
      brief_home:
        Path.expand(opts[:brief_home] || Path.join(data_home, "zimakki-nvim-update-brief"))
    }
  end

  def build_manifest(opts, env, run_git \\ &run_git/2) do
    paths = resolve_paths(opts, env)
    lock_path = Path.join(paths.config_dir, "lazy-lock.json")
    lock = read_json!(lock_path)
    state = load_state(paths.brief_home)
    config_id = sha256(paths.config_dir)

    lazy =
      lock
      |> Enum.sort_by(fn {name, _entry} -> name end)
      |> Enum.map(fn {name, entry} ->
        collect_lazy(name, entry, paths, state, config_id, run_git)
      end)

    mason = collect_mason(paths, state, config_id)

    %{
      "schema" => @schema,
      "generated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "runtime" => %{
        "app_name" => paths.app_name,
        "config_dir" => paths.config_dir,
        "data_dir" => paths.data_dir,
        "brief_home" => paths.brief_home,
        "config_id" => config_id
      },
      "lazy" => lazy,
      "mason" => mason,
      "previous_adjacent" => get_in(state, ["configs", config_id, "adjacent"]) || [],
      "guard" => %{
        "lazy_lock_sha256" => lock_path |> File.read!() |> sha256(),
        "plugins" =>
          Map.new(lazy, fn plugin ->
            {plugin["component_id"],
             %{
               "head" => plugin["installed_revision"],
               "status" => plugin["status"]
             }}
          end),
        "receipts" =>
          Map.new(mason, fn package ->
            {package["component_id"], package["receipt_sha256"]}
          end)
      }
    }
  end

  def collect(opts, env \\ System.get_env(), run_git \\ &run_git/2) do
    manifest = build_manifest(opts, env, run_git)
    brief_home = manifest["runtime"]["brief_home"]
    runs_dir = Path.join(brief_home, "runs")
    File.mkdir_p!(runs_dir)

    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")
    suffix = System.unique_integer([:positive, :monotonic])
    path = Path.join(runs_dir, "#{timestamp}-#{suffix}-manifest.json")
    File.write!(path, encode_json(manifest))
    {:ok, path}
  rescue
    error -> {:error, Exception.message(error)}
  end

  def complete(run_path, coverage_path, report_path, _env, run_git) do
    with {:ok, report} <- read_report(report_path),
         true <- html_document?(report) || {:error, "report is not an HTML document"} do
      manifest = read_json!(run_path)
      coverage = read_json!(coverage_path)

      if local_guard(manifest, run_git) != manifest["guard"] do
        {:error, "Neovim artifacts changed after collection; coverage was not advanced"}
      else
        state = load_state(manifest["runtime"]["brief_home"])
        updated = merge_coverage(state, manifest, coverage, report_path)
        write_state!(manifest["runtime"]["brief_home"], updated)
        :ok
      end
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  def main(args, env \\ System.get_env(), run_git \\ &run_git/2)

  def main(["collect" | args], env, run_git) do
    with {:ok, opts} <- parse_collect_options(args),
         {:ok, path} <- collect(opts, env, run_git) do
      IO.puts(path)
      :ok
    end
  end

  def main(["complete" | args], env, run_git) do
    with {:ok, opts} <- parse_complete_options(args),
         :ok <- complete(opts[:run], opts[:coverage], opts[:report], env, run_git) do
      :ok
    end
  end

  def main(_args, _env, _run_git) do
    {:error, "usage: update_brief.exs collect [--config PATH] [--brief-home PATH]"}
  end

  defp parse_collect_options(args) do
    case OptionParser.parse(args, strict: [config: :string, brief_home: :string]) do
      {opts, [], []} ->
        {:ok, opts}

      {_opts, positional, invalid} ->
        {:error, "invalid collect arguments: #{inspect(positional ++ invalid)}"}
    end
  end

  defp parse_complete_options(args) do
    case OptionParser.parse(args,
           strict: [run: :string, coverage: :string, report: :string]
         ) do
      {opts, [], []} ->
        missing = Enum.reject([:run, :coverage, :report], &Keyword.has_key?(opts, &1))

        if missing == [] do
          {:ok, opts}
        else
          {:error, "missing complete options: #{Enum.map_join(missing, ", ", &"--#{&1}")}"}
        end

      {_opts, positional, invalid} ->
        {:error, "invalid complete arguments: #{inspect(positional ++ invalid)}"}
    end
  end

  defp read_report(path) do
    case File.read(path) do
      {:ok, report} -> {:ok, report}
      {:error, reason} -> {:error, "cannot read report #{path}: #{:file.format_error(reason)}"}
    end
  end

  defp html_document?(report) do
    report
    |> String.slice(0, 1_024)
    |> String.downcase()
    |> String.contains?("<html")
  end

  defp local_guard(manifest, run_git) do
    runtime = manifest["runtime"]
    lock_path = Path.join(runtime["config_dir"], "lazy-lock.json")

    %{
      "lazy_lock_sha256" => lock_path |> File.read!() |> sha256(),
      "plugins" =>
        Map.new(manifest["lazy"], fn plugin ->
          install_dir = plugin["install_dir"]
          {head, _warning} = git_from_install(run_git, ["rev-parse", "HEAD"], install_dir)

          {status, _warning} =
            git_from_install(run_git, ["status", "--porcelain"], install_dir)

          {plugin["component_id"], %{"head" => head, "status" => status}}
        end),
      "receipts" =>
        Map.new(manifest["mason"], fn package ->
          hash = package["receipt_path"] |> File.read!() |> sha256()
          {package["component_id"], hash}
        end)
    }
  end

  defp merge_coverage(state, manifest, coverage, report_path) do
    runtime = manifest["runtime"]
    config_id = runtime["config_id"]
    configs = state["configs"] || %{}
    previous = configs[config_id] || %{}
    components = previous["components"] || %{}

    allowed_ids =
      (manifest["lazy"] ++ manifest["mason"])
      |> MapSet.new(& &1["component_id"])

    completed_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    updated_components =
      Enum.reduce(coverage["processed"] || [], components, fn item, acc ->
        id = item["component_id"]
        through = item["through"]
        disposition = item["disposition"]

        unless MapSet.member?(allowed_ids, id) do
          raise ArgumentError, "coverage references unknown component #{inspect(id)}"
        end

        unless disposition in ["featured", "no_learning_value"] do
          raise ArgumentError, "invalid coverage disposition for #{id}"
        end

        unless is_binary(through) and through != "" do
          raise ArgumentError, "coverage target is missing for #{id}"
        end

        Map.put(acc, id, %{
          "covered" => through,
          "disposition" => disposition,
          "report" => Path.expand(report_path),
          "updated_at" => completed_at
        })
      end)

    adjacent = Enum.uniq((previous["adjacent"] || []) ++ (coverage["adjacent"] || []))

    config =
      previous
      |> Map.put("components", updated_components)
      |> Map.put("adjacent", adjacent)
      |> Map.put("last_report", Path.expand(report_path))
      |> Map.put("last_completed_at", completed_at)

    state
    |> Map.put("schema", @schema)
    |> Map.put("configs", Map.put(configs, config_id, config))
  end

  defp write_state!(brief_home, state) do
    File.mkdir_p!(brief_home)
    state_path = Path.join(brief_home, "state.json")
    temporary_path = state_path <> ".tmp"

    try do
      File.write!(temporary_path, encode_json(state))
      File.rename!(temporary_path, state_path)
    after
      if File.exists?(temporary_path), do: File.rm(temporary_path)
    end
  end

  defp collect_lazy(name, entry, paths, state, config_id, run_git) do
    install_dir = Path.join([paths.data_dir, "lazy", name])
    branch = entry["branch"] || "main"
    locked = entry["commit"]

    {origin, origin_warning} =
      git_from_install(run_git, ["remote", "get-url", "origin"], install_dir)

    {head, head_warning} = git_from_install(run_git, ["rev-parse", "HEAD"], install_dir)
    {status, status_warning} = git_from_install(run_git, ["status", "--porcelain"], install_dir)
    repository = github_repository(origin)

    {remote, remote_warning} =
      if origin do
        case git_output(run_git, ["ls-remote", origin, "refs/heads/#{branch}"], nil) do
          {output, warning} -> {ls_remote_head(output), warning}
        end
      else
        {nil, "upstream target unavailable without an origin"}
      end

    component_id = "lazy:#{repository || name}"
    baseline = prior_covered(state, config_id, component_id, locked)
    target = remote || locked || head

    %{
      "component_id" => component_id,
      "name" => name,
      "repository" => repository,
      "origin" => origin,
      "branch" => branch,
      "locked_revision" => locked,
      "installed_revision" => head,
      "status" => status,
      "baseline" => baseline,
      "target" => target,
      "candidate" => not is_nil(target) and target != baseline,
      "install_dir" => install_dir,
      "warnings" =>
        [origin_warning, head_warning, status_warning, remote_warning]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
    }
  end

  defp collect_mason(paths, state, config_id) do
    [
      Path.join([paths.data_dir, "mason", "packages", "*", "mason-receipt.json"]),
      Path.join([paths.data_dir, "mason", "packages", "*", "receipt.json"])
    ]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn receipt_path ->
      receipt = read_json!(receipt_path)
      name = receipt["name"] || receipt_path |> Path.dirname() |> Path.basename()
      source_id = get_in(receipt, ["source", "id"]) || get_in(receipt, ["primary_source", "id"])
      installed_version = purl_version(source_id) || receipt["version"]
      component_id = "mason:#{name}"
      baseline = prior_covered(state, config_id, component_id, installed_version)

      %{
        "component_id" => component_id,
        "name" => name,
        "source_id" => source_id,
        "installed_version" => installed_version,
        "baseline" => baseline,
        "target" => installed_version,
        "candidate" => not is_nil(installed_version) and installed_version != baseline,
        "receipt_path" => receipt_path,
        "receipt_sha256" => receipt_path |> File.read!() |> sha256(),
        "warnings" => if(source_id, do: [], else: ["receipt has no source identifier"])
      }
    end)
  end

  defp prior_covered(state, config_id, component_id, fallback) do
    get_in(state, ["configs", config_id, "components", component_id, "covered"]) || fallback
  end

  defp load_state(brief_home) do
    case File.read(Path.join(brief_home, "state.json")) do
      {:ok, json} -> :json.decode(json)
      {:error, :enoent} -> %{"schema" => @schema, "configs" => %{}}
      {:error, reason} -> raise File.Error, reason: reason, action: "read", path: brief_home
    end
  end

  defp read_json!(path) do
    path
    |> File.read!()
    |> :json.decode()
    |> case do
      value when is_map(value) -> value
      _value -> raise ArgumentError, "expected a JSON object in #{path}"
    end
  end

  defp git_output(run_git, args, cwd) do
    case run_git.(args, cwd) do
      {:ok, output} -> {String.trim(output), nil}
      {:error, reason} -> {nil, "git #{Enum.join(args, " ")} unavailable: #{reason}"}
    end
  end

  defp git_from_install(run_git, args, install_dir) do
    if File.dir?(install_dir) do
      git_output(run_git, args, install_dir)
    else
      {nil, "plugin install directory is absent"}
    end
  end

  defp run_git(args, cwd) do
    options = if cwd, do: [cd: cwd, stderr_to_stdout: true], else: [stderr_to_stdout: true]

    case System.cmd("git", args, options) do
      {output, 0} -> {:ok, output}
      {output, _status} -> {:error, String.trim(output)}
    end
  rescue
    error in ErlangError -> {:error, Exception.message(error)}
  end

  defp ls_remote_head(nil), do: nil
  defp ls_remote_head(""), do: nil
  defp ls_remote_head(output), do: output |> String.split() |> List.first()

  defp github_repository(nil), do: nil

  defp github_repository(origin) do
    case Regex.run(~r{github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?$}, origin) do
      [_, owner, repository] -> "#{owner}/#{repository}"
      _match -> nil
    end
  end

  defp purl_version(nil), do: nil

  defp purl_version(source_id) do
    case String.split(source_id, "@", parts: 2) do
      [_package, version] -> version
      _parts -> nil
    end
  end

  defp sha256(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end

  defp encode_json(value) do
    value
    |> :json.encode()
    |> IO.iodata_to_binary()
  end
end

if System.get_env("ZIMAKKI_UPDATE_BRIEF_NO_MAIN") != "1" do
  case Zimakki.NvimUpdateBrief.main(System.argv()) do
    :ok ->
      :ok

    {:error, message} ->
      IO.puts(:stderr, "zimakki-nvim-update-brief: #{message}")
      System.halt(1)
  end
end
