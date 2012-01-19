open Utils

type cmd = {
  name : string ; 
  format : string option;
  pvalue : string option;
  mfold : (int32 * int32) option;
  tsize : int32 option;
  gsize : string option;
  bw : int32 option;
  wig : bool option;
  space : int32 option;
  control : string option;
  treatment : string;
}

let cmd ~output ~treatment = {
  name = absolute_path output ;
  format = None ;
  pvalue = None ;
  mfold = None ;
  tsize = None ;
  gsize = None ;
  bw = None ;
  wig = None ;
  space = None ;
  control = None ;
  treatment = absolute_path treatment
}

let xls_output cmd = assert false
let bed_output cmd = assert false
let rprogram_output cmd = assert false

  

