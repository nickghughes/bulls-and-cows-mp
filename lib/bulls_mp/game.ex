defmodule BullsMp.Game do
  # Create a new state
  def new(game, leaderboard \\ %{}) do
    secret_len = 4
    %{
      game: game,
      secret: random_secret(secret_len),
      secret_len: secret_len,
      winners: [],
      users: [],
      locked_guesses: [],
      round: 0,
      timer: nil,
      turn_millis: 30_000,
      leaderboard: leaderboard,
    }
  end

  # Add a user to the game. Default role depends on game state (player if in lobby, spectator if in game)
  def login(st, user) do
    if Enum.any?(st.users, fn x -> x.name == user end) do
      st
    else
      role = if st.round > 0, do: :spectator, else: :player
      %{st | users: st.users ++ [%{name: user, ready: st.round > 0, role: role, guesses: [], results: []}]}
    end
  end

  # Update a user's role in the lobby
  def update_role(st, user, role) do
    users = Enum.map(st.users, fn 
        %{name: ^user} -> %{name: user, ready: false, role: role, guesses: [], results: []}
        x -> x
      end
    )
    players = Enum.filter(users, fn x -> x[:role] == :player end)

    # If this leaves all remaining players ready, start the game
    round = if st.round == 0 and length(players) > 0 and Enum.all?(players, fn x -> x[:ready] end) do
      st.round + 1
    else
      st.round
    end
    %{st | users: users, round: round}
  end

  # Ready/unready a user in the lobby
  def ready(st, user, ready) do
    users = Enum.map(st.users, fn 
        %{name: ^user, role: role} -> %{name: user, ready: ready, role: role, guesses: [], results: []}
        x -> x
      end
    )
    players = Enum.filter(users, fn x -> x[:role] == :player end)
    # If all users are now ready, start the game
    round = if st.round == 0 and length(players) > 0 and Enum.all?(players, fn x -> x[:ready] end) do
      st.round + 1
    else
      st.round
    end
    %{st | users: users, round: round}
  end

  # Remove a user from the game
  def leave(st, user) do
    # Delete the user from the user list
    users = List.delete(st.users, user_record_for(st, user))
    players = Enum.filter(users, fn x -> x[:role] == :player end)

    # If this leaves all remaining players ready, start the game
    round = if st.round == 0 and length(players) > 0 and Enum.all?(players, fn x -> x[:ready] end) do
      st.round + 1
    else
      st.round
    end
    state = %{st | users: users, round: round}
    # End the round if all remaining players have guessed
    if length(state.locked_guesses) == length(Enum.filter(state.users, fn x -> x[:role] == :player end)) do
      end_round(state)
    else
      state
    end
  end

  def user_record_for(st, user) do
    Enum.find(st.users, fn x -> x[:name] == user end)
  end

  # General view case (ie nothing specific to user)
  def view(st, nil) do
    %{
      secret_len: st.secret_len,
      winners: st.winners,
      players: Enum.map(Enum.filter(st.users, fn x -> x[:role] == :player end), fn x -> %{name: x[:name], guesses: x[:guesses], results: x[:results]} end),
      spectators: length(Enum.filter(st.users, fn x -> x[:role] == :spectator end)),
      in_game: st.round > 0,
      leaderboard: st.leaderboard
    }
  end

  # Convert the state to the format to be sent to the frontend
  #  ie omit the secret
  def view(st, user) do
    user_record = user_record_for(st, user)
    locked_guess = List.first(Enum.filter(st.locked_guesses, fn x -> x[:name] == user end))
    if user_record do
      Map.merge(view(st, nil), %{
        name: user,
        role: user_record[:role],
        ready: user_record[:ready],
        locked_guess: (if locked_guess, do: locked_guess[:guess], else: nil)
      })
    else
      # Player left, just return general view
      view(st, nil)
    end
  end

  # Make a guess
  def guess(st, user, guess) do
    if Enum.any?(st.locked_guesses, fn x -> x[:name] == user end) do
      # disallow extra guesses from being made
      st
    else 
      # update the state accordingly
      state = %{st | locked_guesses: st.locked_guesses ++ [%{name: user, guess: guess}]}
      # If this was the last player to guess, end the round
      if length(state.locked_guesses) == length(Enum.filter(state.users, fn x -> x[:role] == :player end)) do
        end_round(state)
      else
        state
      end
    end
  end

  # Determine the result of a guess
  def result_of(guess, secret) do
    secret_enum = String.split(secret, "", trim: true)

    # First determine the exact matches ("A" value)
    a_matches = secret_enum
    |> Enum.with_index
    |> Enum.filter(fn {x, i} -> String.at(guess, i) === x end)
    |> Enum.map(fn {x, _} -> x end)

    # Save the length of the matches enum
    a = a_matches
    |> length
    |> to_string

    # Determine the correct but wrong position digits ("B" value)
    #  by first removing digits we already counted
    b = secret_enum
    |> Enum.reject(fn x -> Enum.member?(a_matches, x) end)
    |> Enum.count(fn x -> String.contains?(guess, x) end)
    |> to_string

    #Return the string to denote the result
    "A" <> a <> "B" <> b
  end

  # End the current round by moving current guesses to overall state, then checking for winners
  def end_round(st) do
    if length(st.locked_guesses) == 0 do
      check_for_winners(%{st | round: st.round + 1})
    else
      [guess | rest] = st.locked_guesses
      if guess[:guess] == "pass" do
        end_round %{st | locked_guesses: rest}
      else
        match_idx = Enum.find_index(st.users, fn x -> x[:name] == guess[:name] end)
        match = Enum.at(st.users, match_idx)
        match = %{match | guesses: match.guesses ++ [guess[:guess]], results: match.results ++ [result_of(guess[:guess], st.secret)]}
        end_round %{st | users: List.update_at(st.users, match_idx, fn _ -> match end), locked_guesses: rest}
      end
    end
  end

  # Check if there are winners. If not, return the state. Otherwise, start a new game with an updated leaderboard and the same players.
  def check_for_winners(st) do
    winners = st.users
    |> Enum.filter(fn x -> List.last(x[:guesses]) == st.secret end) 
    |> Enum.map(fn x -> x[:name] end)

    if length(winners) == 0 do
      st
    else
      %{ new(st.game, new_leaderboard(st.leaderboard, st.users, winners)) | timer: st.timer, winners: winners, users: Enum.map(st.users, fn x -> %{name: x[:name], ready: false, role: x[:role], guesses: [], results: []} end) }
    end
  end

  # Update the game leaderboard after a game ends
  def new_leaderboard(leaderboard, users, winners) do
    players = Enum.filter(users, fn x -> x[:role] == :player end)
    leaderboard
    |> add_new_players_to_leaderboard(players)
    |> update_leaderboard(Enum.map(players, fn x -> x[:name] end), winners)
  end

  # Increment win/loss totals for all players who participated in the last game

  defp update_leaderboard(leaderboard, [], []) do
    leaderboard
  end

  defp update_leaderboard(leaderboard, [first_loser | others], []) do
    old_leaderboard_entry = Map.get(leaderboard, first_loser)
    leaderboard_entry = Map.replace(old_leaderboard_entry, :losses, old_leaderboard_entry[:losses] + 1)
    leaderboard
    |> Map.replace(first_loser, leaderboard_entry)
    |> update_leaderboard(others, [])
  end

  defp update_leaderboard(leaderboard, players, [first_winner | others]) do
    players_match_idx = Enum.find_index(players, fn x -> x == first_winner end)
    old_leaderboard_entry = Map.get(leaderboard, first_winner)
    leaderboard_entry = Map.replace(old_leaderboard_entry, :wins, old_leaderboard_entry[:wins] + 1)
    leaderboard
    |> Map.replace(first_winner, leaderboard_entry)
    |> update_leaderboard(List.delete_at(players, players_match_idx), others)
  end

  # Fill in users that are not yet on the leaderboard

  defp add_new_players_to_leaderboard(leaderboard, []) do
    leaderboard
  end

  defp add_new_players_to_leaderboard(leaderboard, [%{name: name} | others]) do
    if Map.has_key?(leaderboard, name) do
      add_new_players_to_leaderboard(leaderboard, others)
    else
      leaderboard
      |> Map.put(name, %{wins: 0, losses: 0})
      |> add_new_players_to_leaderboard(others)
    end
  end

  # Generate a random secret of length secret_len
  def random_secret(secret_len, secret \\ "") do
    cond do
      String.length(secret) === secret_len -> secret
      true ->
        digits = "1234567890"
        |> String.split("", trim: true)
        |> Enum.reject(fn x -> String.contains?(secret, x) end)

        random_secret(secret_len, secret <> Enum.random(digits))
    end
  end
end