open Biocaml_lwt_internal_pervasives

module Fastq = struct
  include Biocaml_fastq
  include Make(Future_lwt)
end
