include module type of Biocaml_internal_pervasives
open Async.Std

module Future_async : Future.S
  with type 'a Deferred.t = 'a Deferred.t
  and type 'a Pipe.Reader.t = 'a Pipe.Reader.t
  and type Reader.t = Reader.t
