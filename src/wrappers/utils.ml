type path = string

let absolute_path p =
  if Filename.is_relative p then 
    (Sys.getcwd ()) ^ "/" ^ p
  else p
