open Utils

type cmd

val cmd : output:path -> treatment:path -> cmd

val xls_output : cmd -> path
val bed_output : cmd -> path
val rprogram_output : cmd -> path



