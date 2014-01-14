include module type of Biocaml_internal_pervasives
include module type of Lwt

module Future_lwt : Future.S
  with type 'a Deferred.t = 'a Lwt.t
  and type 'a Pipe.Reader.t = 'a Lwt_stream.t
  and type Reader.t = Lwt_io.input_channel
