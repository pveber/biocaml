type genome = [`mm9]

val string_of_genome : genome -> string

module Url : sig
  val chromosomes : genome -> string
end
