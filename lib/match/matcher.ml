(** Pure ranking over path strings.
    Scoring favors basename matches and contiguous runs. Substring
    evidence dominates fuzzy evidence. All functions are total and
    free of observable effects. *)

type candidate = {
  path : string;
  score : float;
}

type ranked = {
  index : int;
  path : string;
  score : float;
}

(** Case folding over ASCII letters.
    Non-ASCII bytes pass through unchanged.
    @return folded string. *)
let lower_ascii s =
  String.map (fun c ->
    if c >= 'A' && c <= 'Z' then Char.chr (Char.code c + 32) else c
  ) s

(** Locates [query] in [text] by naive search.
    Complexity is O(n*m) in text and query lengths. Inputs are short
    in ranking contexts.
    @return byte offset of the first occurrence, or None. *)
let find_substring ~query ~text =
  let n = String.length text in
  let m = String.length query in
  if m = 0 then Some 0
  else if m > n then None
  else
    let rec outer i =
      if i + m > n then None
      else
        let rec inner j =
          if j = m then true
          else if text.[i + j] <> query.[j] then false
          else inner (j + 1)
        in
        if inner 0 then Some i else outer (i + 1)
    in
    outer 0

let substring_score ~query ~path =
  let q = lower_ascii query in
  let p = lower_ascii path in
  if q = "" then 0.0
  else
    match find_substring ~query:q ~text:p with
    | None -> 0.0
    | Some pos ->
      let base = lower_ascii (Filename.basename path) in
      let in_base = match find_substring ~query:q ~text:base with
        | Some _ -> 10.0
        | None -> 0.0
      in
      let length_penalty = float_of_int (String.length path) /. 200.0 in
      let pos_bonus = if pos = 0 then 5.0 else 5.0 /. float_of_int (pos + 1) in
      20.0 +. in_base +. pos_bonus -. length_penalty

(** Scores order-preserving character alignment.
    Aligned characters accumulate per-character weights with gap
    penalties. A query that is not a subsequence scores zero.
    @return non-negative score. *)
let fuzzy_score ~query ~path =
  let q = lower_ascii query in
  let p = lower_ascii path in
  let n = String.length p in
  let m = String.length q in
  if m = 0 then 0.0
  else
    let rec loop i j score last =
      if j = m then score
      else if i = n then -1.0
      else if p.[i] = q.[j] then
        let gap = if last < 0 then 0 else i - last - 1 in
        let add = if gap = 0 then 5.0 else 5.0 /. float_of_int (gap + 1) in
        loop (i + 1) (j + 1) (score +. add) i
      else loop (i + 1) j score last
    in
    let raw = loop 0 0 0.0 (-1) in
    if raw < 0.0 then 0.0
    else raw -. (float_of_int n /. 300.0)

(** Combined score with substring priority.
    The fuzzy score applies only when substring evidence is absent.
    @return non-negative score. *)
let combined_score ~query ~path =
  let s = substring_score ~query ~path in
  if s > 0.0 then s
  else fuzzy_score ~query ~path

let rank ~query ~limit paths =
  if limit < 0 then invalid_arg "rank: limit is negative";
  let scored : candidate list =
    List.filter_map (fun path ->
      let score = combined_score ~query ~path in
      if score <= 0.0 then None
      else Some ({ path; score } : candidate)
    ) paths
  in
  let sorted : candidate list =
    List.sort (fun (a : candidate) (b : candidate) ->
      let c = compare b.score a.score in
      if c <> 0 then c else String.compare a.path b.path
    ) scored
  in
  let rec take n acc = function
    | [] -> List.rev acc
    | x :: xs -> if n <= 0 then List.rev acc else take (n - 1) (x :: acc) xs
  in
  let kept = take limit [] sorted in
  List.mapi (fun i (c : candidate) ->
    { index = i + 1; path = c.path; score = c.score }
  ) kept
