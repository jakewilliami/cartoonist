#!/bin/bash

trap "exit" INT

B_WHITE="\033[1;38m"
IT_WHITE="\033[0;3;38m"
ULINE="\033[1;4m"
B_BLUE="\033[1;34m"
B_YELLOW="\033[1;33m"
COL_RESET="\033[0;38m"

columnise() {
    tablength=$1;
    indent=$2;
    value="$4";
    fullindent=$(($(tput cols)-indent-tablength));
    tabindent=$((indent+tablength));
    firstline=0;
    while read -r line; do
        if [[ "${firstline}" -eq 0 ]]; then
            keyname="$3"
            firstline=1
        else
            keyname=" "
        fi
        printf "%-${tablength}s${B_BLUE}%-${indent}b${COL_RESET}${B_YELLOW}%b${COL_RESET}\n" "" "${keyname}" "${line}"
    done <<< "$(fold -w${fullindent} -s <<< "$value")"
}


show_help() {
    TAB_LENGTH=4
    INDENT_LENGTH=25
    printf "%b\n" "${B_WHITE}Usage: gl [option...]${COL_RESET}"
    printf "\n"
    printf "%b\n" "${IT_WHITE}The present script will convert photo of a hand drawing into an SVG/PDF vector file.  Omitting all options will create PDFs, PNGs, and SVGs.  You can use options to narrow your output (see below).  For more information see the README.md file.${COL_RESET}"
    printf "\n"
    # printf "\t%-35b%-30b\n " "${B_BLUE}-t | --threshold${COL_RESET}" "${B_YELLOW}Sets the contrast ${COL_RESET}${ULINE}${B_BLUE}t${COL_RESET}${ULINE}${B_YELLOW}hreshold${COL_RESET}${B_YELLOW} of the image (i.e., lighter lines will be registered as darker).  This is an integer between 1 and 10, and defaults to 5.${COL_RESET}"
    columnise $TAB_LENGTH $INDENT_LENGTH "-t | --threshold" "Sets the contrast threshold of the image (i.e., lighter lines will be registered as darker).  This is an integer between 1 and 10, and defaults to 5."
    # columnise 4 30 "${B_BLUE}-t | --threshold${COL_RESET}" "${B_YELLOW}Sets the contrast ${COL_RESET}${ULINE}${B_BLUE}t${COL_RESET}${ULINE}${B_YELLOW}hreshold${COL_RESET}${B_YELLOW} of the image (i.e., lighter lines will be registered as darker).  This is an integer between 1 and 10, and defaults to 5.${COL_RESET}"
    columnise $TAB_LENGTH $INDENT_LENGTH "-i | --inverted" "Outputs only the inverted files."
    columnise $TAB_LENGTH $INDENT_LENGTH "-n | --normal" "Outputs only the files that are not inverted."
    columnise $TAB_LENGTH $INDENT_LENGTH "-P | --pdf" "Outputs only the PDF files."
    columnise $TAB_LENGTH $INDENT_LENGTH "-s | --svg" "Outputs only the SVG files."
    columnise $TAB_LENGTH $INDENT_LENGTH "-p | --png" "Outputs only the PNG files."
    columnise $TAB_LENGTH $INDENT_LENGTH "-h | --help" "Displays help (present output)."
    
    # echo -e "\t${B_BLUE}-p | --pdf\t\t${COL_RESET}${B_YELLOW}Ouputs only the ${COL_RESET}${ULINE}${B_BLUE}p${COL_RESET}${ULINE}${B_YELLOW}df${COL_RESET}${B_YELLOW} files.${COL_RESET}"
    # echo -e "\t${B_BLUE}-s | --svg\t\t${COL_RESET}${B_YELLOW}Ouputs only the ${COL_RESET}${ULINE}${B_BLUE}s${COL_RESET}${ULINE}${B_YELLOW}vg${COL_RESET}${B_YELLOW} files.${COL_RESET}"
    # echo -e "\t${B_BLUE}-n | --png\t\t${COL_RESET}${B_YELLOW}Ouputs only the ${COL_RESET}${ULINE}${B_YELLOW}p${COL_RESET}${ULINE}${B_BLUE}n${COL_RESET}${ULINE}${B_YELLOW}g${COL_RESET}${B_YELLOW} files.${COL_RESET}"
    # echo -e "\t${B_BLUE}-h | --help\t\t${COL_RESET}${B_YELLOW}${COL_RESET}${ULINE}${B_BLUE}${COL_RESET}${ULINE}${B_YELLOW}${COL_RESET}${B_YELLOW}${COL_RESET}"
    exit
}

opt_err() { #Invalid option (getopts already reported the illegal option)
    printf "%b\n" "${B_YELLOW}Not a valid option.  Use -h for help.${COL_RESET}"
    exit
}

get_source_file() {
    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"

    # Input File
    in_file="$1"

    dir=$(dirname "$in_file")
    in_basename=$(basename "$in_file")

    name="${in_basename%%.*}"
    in_ext="${in_basename#*.}"

    # Output File
    out="$dir/$name"
}

main() {
    # Threshold
    "$src_dir/lib/localthresh" -m 1 -r 65 -b 5 -n yes "$in_file" "$out.png"
    "$src_dir/lib/isonoise" -r 3 "$out.png" "$out.png"
    
    # Vectors
    convert "$out.png" "$out.pnm"
}

get_pdf() {
    potrace "$out.pnm" -b pdf -o "$out.pdf" --tight
    potrace "$out.pnm" -b pdf -o "$out-i.pdf" --color '#FFFFFF' --tight
}

get_svg() {
    potrace "$out.pnm" --svg -o "$out.svg" --tight
    potrace "$out.pnm" --svg -o "$out-i.svg" --color '#FFFFFF' --tight
}

get_png() {
    # PNGs
    "$src_dir/lib/color2alpha" -ca white "$out.png" "$out.png"
    convert "$out.png" -negate "$out-i.png"
}

rm_temp() {
    rm "$out.pnm"
}

rm_temp_png() {
    rm $out.png
}

mk_all() {
    get_source_file "$1"
    main
    get_pdf
    get_svg
    rm_temp
    get_png
}

mk_inverted() {
    mk_all "$1"
    for out_file in $out*
    do
        if ! [[ "$out_file" =~ $out-i\.* ]]
        then
            # skip original image!!
            [[ "$1" == "$out_file" ]] && continue
            # remove non-inverted files
            rm "$out_file"
        fi
    done
}

mk_norm() {
    mk_all "$1"
    for out_file in $out*
    do
        # remove inverted files
        [[ "$out_file" =~ $out-i\.* ]] && \
            rm "$out_file"
    done
}

mk_pdf() {
    get_source_file "$1"
    main
    get_pdf
    rm_temp
    rm_temp_png
}

mk_png() {
    get_source_file "$1"
    main
    get_png
    rm_temp
}

mk_svg() {
    get_source_file "$1"
    main
    get_svg
    rm_temp
    rm_temp_png
}

# portable way of getting the last argument passed to the script
for ARG in $@; do :; done
OPTION_FILE_ARG="$ARG"

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
# Options
while getopts ":-:htpnsiP" OPTION
do
    case $OPTION in
        -)  # Long options for bash (without GNU)
            case $OPTARG in
                help)
                    show_help ;;
                threshold)
                    ;;
                pdf)
                    mk_pdf "${OPTION_FILE_ARG}" ;;
                png)
                    mk_png "${OPTION_FILE_ARG}" ;;
                svg)
                    mk_svg "${OPTION_FILE_ARG}" ;;
                inverted)
                    mk_inverted "${OPTION_FILE_ARG}" ;;
                Normal)
                    mk_norm "${OPTION_FILE_ARG}" ;;
                *)
                    opt_err ;;
            esac ;;
        h)
            show_help ;;
        t)
            ;;
        P)
            mk_pdf "${OPTION_FILE_ARG}" ;;
        p)
            mk_png "${OPTION_FILE_ARG}" ;;
        s)
            mk_svg "${OPTION_FILE_ARG}" ;;
        i)
            mk_inverted "${OPTION_FILE_ARG}" ;;
        n)
            mk_norm "${OPTION_FILE_ARG}" ;;
        *)
            opt_err ;;
    esac
done
shift $((OPTIND-1))
# [ "${1:-}" == "--" ] && shift

# default function for no options passed
if [[ $OPTIND -eq 1 ]]; then
    mk_all "$1"
fi
