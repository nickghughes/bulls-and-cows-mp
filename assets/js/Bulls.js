import React, { useState, useEffect } from 'react'
import 'milligram';
import { uniqDigits } from './util';
import { ch_join, ch_push_guess, ch_set_callback, ch_push_update_role, ch_ready, ch_leave } from './socket'

// Text fields for logging in (user name and game name)
function Login() {
  const [name, setName] = useState("");
  const [game, setGame] = useState("");

  function keypress(ev) {
    // Only allow login if there are entries in both fields
    if (ev.key == "Enter" && name.length > 0 && game.length > 0) {
      ch_join(game, name);
    }
  }

  return (
    <div>
      <div className="row">
        <b>Name:&nbsp;</b>
        <input type="text"
          value={name}
          onKeyDown={keypress}
          onChange={(ev) => setName(ev.target.value)} />
      </div>
      <div className="row">
        <b>Game:&nbsp;</b>
        <input type="text"
          value={game}
          onKeyDown={keypress}
          onChange={(ev) => setGame(ev.target.value)} />
      </div>
      <div className="row">
        <div className="column">
          <button onClick={() => ch_join(game, name)}>
            Login
          </button>
        </div>
      </div>
    </div>
  );
}

// Lobby component, where users join/leave, ready/unready, and switch roles
function Lobby({ props }) {

  // Update the user's role to whatever the radio input was changed to
  function updateUserRole(ev) {
    ch_push_update_role(ev.target.value);
  }

  // Ready or unready (depending which state preceded this call)
  function setReady(ready) {
    ch_ready(ready);
  }

  // Leave the game
  function leaveGame() {
    ch_leave();
  }

  return (
    <div>
      <div className="row">
        <div className="column">
          <b>Players:</b>
        </div>
      </div>
      <div className="row">
        <div className="column">
          {props["players"].map((player) => props["name"] == player["name"]
            ? <b key={player["name"]} className="inline">&nbsp;{`${player["name"]} (You)`}&nbsp;</b>
            : <p key={player["name"]} className="inline">&nbsp;{player["name"]}&nbsp;</p>)}
        </div>
      </div>
      {
        props["role"] == "player" &&
        (props["ready"]
          ? <button onClick={() => setReady(false)} className="button"> Unready </button>
          : <button onClick={() => setReady(true)} className="button"> Ready </button>
        )
      }
      <div className="row">
        <div className="column">
          <div onChange={updateUserRole}>
            <input type="radio" value="player" checked={props["role"] == "player"} /> Player
            <input type="radio" value="spectator" checked={props["role"] == "spectator"} /> Spectator
          </div>
        </div>
      </div>
      <div className="row">
        <div className="column">
          <button onClick={() => leaveGame()} className="button button-clear"> Leave Game </button>
        </div>
      </div>
      <div className="row">
        <div className="column">
          &nbsp;
        </div>
      </div>
      <div className="row">
        <div className="column">
          <Leaderboard leaderboard={props["leaderboard"]} />
        </div>
      </div>
    </div>
  );
}

// Game component, handling mainly input (also nests View component)
function Game({ props }) {
  const [guess, setGuess] = useState("");

  // Update the input field text, keeping only unique digits
  function updateGuess(ev) {
    setGuess(uniqDigits(ev.target.value).substring(0, props["secret_len"]));
  }

  // Make a guess if enter is pressed, and backspace when backspace is pressed
  function keypress(ev) {
    if (ev.key == "Enter" && !cannotGuess()) {
      makeGuess();
    }
    if (ev.key == "Backspace" && guess.length > 0) {
      setGuess(guess.substring(0, guess.length));
    }
  }

  // Add the new guess to the guesses state, then reset the current guess 
  function makeGuess() {
    ch_push_guess(guess);
    setGuess("");
  }

  // Send "pass" as the guess. The server knows how to handle it.
  function pass() {
    ch_push_guess("pass");
    setGuess("");
  }

  // Cannot guess if input is locked or we haven't typed a sufficient guess yet
  function cannotGuess() {
    return cannotInput() || guess.length !== props["secret_len"];
  }

  // Input is locked if we are waiting for other players
  function cannotInput() {
    return props["locked_guess"];
  }

  return (
    <div>
      <div className="row">
        <div className="column" />
        <div className="column" />
        <div className="column align-right">
          <h3>Input:</h3>
        </div>
        <div className="column">
          <input type="text"
            value={guess}
            onChange={updateGuess}
            onKeyDown={keypress}
            disabled={cannotInput()} />
        </div>
        <div className="column align-left">
          <button disabled={cannotGuess()} onClick={() => makeGuess()}>Guess</button>
        </div>
        <div className="column">
          <button className="button button-outline" disabled={cannotInput()} onClick={() => pass()}>Pass</button>
        </div>
        <div className="column" />
      </div>
      {props["locked_guess"] &&
        <div className="row">
          <div className="column">
            <b>Waiting for other players...</b>
          </div>
        </div>
      }
      <View players={props["players"]} name={props["name"]} />
    </div>
  );
}

// Renders the grid of players, along with their guesses/results
function View({ players, name }) {
  const playersPerRow = 4;

  // Render a row of players (1-4)
  function playerColumns(key, players) {
    return (
      <div>
        <div className="row" key={key}>
          {Array.from(Array(playersPerRow - players.length + 1).keys()).map(() =>
            <div className="column column-10">&nbsp;</div>
          )}
          {players.map((player) =>
            <div key={player["name"]} className="column column-20">
              <h2 className={player["name"] === name ? "self" : ""}>{player["name"]}</h2>
              <div className="row">
                <div className="column"><b>Guess</b></div>
                <div className="column"><b>Result</b></div>
              </div>
              {guessGridFor(player)}
            </div>
          )}
          {Array.from(Array(playersPerRow - players.length + 1).keys()).map(() =>
            <div className="column column-10">&nbsp;</div>
          )}
        </div>
      </div>
    )
  }

  // Render the guess/result grid for a player
  function guessGridFor(player) {
    let guessRows = [];
    const guesses = player["guesses"];
    const results = player["results"];
    const numGuesses = guesses.length;

    for (let i = 0; i < numGuesses; i++) {
      guessRows.push(
        <div className="row" key={i}>
          <div className="column">
            {guesses[i]}
          </div>
          <div className="column">
            {results[i]}
          </div>
        </div>
      );
    }

    return guessRows;
  }

  // Render players in chunks (4 players per row)
  let rows = [];
  for (let i = 0; i < players.length / 4; i++) {
    rows.push(playerColumns(i, players.slice(playersPerRow * i, playersPerRow * (i + 1))));
  }

  return (
    <div>
      <div className="row">
        <div className="column">
          {rows}
        </div>
      </div>
      <div className="row">
        &nbsp;
      </div>
      <div className="row">
        <div className="column">
          <button className="button button-clear" onClick={() => ch_leave()}>
            Leave Game
          </button>
        </div>
      </div>
    </div>
  );
}

// Display the winner(s) of the previous game if applicable
function GameOver({ winners }) {
  return (
    <div>
      <div className="row">
        <div className="column">
          <h1>Game Over!</h1>
        </div>
      </div>
      <div className="row">
        <div className="column">
          <h3>The winner(s) were: {winners.join(", ")}</h3>
        </div>
      </div>
    </div>
  );
}

// Render the leaderboard if it exists
function Leaderboard({ leaderboard }) {
  const LEADERBOARD_HEIGHT = 10; // Arbitrary # to limit leaderboard size on frontend

  // Sort the leaderboard, then display in grid
  let leaderboardAsArray = [];
  Object.keys(leaderboard).forEach((player) => {
    leaderboardAsArray.push([player, leaderboard[player]]);
  });

  leaderboardAsArray.sort((a, b) => b[1]["wins"] - a[1]["wins"]);

  return leaderboardAsArray.length > 0 ?
    <div className="row">
      <div className="column column-34 column-offset-33">
        <div className="row">
          <div className="column">
            <h2>Leaderboard</h2>
          </div>
        </div>
        <div className="row">
          <div className="column align-right">
            <b>#</b>
          </div>
          <div className="column">
            <b>Name</b>
          </div>
          <div className="column">
            <b>Wins</b>
          </div>
          <div className="column">
            <b>Losses</b>
          </div>
        </div>
        {Array.from(Array(Math.min(LEADERBOARD_HEIGHT, leaderboardAsArray.length)).keys()).map((i) =>
          <div className="row">
            <div className="column align-right">
              {i + 1}
            </div>
            <div className="column">
              {leaderboardAsArray[i][0]}
            </div>
            <div className="column">
              {leaderboardAsArray[i][1]["wins"]}
            </div>
            <div className="column">
              {leaderboardAsArray[i][1]["losses"]}
            </div>
          </div>
        )}
      </div>
    </div>
    : null;
}

// Root component, renders above components based on app state
export function Bulls() {
  const [state, setState] = useState({});

  // Join the server
  useEffect(() => {
    ch_set_callback(setState);
  });

  let body = null;

  if (Object.keys(state).length == 0) {
    body = <Login />;
  } else if (state["in_game"]) {
    body = state["role"] == "player" ? <Game props={state} /> : <View players={state["players"]} name={state["name"]} />;
  } else if (state["winners"] && state["winners"].length > 0) {
    body = (
      <div>
        <GameOver winners={state["winners"]} />
        <Lobby props={state} />
      </div>
    );
  } else {
    body = <Lobby props={state} />;
  }

  return (
    <div className="bulls-and-cows container">
      {Object.keys(state).length > 0 &&
        <div className="row">
          <div className="column">
            <b>Spectators: </b> {state["spectators"]}
          </div>
        </div>
      }
      <div className="row">
        &nbsp;
      </div>
      {body}
    </div>
  );
}