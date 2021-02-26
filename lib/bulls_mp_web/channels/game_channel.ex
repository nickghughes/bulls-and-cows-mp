defmodule BullsMpWeb.GameChannel do
  use BullsMpWeb, :channel

  alias BullsMp.Game
  alias BullsMp.GameServer

  @impl true
  def join("game:" <> name, %{"name" => user}, socket) do
    if authorized?(user) do
      GameServer.start(name)
      socket = socket
      |> assign(:name, name)
      |> assign(:user, user)
      view = GameServer.login(name, user)
      |> Game.view(user)
      send(self(), :login)
      {:ok, view, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("guess", %{"guess" => g}, socket) do
    user = socket.assigns[:user]
    game = socket.assigns[:name]
    |> GameServer.guess(user, g)
    view = game
    |> Game.view(user)
    unless view.locked_guess do
      broadcast(socket, "update_players", Map.merge(BullsMp.Game.view(game, nil), %{locked_guess: nil}))
    end
    {:reply, {:ok, view}, socket}
  end

  @impl true
  def handle_in("role", %{"role" => r}, socket) do
    user = socket.assigns[:user]
    view = socket.assigns[:name]
    |> GameServer.update_role(user, String.to_atom(r))
    |> Game.view(user)
    broadcast(socket, "update_players", %{ players: view.players, spectators: view.spectators, in_game: view.in_game })
    {:reply, {:ok, view}, socket}
  end

  @impl true
  def handle_in("ready", %{"ready" => r}, socket) do
    user = socket.assigns[:user]
    view = socket.assigns[:name]
    |> GameServer.ready(user, r)
    |> Game.view(user)
    if view.in_game do
      broadcast(socket, "update_players", %{ players: view.players, spectators: view.spectators, in_game: true })
    end
    {:reply, {:ok, view}, socket}
  end

  @impl true
  def handle_in("leave", _, socket) do
    user = socket.assigns[:user]
    game = socket.assigns[:name]
    |> GameServer.leave(user)
    view = game
    |> Game.view(nil)
    view = if length(game.locked_guesses) == 0 do
      Map.put(view, :locked_guess, nil)
    else
      view
    end
    broadcast(socket, "update_players", view)
    {:reply, {:ok, %{}}, socket}
  end

  intercept ["view"]

  @impl true
  def handle_out("view", msg, socket) do
    user = socket.assigns[:user]
    msg = %{msg | name: user}
    push(socket, "view", msg)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:login, socket) do
    view = socket.assigns[:name]
    |> GameServer.peek()
    |> Game.view(socket.assigns[:user])
    broadcast(socket, "update_players", %{ players: view.players, spectators: view.spectators, in_game: view.in_game })
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_user) do
    true
  end
end