open Batteries

type count_matrix = int array array
type background = float array
type t = float array array

let int_of_char = function
  | 'a' | 'A' -> 0
  | 'c' | 'C' -> 1
  | 'g' | 'G' -> 2
  | 't' | 'T' -> 3
  | _ -> 4

let flat_background () = Array.make 4 0.25

let background_of_sequence seq pc =
  let counts = Array.make 4 0
  and n = ref 0 in
  for i = 0 to String.length seq - 1 do
    let k = int_of_char seq.[i] in
    if k < 4 then (
      counts.(k) <- counts.(k) + 1 ;
      incr n
    )
  done ;
  Array.map (fun c -> (float c +. pc) /. (float !n +. 4. *. pc)) counts

let reverse_complement a = Array.(
  init
    (length a)
    (fun i -> [| a.(i).(3) ; a.(i).(2) ; a.(i).(1) ; a.(i).(0) |])
)

let make mat bg = Array.(
  map
    (fun p ->
      let n = fold_left ( + ) 0 p in
      let r = 
	mapi 
	  (fun i x -> log ((float x +. bg.(i)) /. float n /. bg.(i)))
	  p in
      let n_case = 
	range p 
        |> Enum.fold (fun accu i -> accu +. bg.(i) *. r.(i)) 0. in
      append r [| n_case |])
    mat
)

let scan mat seq tol = 
  let r = ref [] 
  and n = String.length seq 
  and m = Array.length mat in
  for i = n - m downto 0 do
    let score = ref 0. in
    for j = 0 to m - 1 do
      score := !score +. mat.(j).(int_of_char seq.[i + j])
    done ;
    if !score > tol 
    then r := (i, !score) :: !r
  done ;
  !r


