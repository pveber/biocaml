open Core.Std
open Biocaml_internal_utils
module Phred_score = Biocaml_phred_score
open Result.Monad_infix

let ( >>?~ )
    (x : 'a option Or_error.t)
    ~(f : 'a -> 'b Or_error.t)
    : 'b option Or_error.t
    =
  let open Result.Monad_infix in
  x >>= function
  | None -> Ok None
  | Some x -> f x >>| Option.some

(******************************************************************************)
(* Header Types                                                               *)
(******************************************************************************)
type header_item_tag = [
| `HD | `SQ | `RG | `PG | `CO
| `Other of string
] with sexp

type tag_value = string * string
with sexp

type sort_order = [ `Unknown | `Unsorted | `Query_name | `Coordinate ]
with sexp

type header_line = {
  version : string;
  sort_order : sort_order option;
} with sexp

type ref_seq = {
  name : string;
  length : int;
  assembly : string option;
  md5 : string option;
  species : string option;
  uri : string option;
} with sexp

type platform = [
| `Capillary | `LS454 | `Illumina | `Solid
| `Helicos | `Ion_Torrent | `Pac_Bio
] with sexp

type read_group = {
  id : string;
  seq_center : string option;
  description : string option;
  run_date : [`Date of Date.t | `Time of Time.t] option;
  flow_order : string option;
  key_seq : string option;
  library : string option;
  program : string option;
  predicted_median_insert_size : int option;
  platform : platform option;
  platform_unit : string option;
  sample : string option;
} with sexp

type program = {
  id : string;
  name : string option;
  command_line : string option;
  previous_id : string option;
  description : string option;
  version : string option;
} with sexp

type header_item = [
| `HD of header_line
| `SQ of ref_seq
| `RG of read_group
| `PG of program
| `CO of string
| `Other of string * tag_value list
] with sexp

type header = {
  version : string option;
  sort_order : sort_order option;
  ref_seqs : ref_seq list;
  read_groups : read_group list;
  programs : program list;
  comments : string list;
  others : (string * tag_value list) list;
}


(******************************************************************************)
(* Alignment Types                                                            *)
(******************************************************************************)
module Flags = struct
  type t = int
  with sexp

  let of_int x =
    if (0 <= x) && (x <= 65535) then
      Ok x
    else
      error "flag out of range" x sexp_of_int

  let flag_is_set s f = (f land s) <> 0

  let has_multiple_segments            = flag_is_set 0x1
  let each_segment_properly_aligned    = flag_is_set 0x2
  let segment_unmapped                 = flag_is_set 0x4
  let next_segment_unmapped            = flag_is_set 0x8
  let seq_is_reverse_complemented      = flag_is_set 0x10
  let next_seq_is_reverse_complemented = flag_is_set 0x20
  let first_segment                    = flag_is_set 0x40
  let last_segment                     = flag_is_set 0x80
  let secondary_alignment              = flag_is_set 0x100
  let not_passing_quality_controls     = flag_is_set 0x200
  let pcr_or_optical_duplicate         = flag_is_set 0x400
end

type cigar_op = [
| `Alignment_match of int
| `Insertion of int
| `Deletion of int
| `Skipped of int
| `Soft_clipping of int
| `Hard_clipping of int
| `Padding of int
| `Seq_match of int
| `Seq_mismatch of int
] with sexp

type optional_field_value = [
| `A of string
| `i of Int32.t
| `f of float
| `Z of string
| `H of string
| `B of char * string list
] with sexp

type optional_field = {
  tag : string;
  value : optional_field_value
} with sexp

type rnext = [`Value of string | `Equal_to_RNAME]
with sexp

type alignment = {
  qname : string option;
  flags : Flags.t;
  rname : string option;
  pos : int option;
  mapq : int option;
  cigar : cigar_op list;
  rnext : rnext option;
  pnext : int option;
  tlen : int option;
  seq: string option;
  qual: Biocaml_phred_score.t list;
  optional_fields : optional_field list;
} with sexp


(******************************************************************************)
(* Main Item Type                                                             *)
(******************************************************************************)
type item = [
| `Header_item of header_item
| `Alignment of alignment
] with sexp


(******************************************************************************)
(* Header Parsers and Constructors                                            *)
(******************************************************************************)
let parse_header_version s =
  let err =
    error "invalid version" (`HD, s)
    <:sexp_of< header_item_tag * string >>
  in
  match String.lsplit2 ~on:'.' s with
  | None -> err
  | Some (a,b) ->
    if (String.for_all a ~f:Char.is_digit)
      && (String.for_all b ~f:Char.is_digit)
    then
      Ok s
    else
      err

let header_line ~version ?sort_order () =
  parse_header_version version >>| fun version ->
  {version; sort_order}

let ref_seq
    ~name ~length
    ?assembly ?md5 ?species ?uri
    ()
    =
  let is_name_first_char_ok = function
    | '!' .. ')' | '+' .. '<' | '>' .. '~' -> true
    | _ -> false
  in

  let is_name_other_char_ok = function '!' .. '~' -> true | _ -> false in

  (if (1 <= length) && (length <= 2147483647) then
      Ok length
   else
      error "invalid reference sequence length" length sexp_of_int
  ) >>= fun length ->

  (if (String.length name > 0)
      && (String.foldi name ~init:true ~f:(fun i accum c ->
        accum && (
          if i = 0 then is_name_first_char_ok c
          else is_name_other_char_ok c
        ) ) )
   then
      Ok name
   else
      error "invalid ref seq name" name sexp_of_string
  ) >>= fun name ->

  Ok {name; length; assembly; md5; species; uri}


let read_group
    ~id ?seq_center ?description ?run_date ?flow_order
    ?key_seq ?library ?program ?predicted_median_insert_size
    ?platform ?platform_unit ?sample
    ()
    =
  (match run_date with
  | None -> Ok None
  | Some run_date ->
    try Ok (Some (`Date (Date.of_string run_date)))
    with _ ->
      try Ok (Some (`Time (Time.of_string run_date)))
      with _ ->
        error "invalid run date/time" run_date sexp_of_string
  ) >>= fun run_date ->

  (match flow_order with
  | None -> Ok None
  | Some "" -> Or_error.error_string "invalid empty flow order"
  | Some "*" -> Ok flow_order
  | Some x ->
    if String.for_all x ~f:(function
    | 'A' | 'C' | 'M' | 'G' | 'R' | 'S' | 'V' | 'T' | 'W'| 'Y' | 'H'
    | 'K' | 'D' | 'B' | 'N' -> true
    | _ -> false
    )
    then
      Ok flow_order
    else
      error "invalid flow order" x sexp_of_string
  ) >>| fun flow_order ->

  {
    id; seq_center; description; run_date; flow_order; key_seq;
    library; program; predicted_median_insert_size;
    platform; platform_unit; sample;
  }


let header
    ?version ?sort_order ?(ref_seqs=[]) ?(read_groups=[])
    ?(programs=[]) ?(comments=[]) ?(others=[])
    ()
    =
  [
    (
      match version with
      | None -> None
      | Some x -> match parse_header_version x with
        | Error e -> Some e
        | Ok _ -> None
    );
    (
      if Option.is_some sort_order && (version = None) then
        Some (Error.create
                "sort order cannot be defined without version"
                (sort_order, version)
                <:sexp_of< sort_order option * string option >>
        )
      else
        None
    );
    (
      List.map ref_seqs ~f:(fun (x:ref_seq) -> x.name)
      |> List.find_a_dup
      |> Option.map ~f:(fun name ->
         Error.create "duplicate ref seq name" name sexp_of_string
      )
    );
  ]
  |> List.filter_map ~f:Fn.id
  |> function
     | [] -> Ok {
       version; sort_order; ref_seqs; read_groups;
       programs; comments; others;
     }
     | errs -> Error (Error.of_list errs)


let parse_header_item_tag s =
  let is_letter = function 'A' .. 'Z' | 'a' .. 'z' -> true | _ -> false in
  match String.chop_prefix s ~prefix:"@" with
  | None -> error "header item tag must begin with @" s sexp_of_string
  | Some "HD" -> Ok `HD
  | Some "SQ" -> Ok `SQ
  | Some "RG" -> Ok `RG
  | Some "PG" -> Ok `PG
  | Some "CO" -> Ok `CO
  | Some x ->
    if (String.length x = 2)
      && (String.for_all x ~f:is_letter)
    then
      Ok (`Other x)
    else
      error "invalid header item tag" s sexp_of_string

let parse_tag_value s =
  let parse_tag s =
    if (String.length s = 2)
      && (match s.[0] with 'A' .. 'Z' | 'a' .. 'z' -> true | _ -> false)
      && (match s.[1] with
          | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' -> true
          | _ -> false
      )
    then
      Ok s
    else
      error "invalid tag" s sexp_of_string
  in
  let parse_value tag s =
    if (s <> "")
      && (String.for_all s ~f:(function ' ' .. '~' -> true | _ -> false))
    then
      Ok s
    else
      error "tag has invalid value" (tag,s)
      <:sexp_of< string * string >>
  in
  match String.lsplit2 s ~on:':' with
  | None ->
    error "tag-value not colon separated" s sexp_of_string
  | Some (tag,value) ->
    parse_tag tag >>= fun tag ->
    parse_value tag value >>= fun value ->
    Ok (tag, value)

(** Find all occurrences of [x'] in the association list [l]. *)
let find_all l x' =
  let rec loop accum = function
    | [] -> accum
    | (x,y)::l ->
      let accum = if x = x' then y::accum else accum in
      loop accum l
  in
  List.rev (loop [] l)

(** Find exactly 1 occurrence [x] in association list [l]. Return
    error if [x] is not defined exactly once. *)
let find1 header_item_tag l x =
  match find_all l x with
  | [] ->
    error "required tag not found" (header_item_tag, x)
    <:sexp_of< header_item_tag * string >>
  | y::[] -> Ok y
  | ys ->
    error "tag found multiple times" (header_item_tag, x, ys)
    <:sexp_of< header_item_tag * string * string list >>

(** Find 0 or 1 occurrence [x] in association list [l]. Return
    error if [x] is defined more than once. *)
let find01 header_item_tag l x =
  match find_all l x with
  | [] -> Ok None
  | y::[] -> Ok (Some y)
  | ys ->
    error "tag found multiple times" (header_item_tag, x, ys)
    <:sexp_of< header_item_tag * string * string list >>

(** Assert that [tvl] contains at most the given [tags]. *)
let assert_tags header_item_tag tvl tags =
  let expected_tags = String.Set.of_list tags in
  let got_tags = List.map tvl ~f:fst |> String.Set.of_list in
  let unexpected_tags = Set.diff got_tags expected_tags in
  if Set.length unexpected_tags = 0 then
    Ok ()
  else
    error
      "unexpected tag for given header item type"
      (header_item_tag, unexpected_tags)
      <:sexp_of< header_item_tag * String.Set.t >>

let parse_sort_order = function
  | "unknown" -> Ok `Unknown
  | "unsorted" -> Ok `Unsorted
  | "queryname" -> Ok `Query_name
  | "coordinate" -> Ok `Coordinate
  | x -> error "invalid sort order" x sexp_of_string

let parse_header_line tvl =
  find1 `HD tvl "VN" >>= fun version ->
  find01 `HD tvl "SO" >>?~
  parse_sort_order >>= fun sort_order ->
  assert_tags `HD tvl ["VN"; "SO"] >>= fun () ->
  header_line ~version ?sort_order ()

let parse_ref_seq tvl =
  find1 `SQ tvl "SN" >>= fun name ->
  find1 `SQ tvl "LN" >>= fun length ->
  (try Ok (Int.of_string length)
   with _ ->
     error "invalid ref seq length" length sexp_of_string
  ) >>= fun length ->
  find01 `SQ tvl "AS" >>= fun assembly ->
  find01 `SQ tvl "M5" >>= fun md5 ->
  find01 `SQ tvl "SP" >>= fun species ->
  find01 `SQ tvl "UR" >>= fun uri ->
  assert_tags `SQ tvl ["SN";"LN";"AS";"M5";"SP";"UR"] >>= fun () ->
  ref_seq ~name ~length ?assembly ?md5 ?species ?uri ()

let parse_platform = function
  | "CAPILLARY" -> Ok `Capillary
  | "LS454" -> Ok `LS454
  | "ILLUMINA" -> Ok `Illumina
  | "SOLID" -> Ok `Solid
  | "HELICOS" -> Ok `Helicos
  | "IONTORRENT" -> Ok `Ion_Torrent
  | "PACBIO" -> Ok `Pac_Bio
  | x -> error "unknown platform" x sexp_of_string

let parse_read_group tvl =
  find1 `RG tvl "ID" >>= fun id ->
  find01 `RG tvl "CN" >>= fun seq_center ->
  find01 `RG tvl "DS" >>= fun description ->
  find01 `RG tvl "DT" >>= fun run_date ->
  find01 `RG tvl "FO" >>= fun flow_order ->
  find01 `RG tvl "KS" >>= fun key_seq ->
  find01 `RG tvl "LB" >>= fun library ->
  find01 `RG tvl "PG" >>= fun program ->
  find01 `RG tvl "PI" >>?~ (fun predicted_median_insert_size ->
  try Ok (Int.of_string predicted_median_insert_size)
  with _ ->
    error
      "invalid predicted median insert size"
      predicted_median_insert_size
      sexp_of_string
  ) >>= fun predicted_median_insert_size ->
  find01 `RG tvl "PL" >>?~
  parse_platform >>= fun platform ->
  find01 `RG tvl "PU" >>= fun platform_unit ->
  find01 `RG tvl "SM" >>= fun sample ->
  assert_tags `RG tvl
    ["ID";"CN";"DS";"DT";"FO";"KS";"LB";"PG";"PI";"PL";"PU";"SM"]
  >>= fun () ->
  read_group
    ~id ?seq_center ?description ?run_date ?flow_order ?key_seq
    ?library ?program ?predicted_median_insert_size
    ?platform ?platform_unit ?sample ()

let parse_program tvl =
  find1 `PG tvl "ID" >>= fun id ->
  find01 `PG tvl "PN" >>= fun name ->
  find01 `PG tvl "CL" >>= fun command_line ->
  find01 `PG tvl "PP" >>= fun previous_id ->
  find01 `PG tvl "DS" >>= fun description ->
  find01 `PG tvl "VN" >>= fun version ->
  assert_tags `PG tvl ["ID";"PN";"CL";"PP";"DS";"VN"] >>| fun () ->
  {id; name; command_line; previous_id; description; version}

let parse_header_item line =
  let parse_data tag tvl = match tag with
    | `HD -> parse_header_line tvl >>| fun x -> `HD x
    | `SQ -> parse_ref_seq tvl >>| fun x -> `SQ x
    | `RG -> parse_read_group tvl >>| fun x -> `RG x
    | `PG -> parse_program tvl >>| fun x -> `PG x
    | `Other tag -> Ok (`Other (tag,tvl))
    | `CO -> assert false
  in
  match String.lsplit2 ~on:'\t' (line : Line.t :> string) with
  | None ->
    error "header line contains no tabs" line Line.sexp_of_t
  | Some (tag, data) ->
    parse_header_item_tag tag >>= function
    | `CO -> Ok (`CO data)
    | tag ->
      match String.split ~on:'\t' data with
      | [] -> assert false
      | ""::[] ->
        error "header contains no data" tag sexp_of_header_item_tag
      | tvl ->
        Result.List.map tvl ~f:parse_tag_value >>= fun tvl ->
        parse_data tag tvl


(******************************************************************************)
(* Alignment Parsers and Constructors                                         *)
(******************************************************************************)
let alignment
    ?qname ~flags ?rname ?pos ?mapq ?(cigar=[])
    ?rnext ?pnext ?tlen ?seq ?(qual=[])
    ?(optional_fields=[])
    ()
    =
  Ok {
    qname; flags; rname; pos; mapq; cigar;
    rnext; pnext; tlen; seq; qual; optional_fields
  }

let parse_int_range field lo hi s =
  let out_of_range = sprintf "%s out of range" field in
  let not_an_int = sprintf "%s not an int" field in
  try
    let n = Int.of_string s in
    if (lo <= n) && (n <= hi) then
      Ok n
    else
      error out_of_range (n,lo,hi) <:sexp_of< int * int * int >>
  with _ ->
    error not_an_int s sexp_of_string

(** Parse a string that can either by "*" or some other regexp, with
    "*" denoting [None]. The given regexp [re] should include "*" as
    one of the alternatives. *)
let parse_opt_string field re s =
  if not (Re.execp re s) then
    error (sprintf "invalid %s" field) s sexp_of_string
  else
    match s with
    | "*" -> Ok None
    | _ -> Ok (Some s)

let qname_re =
  let open Re in
  alt [
    char '*';
    repn (alt [rg '!' '?'; rg 'A' '~']) 1 (Some 255);
  ]
  |> compile

let parse_qname s =
  parse_opt_string "QNAME" qname_re s

let parse_flags s =
  try Flags.of_int (Int.of_string s)
  with _ ->
    error "invalid FLAG" s sexp_of_string

let rname_re = Re_perl.compile_pat "^\\*|[!-()+-<>-~][!-~]*$"
let parse_rname s =
  parse_opt_string "RNAME" rname_re s

let parse_pos s =
  parse_int_range "POS" 0 2147483647 s >>| function
  | 0 -> None
  | x -> Some x

let parse_mapq s =
  parse_int_range "MAPQ" 0 255 s >>| function
  | 255 -> None
  | x -> Some x

let parse_cigar text =
  match text with
  | "*" -> Ok []
  | "" ->
    error "invalid cigar string" text sexp_of_string
  | _ ->
    let ch = Scanf.Scanning.from_string text in
    let rec loop accum =
      if Scanf.Scanning.end_of_input ch then Ok accum
      else
        try
          let n = Scanf.bscanf ch "%d" ident in
          if n < 0 then
            error "invalid cigar string" text sexp_of_string
          else
            let c = Scanf.bscanf ch "%c" ident in
            let x = match c with
              | 'M' -> `Alignment_match n
              | 'I' -> `Insertion n
              | 'D' -> `Deletion n
              | 'N' -> `Skipped n
              | 'S' -> `Soft_clipping n
              | 'H' -> `Hard_clipping n
              | 'P' -> `Padding n
              | '=' -> `Seq_match n
              | 'X' -> `Seq_mismatch n
              | other -> failwith ""
            in
            loop (x::accum)
        with
          _ ->
            error "invalid cigar string" text sexp_of_string
    in
    loop [] >>| List.rev

let rnext_re = Re_perl.compile_pat "^\\*|=|[!-()+-<>-~][!-~]*$"
let parse_rnext s =
  if not (Re.execp rnext_re s) then
    error "invalid RNEXT" s sexp_of_string
  else
    match s with
    | "*" -> Ok None
    | "=" -> Ok (Some `Equal_to_RNAME)
    | _ -> Ok (Some (`Value s))

let parse_pnext s =
  parse_int_range "PNEXT" 0 2147483647 s >>| function
  | 0 -> None
  | x -> Some x

let parse_tlen s =
  parse_int_range "TLEN" ~-2147483647 2147483647 s >>| function
  | 0 -> None
  | x -> Some x

let seq_re = Re_perl.compile_pat "^\\*|[A-Za-z=.]+$"
let parse_seq s =
  parse_opt_string "SEQ" seq_re s

let parse_qual s =
  match s with
  | "" -> Or_error.error_string "invalid empty QUAL"
  | "*" -> Ok []
  | _ ->
    String.to_list s
    |> Result.List.map ~f:(Phred_score.of_char ~offset:`Offset33)

let opt_field_tag_re = Re_perl.compile_pat "^[A-Za-z][A-Za-z0-9]$"
let opt_field_A_re = Re_perl.compile_pat "^[!-~]$"
let opt_field_Z_re = Re_perl.compile_pat "^[ !-~]+$"
let opt_field_H_re = Re_perl.compile_pat "^[0-9A-F]+$"
let opt_field_B_re =
  Re_perl.compile_pat "^[cCsSiIf](,[-+]?[0-9]*\\.?[0-9]+([eE][-+]?[0-9]+)?)+$"

let parse_optional_field s =
  match String.lsplit2 s ~on:':' with
  | None ->
    error "missing TAG in optional field" s sexp_of_string
  | Some (tag,s) ->
    if not (Re.execp opt_field_tag_re tag) then
      error "invalid TAG" tag sexp_of_string
    else
      match String.lsplit2 s ~on:':' with
      | None ->
        error "missing TYPE in optional field" s sexp_of_string
      | Some (typ,value) ->
        let err_val =
          error "invalid value" (typ,value) <:sexp_of< string * string >>
        in
        (
          match typ with
          | "A" ->
            if Re.execp opt_field_A_re value
            then Ok (`A value)
            else err_val
          | "i" ->
            (try Ok (`i (Int32.of_string value))
             with _ -> err_val)
          | "f" ->
            (try Ok (`f (Float.of_string value))
             with _ -> err_val)
          | "Z" ->
            if Re.execp opt_field_Z_re value
            then Ok (`Z value)
            else err_val
          | "H" ->
            if Re.execp opt_field_H_re value
            then Ok (`H value)
            else err_val
          | "B" -> (
            if not (Re.execp opt_field_B_re value) then
              err_val
            else
              match String.split ~on:',' value with
              | num_typ::values ->
                if String.length num_typ = 1 then
                  Ok (`B (num_typ.[0],values))
                else
                  error "invalid array type" num_typ sexp_of_string
              | _ -> assert false (* since opt_field_B_re matched *)
          )
          | _ -> error "invalid type" typ sexp_of_string
        )
        >>| fun value -> {tag; value}

let parse_optional_fields sl =
  Result.List.map sl ~f:parse_optional_field

let parse_alignment line =
  match String.split ~on:'\t' (line : Line.t :> string) with
  | qname::flags::rname::pos::mapq::cigar::rnext
    ::pnext::tlen::seq::qual::optional_fields
    -> (
      parse_qname qname >>= fun qname ->
      parse_flags flags >>= fun flags ->
      parse_rname rname >>= fun rname ->
      parse_pos pos >>= fun pos ->
      parse_mapq mapq >>= fun mapq ->
      parse_cigar cigar >>= fun cigar ->
      parse_rnext rnext >>= fun rnext ->
      parse_pnext pnext >>= fun pnext ->
      parse_tlen tlen >>= fun tlen ->
      parse_seq seq >>= fun seq ->
      parse_qual qual >>= fun qual ->
      parse_optional_fields optional_fields >>= fun optional_fields ->
      alignment
        ?qname ~flags ?rname ?pos ?mapq ~cigar
        ?rnext ?pnext ?tlen ?seq ~qual ~optional_fields
        ()
    )
  | _ ->
    Or_error.error_string "alignment line contains < 12 fields"


(******************************************************************************)
(* Main Item Parser                                                           *)
(******************************************************************************)
let parse_item line =
  if String.length (line : Line.t :> string) = 0 then
    Or_error.error_string "invalid empty line"
  else if (line : Line.t :> string).[0] = '@' then
    parse_header_item line >>| fun x -> `Header_item x
  else
    parse_alignment line >>| fun x -> `Alignment x


(******************************************************************************)
(* Input/Output                                                               *)
(******************************************************************************)
module MakeIO(Future : Future.S) = struct
  open Future
  module Lines = Biocaml_lines.MakeIO(Future)

  let read ?(start=Pos.(incr_line unknown)) r =
    let init_hdr = {
      version = None;
      sort_order = None;
      ref_seqs = [];
      read_groups = [];
      programs = [];
      comments = [];
      others = [];
    }
    in
    let lines = Pipe.map (Lines.read r) ~f:parse_item in
    let rec loop hdr : header Or_error.t Deferred.t =
      Pipe.peek_deferred lines >>= (function
      | `Ok (Error _ as e) -> return e
      | `Eof
      | `Ok (Ok (`Alignment _)) -> return (Ok hdr)
      | `Ok (Ok (`Header_item x)) ->
        Pipe.junk lines >>= fun () -> match x with
        | `HD ({version; sort_order} : header_line) -> (
          match hdr.version with
          | Some _ ->
            return (Or_error.error_string "multiple @HD lines not allowed")
          | None ->
            loop {hdr with version = Some version; sort_order}
        )
        | `SQ x -> loop {hdr with ref_seqs = x::hdr.ref_seqs}
        | `RG x -> loop {hdr with read_groups = x::hdr.read_groups}
        | `PG x -> loop {hdr with programs = x::hdr.programs}
        | `CO x -> loop {hdr with comments = x::hdr.comments}
        | `Other x -> loop {hdr with others = x::hdr.others}
      )
    in
    loop init_hdr >>= function
    | Error _ as e -> return e
    | Ok {version; sort_order; ref_seqs; read_groups; programs; comments} ->
      header ?version ?sort_order ~ref_seqs ~read_groups ~programs ~comments ()
      |> function
         | Error _ as e -> return e
         | Ok hdr ->
           let alignments = Pipe.map lines ~f:(function
             | Error _ as e -> e
             | Ok (`Alignment x) -> Ok x
             | Ok (`Header_item _) ->
               Or_error.error_string
                 "header line occurs after start of alignments"
           )
           in
           return (Ok (hdr, alignments))


  let read_file ?buf_len file =
    let start = Pos.make ~source:file ~line:1 () in
    Reader.open_file ?buf_len file >>= (read ~start)


  let read_items ?(start=Pos.(incr_line unknown)) r =
    let pos = ref start in
    Lines.read r
    |> Pipe.map ~f:(fun line ->
      let item =
        parse_item line
        |> fun x -> Or_error.tag_arg x "position" !pos Pos.sexp_of_t
      in
      pos := Pos.incr_line !pos;
      item
    )

  let read_items_file ?buf_len file =
    let start = Pos.make ~source:file ~line:1 () in
    Reader.open_file ?buf_len file >>| (read_items ~start)

end
include MakeIO(Future_std)
