open OUnit
open Core.Std
open Biocaml

let id1 = "9229"

let matrix1 =
  [|
    [|0 ; 94 ; 1 ; 2 |] ;
    [|3 ; 75 ; 0 ; 19|] ;
    [|79; 4  ; 3 ; 11|] ;
    [|40; 3  ; 4 ; 50|] ;
    [|66; 1  ; 1 ; 29|] ;
    [|48; 2  ; 0 ; 47|] ;
    [|65; 5  ; 5 ; 22|] ;
    [|11; 2  ; 3 ; 81|] ;
    [|65; 3  ; 28; 1 |] ;
    [|0 ; 3  ; 88; 6 |] ;
   |]

let col1 = Jaspar.Core
let factor_name1 = "SEP4"


let string_of_matrix mat =
  Array.to_list mat
  |> List.map ~f:Array.to_list
  |> List.map ~f:(List.map ~f:string_of_int)
  |> List.map ~f:(String.concat ~sep:":")
  |> String.concat ~sep:"\n"

let test_parser () =
  let db = Jaspar.load "src/tests/data/jaspar_sample" in
  assert_equal ~printer:string_of_int ~msg:"Unexpected database length" 1499 (List.length db) ;
  let jaspar_motif =
    try List.find_exn db ~f:(fun m -> m.Jaspar.id = id1)
    with Not_found -> assert_failure "missing Jaspar entry"
  in
  assert_equal ~printer:string_of_matrix ~msg:"Incorrect matrix" matrix1 jaspar_motif.Jaspar.matrix ;
  assert_equal ~msg:"Incorrect collection" col1 jaspar_motif.Jaspar.collection ;
  assert_equal ~printer:ident factor_name1 jaspar_motif.Jaspar.factor_name

let tests = "JASPAR" >::: [
  "Parse database" >:: test_parser
]
