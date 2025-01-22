defmodule Scrivener.Phoenix.MergeParamsTest do
  use ScrivenerPhoenixWeb.ConnCase, async: true
  alias ScrivenerPhoenixTestWeb.Router.Helpers, as: Routes

  setup %{conn: conn} do
    [
      conn: %{conn | query_params: %{"page" => "1", "search" => "spaghetti", "per" => "50"}},
    ]
  end

  defp do_test(conn, _fun, _helper_arguments, options, expected) do
    options = Enum.into(options, %{params: nil, param_name: :page})
#     sanitized_params = Scrivener.Phoenix.URLBuilder.fetch_and_sanitize_params(conn, options)

#     uri =
#       conn
#       # NOTE: for Scrivener.PhoenixView.URLBuilder.url, options were previously converted to a map
#       # TODO: add a public intermediary function to build options
#       |> Scrivener.Phoenix.URLBuilder.url(fun, helper_arguments, 2, sanitized_params, options)
#       |> URI.parse()

#     assert expected == URI.decode_query(uri.query)

    assert Map.delete(expected, to_string(options.param_name)) == Scrivener.Phoenix.URLBuilder.fetch_and_sanitize_params(conn, options)
  end

  describe "test merge_params behaviour" do
    test "query string is dropped when false", %{conn: conn} do
      do_test(conn, &Routes.blog_post_path/3, [:index], [param_name: :seite, merge_params: false], %{"seite" => "2"})
      do_test(conn, &Routes.blog_post_url/3, [:index], [param_name: :seite, merge_params: false], %{"seite" => "2"})
    end

    test "query string is reproduced when true", %{conn: conn} do
      do_test(conn, &Routes.blog_post_path/3, [:index], [param_name: :seite, merge_params: true], %{"seite" =>"2", "page" => "1", "search" => "spaghetti", "per" => "50"})
      do_test(conn, &Routes.blog_post_url/3, [:index], [param_name: :seite, merge_params: true], %{"seite" =>"2", "page" => "1", "search" => "spaghetti", "per" => "50"})
    end

    test "query string is reproduced but page parameter is overridden if already present when true", %{conn: conn} do
      do_test(conn, &Routes.blog_post_path/3, [:index], [merge_params: true], %{"page" => "2", "search" => "spaghetti", "per" => "50"})
      do_test(conn, &Routes.blog_post_url/3, [:index], [merge_params: true], %{"page" => "2", "search" => "spaghetti", "per" => "50"})
    end

    test "query string is selectively reproduced but page is overridden if already present when a list", %{conn: conn} do
      do_test(conn, &Routes.blog_post_path/3, [:index], [merge_params: ~W[search]a], %{"page" => "2", "search" => "spaghetti"})
      do_test(conn, &Routes.blog_post_path/3, [:index], [merge_params: ~W[search page]a], %{"page" => "2", "search" => "spaghetti"})
      do_test(conn, &Routes.blog_post_url/3, [:index], [merge_params: ~W[search]], %{"page" => "2", "search" => "spaghetti"})

      do_test(conn, &Routes.blog_post_path/3, [:index], [merge_params: ~W[per]], %{"page" => "2", "per" => "50"})
      do_test(conn, &Routes.blog_post_path/3, [:index], [merge_params: ~W[per page]], %{"page" =>"2", "per" => "50"})
      do_test(conn, &Routes.blog_post_url/3, [:index], [merge_params: ~W[per]a], %{"page" => "2", "per" => "50"})
    end
  end
end
