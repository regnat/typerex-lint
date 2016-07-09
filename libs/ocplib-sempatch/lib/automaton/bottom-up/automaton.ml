open! Std_utils
module IM = Map.Make(State.Identifier)
module T = Tree
module St = State_tree
module S = State

open Std_utils.Option.Infix

type t = {
  transitions: Transitions.t;
  states: State.t IM.t;
}

let update_states t states = { t with states = states }
let update_transitions t transitions = { t with transitions = transitions }

let empty = {
  transitions = Transitions.empty;
  states = IM.empty;
}

let add_state
    ?(final=false)
    ?(updates_loc=false)
    ?replacement_tree
    t
  =
  let state = State.new_state
      ~final
      ~updates_loc
      ~replacement_tree
      ()
  in
  update_states t (IM.add (S.id state) state t.states), S.id state

let get_state t id =
  try
    Some (IM.find id t.states)
  with
  Not_found -> None

let add_transition stree tree dest_id t =
  update_transitions t (Transitions.add t.transitions stree tree dest_id)

let go_one_step t state_tree tree =
  let%bind current_state_id =
    Transitions.follow
      t.transitions
      state_tree
      tree
  in
  try Some (IM.find current_state_id t.states)
  with Not_found -> None

let states t =
  IM.bindings t.states
  |> List.split
  |> snd

let transitions t = t.transitions

let step t stree tree env =
  let%map current_state =
    go_one_step t stree tree
  in
  current_state, env

let rec run t tree env =
  let%bind state_tree, envs =
    match tree with
    | T.Node1 (T.Node12 (sub0, sub1)) ->
      let%bind state0, env0 = run t (T.Node2 sub0) env in
      let%map state1, env1 = run t (T.Leaf1 sub1) env in
      (St.Node1 (St.Node12 (S.id state0, S.id state1))),
      [env0; env1]
    | T.Node1 (T.Node11 sub0) ->
      let%map state0, env0 = run t (T.Node1 sub0) env in
      (St.Node1 (St.Node11 (S.id state0))), [env0]
    | T.Node2 (T.Node21 sub0) ->
      let%map state0, env0 = run t (T.Node1 sub0) env in
      (St.Node2 (St.Node21 (S.id state0))), [env0]
    | T.Node2 (T.Node22 sub0) ->
      let%map state0, env0 = run t (T.Leaf1 sub0) env in
      (St.Node2 (St.Node22 (S.id state0))), [env0]
    | T.Leaf1 _ ->
      Some (St.Unit, [])
  in
  let%map current_state =
    go_one_step t state_tree tree
  in
  let merged_envs =
    List.fold_left Env.merge env envs
  in
  current_state, merged_envs
