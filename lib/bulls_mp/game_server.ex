defmodule BullsMp.GameServer do
  use GenServer

  def reg(name) do
    {:via, Registry, {BullsMp.GameReg, name}}
  end

  def start(name) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [name]},
      restart: :permanent,
      type: :worker,
    }
    BullsMp.GameSup.start_child(spec);
  end

  def start_link(name) do
    game = BullsMp.BackupAgent.get(name) || BullsMp.Game.new(name)
    GenServer.start_link(
      __MODULE__,
      game,
      name: reg(name)
    )
  end

  def login(name, user) do
    GenServer.call(reg(name), {:login, name, user})
  end

  def reset(name) do
    GenServer.call(reg(name), {:reset, name})
  end

  def guess(name, user, g) do
    GenServer.call(reg(name), {:guess, name, user, g})
  end

  def peek(name) do
    GenServer.call(reg(name), {:peek, name})
  end

  def update_role(name, user, role) do
    GenServer.call(reg(name), {:update_role, name, user, role})
  end

  def ready(name, user, ready) do
    GenServer.call(reg(name), {:ready, name, user, ready})
  end

  def leave(name, user) do
    GenServer.call(reg(name), {:leave, name, user})
  end

  # implementation

  def init(game) do
    # Process.send_after(self(), :pook, 10_000)
    {:ok, game}
  end

  def handle_call({:login, name, user}, _from, game) do
    game = BullsMp.Game.login(game, user)
    BullsMp.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_call({:guess, name, user, g}, _from, game) do
    round1 = game.round
    game = BullsMp.Game.guess(game, user, g)
    round2 = game.round
    if round2 != round1 and game.timer do
      Process.cancel_timer(game.timer)
    end
    game = if round2 > round1 do
      Map.put(game, :timer, Process.send_after(self(), :end_round, game.turn_millis))
    else
      game
    end
    BullsMp.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_call({:peek, _name}, _from, game) do
    {:reply, game, game}
  end

  def handle_call({:update_role, name, user, role}, _from, game) do
    round1 = game.round
    game = BullsMp.Game.update_role(game, user, role)
    round2 = game.round
    game = if round2 > round1 do
      Map.put(game, :timer, Process.send_after(self(), :end_round, game.turn_millis))
    else
      game
    end
    BullsMp.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_call({:ready, name, user, ready}, _from, game) do
    round1 = game.round
    game = BullsMp.Game.ready(game, user, ready)
    round2 = game.round
    game = if round2 > round1 do
      Map.put(game, :timer, Process.send_after(self(), :end_round, game.turn_millis))
    else
      game
    end
    BullsMp.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_call({:leave, name, user}, _from, game) do
    round1 = game.round
    game = BullsMp.Game.leave(game, user)
    round2 = game.round
    if round2 != round1 and game.timer do
      Process.cancel_timer(game.timer)
    end
    game = if round2 > round1 do
      Map.put(game, :timer, Process.send_after(self(), :end_round, game.turn_millis))
    else
      game
    end
    BullsMp.BackupAgent.put(name, game)
    {:reply, game, game}
  end

  def handle_info(:end_round, game) do
    if game.timer do
      IO.inspect "cancelling timer in handler"
      Process.cancel_timer(game.timer)
    end
    game = BullsMp.Game.end_round(game)
    |> Map.put(:timer, Process.send_after(self(), :end_round, game.turn_millis))
    BullsMp.BackupAgent.put(game.game, game)
    BullsMpWeb.Endpoint.broadcast!(
      "game:" <> game.game,
      "update_players",
      Map.merge(BullsMp.Game.view(game, nil), %{locked_guess: nil})
    )
    {:noreply, game}
  end

  # def handle_info(:pook, game) do
  #   game = BullsMp.Game.guess(game, "q")
  #   BullsMpWeb.Endpoint.broadcast!(
  #     "game:1", # FIXME: Game name should be in state
  #     "view",
  #     BullsMp.Game.view(game, ""))
  #   {:noreply, game}
  # end
end