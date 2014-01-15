OPAM_DEPENDS="ocamlfind core.$CORE_VERSION camlzip xmlm pcre-ocaml cfstream omake lwt flow async"

case "$OCAML_VERSION,$OPAM_VERSION" in
3.12.1,1.0.0) ppa=avsm/ocaml312+opam10 ;;
3.12.1,1.1.0) ppa=avsm/ocaml312+opam11 ;;
4.00.1,1.0.0) ppa=avsm/ocaml40+opam10 ;;
4.00.1,1.1.0) ppa=avsm/ocaml40+opam11 ;;
4.01.0,1.0.0) ppa=avsm/ocaml41+opam10 ;;
4.01.0,1.1.0) ppa=avsm/ocaml41+opam11 ;;
*) echo Unknown $OCAML_VERSION,$OPAM_VERSION; exit 1 ;;
esac

echo "yes" | sudo add-apt-repository ppa:$ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
export OPAMYES=1
export OPAMVERBOSE=1
echo OCaml version
ocaml -version
echo OPAM versions
opam --version
opam --git-version

opam init 

opam remote add biorepo git://github.com/biocaml/dev-opam-repo.git
opam update
opam pin flow git://github.com/smondet/flow

echo "==== Installing $OPAM_DEPENDS ===="
opam install ${OPAM_DEPENDS}

eval `opam config env`
echo "==== Build ===="
omake
echo "==== Test ===="
omake run_tests
echo "==== Bench ===="
_build/benchmarks/biocaml_benchmarks -help
echo "==== Doc ===="
omake doc

