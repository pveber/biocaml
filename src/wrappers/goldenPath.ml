open Printf

type genome = [`mm9]

let string_of_genome = function
  | `mm9 -> "mm9"

module Url = struct
  let chromosomes org = 
    sprintf "ftp://hgdownload.cse.ucsc.edu/goldenPath/%s/chromosomes/" (string_of_genome org)
end
