defmodule BullsMpWeb.PageController do
  use BullsMpWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
