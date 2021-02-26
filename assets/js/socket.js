// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import { Socket } from "phoenix"

let socket = new Socket("/socket", { params: { token: "" } });
socket.connect();

let channel, callback;

let state = {};

function state_update(st) {
  console.log(`New state: ${JSON.stringify(st)}`);
  state = st;
  if (callback) {
    callback(st);
  }
}

export function ch_join(game, name) {
  channel = socket.channel(`game:${game}`, { name });
  channel.join()
    .receive("ok", (resp) => {
      state_update(resp);
      channel.on("update_players", payload => {
        update_players(payload);
      });
    })
    .receive("error", resp => { console.log("Unable to join", resp) });
}

function update_players(payload) {
  if (payload["in_game"] == false && state["in_game"]) {
    payload["ready"] = false;
  }
  let st = Object.assign({}, state, payload);
  state_update(st);
}

export function ch_push_guess(guess) {
  channel.push("guess", { "guess": guess })
    .receive("ok", state_update)
    .receive("error", resp => { console.log("Unable to push", resp) });
}

export function ch_push_reset() {
  channel.push("reset", {})
    .receive("ok", state_update)
    .receive("error", resp => { console.log("Unable to push", resp) });
}

export function ch_set_callback(cb) {
  callback = cb;
}

export function ch_push_update_role(role) {
  channel.push("role", { "role": role })
    .receive("ok", state_update)
    .receive("error", resp => { console.log("Unable to push", resp) });
}

export function ch_ready(ready)  {
  channel.push("ready", {"ready": ready })
    .receive("ok", state_update)
    .receive("error", resp => { console.log("Unable to push", resp) });
}

export function ch_leave()  {
  channel.push("leave")
    .receive("ok", (state) => {
      state_update(state);
      channel.leave();
    })
    .receive("error", resp => { console.log("Unable to push", resp) });
}

export default socket;
