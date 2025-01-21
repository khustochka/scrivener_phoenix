defmodule ScrivenerPhoenixTestWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: ScrivenerPhoenixTestWeb
      import Plug.Conn
      alias ScrivenerPhoenixTestWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: true

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [
        get_csrf_token: 0,
        view_module: 1,
        view_template: 1,
      ]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
#       use Gettext, backend: Scrivener.Phoenix.Gettext

      # Shortcut for generating JS commands
#       alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes, [
        endpoint: ScrivenerPhoenixTestWeb.Endpoint,
        router: ScrivenerPhoenixTestWeb.Router,
#         statics: ScrivenerPhoenixTestWeb.static_paths(),
      ]

      alias ScrivenerPhoenixTestWeb.Router.Helpers, as: Routes
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
