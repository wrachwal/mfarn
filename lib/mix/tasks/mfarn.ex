defmodule Mix.Tasks.Mfarn do
  use Mix.Task

  @moduledoc """
  Print warnings about remote calls (MFA) unable to find in the project.

  This is sub-task intentended to be run after `compile` task.

  In `mix.exs` define `compile` alias in which `mfarn` task follows `compile` task:

      def project do
        [# ...
         aliases: aliases]
      end

      defp aliases do
        [compile: ["compile", "mfarn"]]
      end
  """

  def run(_) do
    config = Mix.Project.config
    app = config[:app]
    # {:ok, _} = Application.ensure_all_started(app)
    app_res = Atom.to_char_list(app) ++ '.app'
    app_file = :code.where_is_file(app_res)
    is_list(app_file) || throw "not found #{inspect app_res}"
    {:ok, [{:application,^app,app_terms}]} = :file.consult(app_file)
    modules = app_terms[:modules]
    Enum.reduce modules, {MapSet.new, MapSet.new}, &check_module/2
  end

  def check_module(module) do
    check_module(module, {MapSet.new, MapSet.new})
    :ok
  end

  defp check_module(module, {visited, exports}) do
    # IO.puts "# #{module}"
    beam = :code.which(module)
    {:ok, {^module, [abstract_code: {_, code}]}} = :beam_lib.chunks(beam, [:abstract_code])
    tree = :erl_syntax.form_list(code)
    source = module.module_info[:compile][:source]
    source = Path.relative_to_cwd(source)
    imports = called_remote_funs(tree)
    Enum.reduce imports, {visited, exports}, &check_mfa(source, &1, &2)
  end

  defp called_remote_funs(tree) do
    :erl_syntax_lib.fold(&pick_remote_fun/2, MapSet.new, tree) |> Enum.sort
  end

  defp pick_remote_fun(ast, acc) do
    case ast do
      {:call, line, {:remote, _, {:atom, _, mod}, {:atom, _, fun}}, args} ->
        acc = MapSet.put(acc, {line, {mod, fun, length(args)}})
        if fun == :make_fun and mod == :erlang do
          case args do
            [{:atom, _, mod}, {:atom, _, fun}, {:integer, _, arity}] ->
              acc = MapSet.put(acc, {line, {mod, fun, arity}})
            _ -> nil
          end
        end
      _ -> nil
    end
    acc
  end

  defp check_mfa(source, {line, mfa}, {visited, exports}) do
    {mod, fun, arity} = mfa
    unless MapSet.member?(exports, mfa) do
      unless MapSet.member?(visited, mod) do
        visited = MapSet.put(visited, mod)
        fa_list = try do
          # IO.puts "? #{mod}"
          mod.module_info[:exports]
        catch
          _, _ -> []
        end
        exports = Enum.reduce fa_list, exports, fn {f, a}, mfa_set -> MapSet.put(mfa_set, {mod, f, a}) end
      end
      unless MapSet.member?(exports, mfa) do
        IO.puts "#{source}:#{line}: warning: unknown #{inspect mod}.#{fun}/#{arity}"
      end
    end
    {visited, exports}
  end
end
