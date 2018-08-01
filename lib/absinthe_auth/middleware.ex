defmodule AbsintheAuth.Middleware do
  @behaviour Absinthe.Middleware
  @behaviour Absinthe.Plugin

  # TODO: Handle if resolution itself returns an error
  # e.g. if the resolver returns {:error, "foo"}

  # The approach here is a bit inefficient - we always resolve before
  # restricting. That's really only needed if the resolved value
  # is required to make an access decision. Otherwise we shouldn't resolve
  #
  def _call(%{state: :unresolved, definition: definition} = resolution, args) do
    case resolution.middleware do
      [{{Absinthe.Resolution, :call}, fun} | rest] ->
        # Force resolving if it hasn't happened already
        # FIXME: This will only work if there are no other middlewares on
        # the field (i.e. the resolver is the next middleware)
        # We could possibly traverse the list and remove
        # BUT we probably only need to do this if resolution
        # has not yet completed

        new_res = Absinthe.Resolution.call(resolution, fun)
        call(%{new_res | middleware: rest}, args)

      [] ->
        field = String.to_atom(definition.name)
        new_res = Absinthe.Middleware.MapGet.call(resolution, field)
        call(new_res, args)
    end
  end

  def call(%{state: :unresolved, definition: definition} = resolution, args) do

    IO.inspect(resolution.middleware, label: "UNRESOLVED")

    case resolution.middleware do
      #[{{Absinthe.Resolution, :call}, fun} | rest] ->

      [_ | _] ->
        # Force resolving if it hasn't happened already
        # FIXME: This will only work if there are no other middlewares on
        # the field (i.e. the resolver is the next middleware)
        # We could possibly traverse the list and remove
        # BUT we probably only need to do this if resolution
        # has not yet completed

        #new_res = Absinthe.Resolution.call(resolution, fun)

        go(resolution, args)

      [] ->
        field = String.to_atom(definition.name)
        #new_res = Absinthe.Middleware.MapGet.call(resolution, field)
        go(%{resolution | middleware: [{Absinthe.Middleware.MapGet, field}]}, args)
    end
  end


  # TODO: storing the authorisation state might be better in the private field
  def go(resolution, {module, args}) do
    %{
      resolution
      | context: Map.put(resolution.context, :authorisation, :pending),
      middleware: [{module, args} | resolution.middleware] |> IO.inspect(label: "middleware")
    }
  end

  def after_resolution(exec) do
    exec
  end

  def before_resolution(%{context: context} = exec) do
    context =
      with %{acl: acl} <- context do
        Map.put(context, :permissions, acl.load_permissions(context))
      end

    %{exec | context: context}
  end

  def pipeline(pipeline, _) do
    pipeline
  end

  def _pipeline(pipeline, %{context: context}) do
    with %{authorisation: :pending} <- context do
      [Absinthe.Phase.Document.Execution.Resolution | pipeline]
    else
      _ ->
        pipeline
    end
  end
end