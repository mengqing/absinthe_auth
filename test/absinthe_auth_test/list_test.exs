defmodule AbsintheAuthTest.ListTest do
  use AbsintheAuthTest.GraphQLCase
  import AbsintheAuthTest.SetupHelpers
  doctest AbsintheAuth

  @query """
    {
      movies {
        title
        budget
      }
    }
  """

  describe "when the viewer is not set (logged out)" do
    test "budget is not visible on any movie" do
      @query
      |> Absinthe.run(Movies.Schema)
      |> assert_success
      |> assert_field_error(["movies", 0, "budget"], "Denied")
      |> assert_field_error(["movies", 1, "budget"], "Denied")
      |> assert_field_error(["movies", 2, "budget"], "Denied")
      |> assert_field_error(["movies", 3, "budget"], "Denied")
    end
  end

  describe "when the viewer is a producer" do
    setup [:viewer_is_producer]

    test "budget is visible on movies she produced", %{context: context} do
      @query
      |> Absinthe.run(Movies.Schema, context: context)
      |> assert_success
      |> assert_field(["movies", 0, "budget"], 63_000_000)
      |> assert_field_error(["movies", 1, "budget"], "Denied")
      |> assert_field_error(["movies", 2, "budget"], "Denied")
      |> assert_field_error(["movies", 3, "budget"], "Denied")
    end
  end

  describe "when the viewer is a studio manager" do
    setup [:viewer_is_studio_manager]

    test "budget is visible on all movies", %{context: context} do
      @query
      |> Absinthe.run(Movies.Schema, context: context)
      |> assert_success
      |> assert_field(["movies", 0, "budget"], 63_000_000)
      |> assert_field(["movies", 1, "budget"], 11_000_000)
      |> assert_field(["movies", 2, "budget"], 4_000_000)
      |> assert_field(["movies", 3, "budget"], 12_000_000)
    end
  end
end
