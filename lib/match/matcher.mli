(** Pure ranking over file path candidates.
    All functions in this module are total and free of IO. Scoring is
    case-insensitive over ASCII. Non-ASCII bytes compare literally and
    pass through case folding unchanged. The ranking is deterministic:
    equal scores resolve by path order. *)

(** A scored search candidate. [path] is a normalized absolute path.
    [score] is non-negative with higher values denoting better matches. *)
type candidate = {
  path : string;
  score : float;
}

(** A ranked result with a 1-based dense [index] for display and
    selection. Indices are contiguous from 1 over the retained list. *)
type ranked = {
  index : int;
  path : string;
  score : float;
}

(** [substring_score ~query ~path] scores contiguous matches.
    Basename matches receive a fixed bonus over directory matches.
    Matches at lower byte offsets score above later matches. Length
    imposes a linear penalty. An empty query scores zero. A query
    absent from the path scores zero.
    @return non-negative relevance score. *)
val substring_score : query:string -> path:string -> float

(** [fuzzy_score ~query ~path] scores order-preserving matches.
    Characters of [query] occur in [path] in order with possible gaps.
    Contiguous runs score above gapped runs. Length imposes a linear
    penalty. A query that is not a subsequence of the path scores zero.
    @return non-negative relevance score. *)
val fuzzy_score : query:string -> path:string -> float

(** [rank ~query ~limit paths] scores, sorts, and truncates [paths].
    Substring matches dominate: any path with a positive substring
    score outranks fuzzy-only matches. Sorting is in decreasing order
    of score with path order as tiebreak. Indices are assigned from 1
    over the retained prefix.
    Complexity is O(n * (a + b)) where n is the candidate count and
    a and b are mean query and path lengths, plus sorting cost.
    @param limit maximum results to retain. Non-positive limits yield
      an empty list.
    @return ranked list with dense indices.
    @raise Invalid_argument if [limit] is negative. *)
val rank : query:string -> limit:int -> string list -> ranked list
