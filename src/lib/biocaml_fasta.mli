(** FASTA files.

    The FASTA family of file formats has different incompatible descriptions
    ({{:https://www.proteomecommons.org/tranche/examples/proteomecommons-fasta/fasta.jsp
    }1},
    {{:http://zhanglab.ccmb.med.umich.edu/FASTA/}2},
    {{:http://en.wikipedia.org/wiki/FASTA_format}3}, etc.).
    
    Roughly FASTA files are in the format:

    {v
    # comment
    # comment
    ...
    >header
    sequence
    >header
    sequence
    ...
    v}

    where the sequence may span multiple lines, and a ';' may be used
    instead of '#' to start comments.
    
    Header lines begin with the '>' character. It is often considered
    that all characters until the first whitespace define the {i name}
    of the content, and any characters beyond that define additional
    information in a format specific to the file provider.
    
    Sequence are most often a sequence of characters denoting
    nucleotides or amino acids. However, sometimes FASTA files provide
    quality scores, either as ASCII encoded, e.g. as supported by
    modules {!module: Biocaml_phred_score} and {!module:
    Biocaml_solexa_score}, or as space-separated integers.

    Thus, the FASTA format is really a family of formats with a fairly
    loose specification of the header and content formats. The only
    consistently followed meaning of the format is:

    - the file can begin with comment lines that begin with a '#' or
    ';' character and/or all white-space lines

    - the header lines begins with the '>' character, is followed
    optionally by whitespace, and then contains some string

    - each header line is followed by a sequence of characters or
    space-separated integers, often just one line but allowed to span
    multiple lines

    - and this alternating pair of header/sequence lines can occur
    repeatedly.
*)

module Error : sig

  type string_to_item = [
  | `empty_line of Biocaml_pos.t
  | `incomplete_input of Biocaml_pos.t * string list * string option
  | `malformed_partial_sequence of string
  ]
  with sexp

  type t = [
    string_to_item
  | `unnamed_sequence of string
  | `unnamed_scores of int list
  ]
  with sexp

end

module Exceptionful : sig
  exception Error of Error.t

  val sequence_stream_of_in_channel :
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    in_channel ->
    (string * string) Stream.t
      (** [sequence_stream_of_file file] returns a stream of [(name,
          sequence)] pairs. Initial comments are not provided. @raise
          Failure in case of any errors. *)

  val score_stream_of_in_channel :
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    in_channel ->
    (string * int list) Stream.t
      (** [score_stream_of_file file] returns a stream of [(name,
          scores)] pairs. Initial comments are not provided. @raise
          Failure in case of any errors. *)

end


(** {6 Low-level API} *)

module Transform: sig

    

  type 'a item = [
  | `comment of string
  | `header of string
  | `partial_sequence of 'a
  ]
  with sexp
  (** Lowest level items parsed by this module:
      
      - [`comment _] - a single comment line without the final newline
      
      - [`header _] - a single header line without the initial '>',
      whitespace following this, nor final newline
      
      - [`partial_sequence _] - Either a sequence of characters, represented as a
      string, or a sequence of space separated integers, represented by
      an [int list]. The value does not necessarily carry the complete
      content associated with a header. It may be only part of the
      sequence, which can be useful for files with large sequences
      (e.g. genomic sequence files). *)

  val string_to_sequence_item:
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    unit ->
    (string, (string item, Error.t) Core.Result.t) Biocaml_transform.t
  (** Parse a stream of strings as a sequence FASTA file.
      The [filename] is used only for error messages. If [pedantic] is
      [true] (default) the parser will report more errors
      (Biocaml_transform.no_error lines, non standard characters). The
      comment format is set with [sharp_comments] and/or
      [semicolon_comments]. *)

  val string_to_score_item:
    ?filename:string ->
    ?pedantic:bool ->
    ?sharp_comments:bool ->
    ?semicolon_comments:bool ->
    unit ->
    (string, (int list item, Error.t) Core.Result.t) Biocaml_transform.t
  (** Parse a stream of strings as a sequence FASTA file.
      See [sequence_parser]. *)

  val sequence_item_to_string:
    ?comment_char:char ->
    unit ->
    (string item, string) Biocaml_transform.t
  (** Print sequences. If [comment_char] is [None] comments will be ignored. *)
      
  val score_item_to_string:
    ?comment_char:char ->
    unit ->
    (int list item, string) Biocaml_transform.t
  (** Print scores. If [comment_char] is [None] comments will be ignored. *)
      
  val sequence_item_to_aggregated:
    unit -> 
    (string item,
     (string * string, [ `unnamed_sequence of string ]) Core.Result.t)
      Biocaml_transform.t
  (** Aggregate a stream of FASTA [string item] into a [(name, sequence)] stream.
      The error [`unnamed_sequence _] means that the file did start with
      the name of a sequence. *)

  val score_item_to_aggregated:
    unit -> 
    (int list item,
     (string * int list, [ `unnamed_sequence of int list ]) Core.Result.t)
      Biocaml_transform.t
  (** Like [sequence_aggregator] but for [int list item]. *)

  val aggregated_to_sequence_item: ?line_width:int -> unit ->
    (string * string, string item) Biocaml_transform.t
  (** Cut a stream of [(name, sequence)] into a stream of [string item]
      where line are cut at [line_width] characters (default 80). *)

  val aggregated_to_score_item: ?group_by:int -> unit ->
    (string * int list, int list item) Biocaml_transform.t
(** Cut a stream of [(name, scores)] into a stream of [int list item]
    where lists are cut at [group_by] numbers (default 10). *)
end

