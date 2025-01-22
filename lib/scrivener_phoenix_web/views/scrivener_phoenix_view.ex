if Code.ensure_loaded?(PhoenixHTMLHelpers) do
  defmodule Scrivener.PhoenixView do
    @moduledoc ~S"""
    The module which provides the helper to generate links for a Scrivener pagination.
    """

    alias Scrivener.Phoenix.Gap
    alias Scrivener.Phoenix.Page
    import Scrivener.Phoenix.URLBuilder
    use Gettext, backend: Scrivener.Phoenix.Gettext

    @default_left 0
    @default_right 0
    @default_window 4
    @default_outer_window 0
    @default_live nil
    @default_inverted false
    @default_param_name :page
    @default_merge_params false
    @default_display_if_single false
    @default_template Scrivener.Phoenix.Template.Bootstrap4

    defp defaults do
      [
        params: nil,
        left: @default_left,
        right: @default_right,
        window: @default_window,
        outer_window: @default_outer_window,
        live: @default_live,
        inverted: @default_inverted, # NOTE: would be great if it was an option handled by (and passed from - part of %Scriver.Page{}) Scrivener
        display_if_single: @default_display_if_single,
        param_name: @default_param_name,
        merge_params: @default_merge_params,
        template: @default_template,
        labels: %{
          first: dgettext("scrivener_phoenix", "First"),
          prev: dgettext("scrivener_phoenix", "Prev"),
          next: dgettext("scrivener_phoenix", "Next"),
          last: dgettext("scrivener_phoenix", "Last"),
        },
        symbols: %{
          first: "«",
          prev: "‹",
          next: "›",
          last: "»",
          #gap: "…",
        },
      ]
    end

    @type conn_or_socket_or_endpoint_or_uri :: Plug.Conn.t | Phoenix.LiveView.Socket.t | module | URI.t
    #@typep options :: %{optional(atom) => any}
    @type options :: %{
      params: Enumerable.t | nil,
      left: non_neg_integer,
      right: non_neg_integer,
      window: non_neg_integer,
      outer_window: non_neg_integer,
      live: boolean | nil,
      inverted: boolean,
      display_if_single: boolean,
      param_name: atom | String.t,
      merge_params: boolean | [atom | String.t],
      template: module,
      labels: %{
        first: String.t,
        prev: String.t,
        next: String.t,
        last: String.t,
      },
      symbols: %{
        first: String.t,
        prev: String.t,
        next: String.t,
        last: String.t,
      },
    }

    @spec do_paginate(conn :: conn_or_socket_or_endpoint_or_uri, page :: Scrivener.Page.t, fun :: (... -> String.t), arguments :: list, options :: %{optional(atom) => any}) :: Phoenix.HTML.safe

    # skip pagination if:
    # - there is zero entry (total)
    # - there only is a single page and display_if_single = false
    defp do_paginate(_conn, %Scrivener.Page{total_entries: 0}, _fun, _arguments, _options), do: nil
    defp do_paginate(_conn, %Scrivener.Page{total_pages: 1}, _fun, _arguments, %{display_if_single: false}), do: nil

    defp do_paginate(conn, page = %Scrivener.Page{}, fun, arguments, options = %{})
      when is_function(fun)
    do
      map = %{
        first: options.inverted,
        prev: options.inverted,
        next: !options.inverted,
        last: !options.inverted,
      }

      options = %{options | labels: options.labels
        |> Enum.reduce(options.labels, fn {k, v}, acc ->
          label =
            [v]
            |> List.insert_at(bool_to_int(map[k]), options.symbols[k])
            |> Enum.join(" ")
            |> String.trim()
          Map.put(acc, k, label)
        end)
      }

      left_window_plus_one = range_as_list(1, options.left + 1)
      right_window_plus_one = range_as_list(page.total_pages - options.right, page.total_pages)
      inside_window_plus_each_sides = range_as_list(page.page_number - options.window - 1, page.page_number + options.window + 1)

      sanitized_params = fetch_and_sanitize_params(conn, options)
      first_page = Page.create(1, url(conn, fun, arguments, 1, sanitized_params, options))
      last_page = Page.create(page.total_pages, url(conn, fun, arguments, page.total_pages, sanitized_params, options))
      prev_page = if has_prev?(page) do
        Page.create(page.page_number - 1, url(conn, fun, arguments, page.page_number - 1, sanitized_params, options))
      end
      next_page = if has_next?(page) do
        Page.create(page.page_number + 1, url(conn, fun, arguments, page.page_number + 1, sanitized_params, options))
      end
      window_pages =
        left_window_plus_one
        |> Kernel.++(right_window_plus_one)
        |> Kernel.++(inside_window_plus_each_sides)
        |> Enum.sort()
        |> Enum.uniq()
        |> Enum.reject(&(&1 < 1 or &1 > page.total_pages))
        |> Enum.map(
          fn page_number ->
            Page.create(page_number, url(conn, fun, arguments, page_number, sanitized_params, options))
          end
        )
        |> add_gap(page, options)
        |> reverse_links_if_not_inversed(options)

      []
      |> prepend_right_links(page, first_page, prev_page, next_page, last_page, options)
      |> append_pages(window_pages, page, options)
      |> Enum.reverse()
      |> prepend_left_links(page, first_page, prev_page, next_page, last_page, options)
      |> options.template.wrap()
    end

    defp auto_set_live_option(options = %{live: nil}, cse)
      when is_map(options)
    do
      Map.put(options, :live, is_struct(cse) and cse.__struct__ == Phoenix.LiveView.Socket)
    end

    defp auto_set_live_option(options, _cse), do: options

    @doc """
    Generates the whole HTML to navigate between pages.

    Options:

      * params (default: `nil`): an explicit list (or map) of parameters to add to the query string, this is mostly intended for LiveView with `push_patch` since *params* have to be handled by yourself
      * left (default: `#{inspect(@default_left)}`): display the *left* first pages
      * right (default: `#{inspect(@default_right)}`): display the *right* last pages
      * window (default: `#{inspect(@default_window)}`): display *window* pages before and after the current page (eg, if 7 is the current page and window is 2, you'd get: `5 6 7 8 9`)
      * outer_window (default: `#{inspect(@default_outer_window)}`), equivalent to left = right = outer_window: display the *outer_window* first and last pages (eg valued to 2:
        `« First ‹ Prev 1 2 ... 5 6 7 8 9 ... 19 20 Next › Last »` as opposed to left = 1 and right = 3: `« First ‹ Prev 1 ... 5 6 7 8 9 ... 18 19 20 Next › Last »`)
      * live (default: `#{inspect(@default_live)}`):
        + `true` to generate links with `Phoenix.LiveView.Helpers.live_patch/2` instead of `Phoenix.HTML.Link.link/2`
        + `nil` to set it automatically to `true` when `paginate/5` is called with a `%Phoenix.LiveView.Socket{}` as its first parameter else `false`
      * inverted (default: `#{inspect(@default_inverted)}`): `true` to first (left side) link last pages instead of first
      * display_if_single (default: `#{inspect(@default_display_if_single)}`): `true` to force a pagination to be displayed when there only is a single page of result(s)
      * param_name (default: `#{inspect(@default_param_name)}`): the name of the parameter generated in URL (query string) to propagate the page number
      * merge_params (default: `#{inspect(@default_merge_params)}`): `true` to copy the entire query string between requests, `false` to ignore it or a list of the parameter names to only reproduce
      * template (default: `#{inspect(@default_template)}`): the module which implements `Scrivener.Phoenix.Template` to use to render links to pages
      * symbols (default: `%{first: "«", prev: "‹", next: "›", last: "»"}`): the symbols to add before or after the label for the first, previous, next and last page (`nil` or `""` for none)
      * labels (default: `%{first: dgettext("scrivener_phoenix", "First"), prev: dgettext("scrivener_phoenix", "Prev"), next: dgettext("scrivener_phoenix", "Next"), last: dgettext("scrivener_phoenix", "Last")}`):
        the texts used by links to describe the first, previous, next and last page
    """
    @spec paginate(conn :: conn_or_socket_or_endpoint_or_uri, spage :: Scrivener.Page.t, fun :: function, arguments :: list, options :: Keyword.t) :: Phoenix.HTML.safe
    def paginate(conn, page = %Scrivener.Page{}, fun, arguments \\ [], options \\ [])
      when is_function(fun)
    do
      # defaults() < config (Application) < options
      options =
        defaults()
        |> Keyword.merge(Application.get_all_env(:scrivener_phoenix))
        |> Keyword.merge(options)
        |> Enum.into(%{})
        |> adjust_symbols_if_needed()
        |> auto_set_live_option(conn)

      do_paginate(conn, page, fun, arguments, options)
    end

    defp adjust_symbols_if_needed(options = %{inverted: true}) do
      %{options | symbols: %{first: options.symbols.last, prev: options.symbols.next, next: options.symbols.prev, last: options.symbols.first}}
    end

    defp adjust_symbols_if_needed(options), do: options

    defp prepend_right_links(links, page, first, prev, _next, _last, options = %{inverted: true}) do
      links
      |> maybe_prepend(&options.template.prev_page/2, prev, options)
      |> maybe_prepend(&options.template.first_page/3, first, page, options)
    end

    defp prepend_right_links(links, page, _first, _prev, next, last, options) do
      links
      |> maybe_prepend(&options.template.next_page/2, next, options)
      |> maybe_prepend(&options.template.last_page/3, last, page, options)
    end

    defp prepend_left_links(links, page, _first, _prev, next, last, options = %{inverted: true}) do
      links
      |> maybe_prepend(&options.template.next_page/2, next, options)
      |> maybe_prepend(&options.template.last_page/3, last, page, options)
    end

    defp prepend_left_links(links, page, first, prev, _next, _last, options) do
      links
      |> maybe_prepend(&options.template.prev_page/2, prev, options)
      |> maybe_prepend(&options.template.first_page/3, first, page, options)
    end

    defp reverse_links_if_not_inversed(links, %{inverted: true}), do: links
    defp reverse_links_if_not_inversed(links, _options) do
      links
      |> Enum.reverse()
    end

    defp prepend_to_list_if_not_nil(nil, list), do: list
    defp prepend_to_list_if_not_nil(value, list) do
      [value | list]
    end

    defp maybe_prepend(links, fun, page, options) do
      page
      |> fun.(options)
      |> prepend_to_list_if_not_nil(links)
    end

    defp maybe_prepend(links, fun, page, spage, options) do
      page
      |> fun.(spage, options)
      |> prepend_to_list_if_not_nil(links)
    end

    defp append_pages(links, pages, spage, options) do
      result =
        pages
        |> Enum.reverse()
        |> Enum.map(
          fn page ->
            options.template.page(page, spage, options)
          end
        )
      Enum.concat(links, result)
    end

    @spec has_prev?(page :: Scrivener.Page.t) :: boolean
    def has_prev?(page = %Scrivener.Page{}) do
      page.page_number > 1
    end

    @spec has_next?(page :: Scrivener.Page.t) :: boolean
    def has_next?(page = %Scrivener.Page{}) do
      page.page_number < page.total_pages
    end

    defp was_truncated([%Gap{} | _ ]), do: true
    defp was_truncated(_), do: false

    defp do_add_gap([], acc, _page = %Scrivener.Page{}, _options = %{}) do
      acc
    end

    defp do_add_gap([hd | tl], acc, page = %Scrivener.Page{}, options = %{}) do
      import Scrivener.Phoenix.Page

      acc = cond do
        left_outer?(hd, options) || right_outer?(hd, page, options) || inside_window?(hd, page, options) ->
          [hd | acc]
        !was_truncated(acc) ->
          [%Gap{} | acc]
        true ->
          acc
      end
      do_add_gap(tl, acc, page, options)
    end

    def add_gap(pages, page = %Scrivener.Page{}, options = %{}) do
      do_add_gap(pages, [], page, options)
    end

    @spec range_as_list(l :: integer, h :: integer) :: [integer]
    defp range_as_list(l, h) do
      l
      |> Range.new(h)
      |> Enum.to_list()
    end

    defp bool_to_int(true), do: 1
    defp bool_to_int(false), do: 0
  end
end
