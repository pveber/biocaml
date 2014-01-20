open Core.Std
open CFStream

let ( >>= ) = Lwt.( >>= )
let stream_length xs = Stream.fold xs ~init:0 ~f:(fun accu _ -> accu + 1)
let lwt_stream_length xs = Lwt_stream.fold (fun _ accu -> accu + 1) xs 0

let main input_file () =
  let open Biocaml in
  let time f x =
    let start = Time.(now () |> to_float) in
    let y = f x in
    let stop = Time.(now () |> to_float) in
    (y, stop -. start)
  in
  let future_blocking f =
    In_channel.with_file f ~f:(fun ic ->
      stream_length (Biocaml_fastq.get ic)
    )
  in
  let transform_blocking f =
    In_channel.with_file f ~f:(fun ic ->
      stream_length (Biocaml_fastq.in_channel_to_item_stream_exn ic)
    )
  in
  let future_lwt f =
    let t =
      Lwt_io.(with_file ~mode:input f (fun io ->
	lwt_stream_length (Biocaml_lwt.Fastq.get io)
      ))
    in
    Lwt_main.run t
  in
  let transform_lwt f =
    let transfo = Biocaml_fastq.Transform.string_to_item () in
    let c = ref 0 in
    let t =
      Lwt_io.(with_file ~mode:input f (fun ic ->
	let rec put_in_stream stopped =
          match Biocaml_transform.next transfo with
          | `output (Ok s) ->
            incr c ;
            put_in_stream stopped
          | `end_of_stream ->
	    Lwt.return ()
          | `not_ready ->
            if stopped then put_in_stream stopped else Lwt.return ()
          | `output (Error _) -> assert false
        in

	let rec loop () =
	  read ic >>= fun read_string ->
	  if read_string = "" then (
            Biocaml_transform.stop transfo ;
	    put_in_stream true
	  )
	  else (
	    Biocaml_transform.feed transfo read_string ;
	    put_in_stream false >>= fun () ->
	    loop ()
	  )
	in
	loop ()
      ))
    in
    Lwt_main.run t ;
    !c
  in
  let results =
    let s_fb, t_fb = time future_blocking input_file in
    let s_tb, t_tb = time transform_blocking input_file in
    let s_fl, t_fl = time future_lwt input_file in
    let s_tl, t_tl = time transform_lwt input_file in

    assert (s_fb = s_tb) ;
    assert (s_fb = s_fl) ;
    assert (s_fl = s_tl) ;
    [
      "Blocking", t_tb, t_fb ;
      "Lwt", t_tl, t_fl ;
    ]
  in
  printf "\n\n";
  printf "Input size: %d\n" 0 ;
  printf "  Thread      Transform      Future   \n" ;
  printf "----------  -------------  ---------- \n" ;
  List.iter results ~f:(fun (thread, transform, future) ->
    printf "% 10s  % 10.2f  %  10.2f\n" thread transform future
  )

let command =
  let open Command in
  basic ~summary:"Benchmark Transform and Future-style FASTQ read"
    Spec.(
      empty +> (anon ("INPUT_FILES" %: string))
    )
    main




