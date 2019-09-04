#!/bin/bash

# Settings to improve accessibility of dialog.
export DIALOGOPTS='--insecure --no-lines --visit-items'

msgbox() {
# Returns: None
# Shows the provided message on the screen with an ok button.
dialog --clear --msgbox "$*" 10 72
}

infobox() {
    # Returns: None
    # Shows the provided message on the screen with no buttons.
   local timeout=3 
    dialog --infobox "$*" 0 0
    read -n1 -t $timeout continue
    # Clear any keypresses from the buffer
    read -t 0.01 continue
}

yesno() {
    # Returns: Yes or No
    # Args: Question to user.
    # Called  in if $(yesno) == "Yes"
    # Or variable=$(yesno)
    dialog --clear --backtitle "$(gettext "Press 'Enter' for \"yes\" or 'Escape' for \"no\".")" --yesno "$*" 10 80 --stdout
    if [[ $? -eq 0 ]]; then
        echo "Yes"
    else
        echo "No"
    fi
}

# variables
WorkSpacePath="$(mktemp -d)/"
currentDir="$(pwd)"
filename="${1##*/}"
maxsize=5

# dont continue on error
set -e

checkRequirements() {
    # Add requirements to the array
    local requirements=(
        tesseract
        pdftotext
        convert
        pdftotext
        awk
    )
    for i in "${requirements[@]}" ; do
        if ! command -v "$i" &> /dev/null ; then
            infobox "$(gettext "You are missing the required package:") $i"
            exit 1
        fi
    done
}

initWorkSpace () {
    echo "Prepare workspace $WorkSpacePath"
    cp "$1" "$WorkSpacePath/"
}
clearWorkSpace() {
    rm "${WorkSpacePath:?}/*" 2> /dev/null
    cp "$1" "$WorkSpacePath"
}

cleanupWorkSpace () {
    if [ -d "$WorkSpacePath" ];
    then
        rm -r "${WorkSpacePath:?}"
    fi
}

cleanupFile() {
    local ret="$(awk '!NF {if (++n <= 2) print; next}; {n=0;print}' $1)"
    echo "$ret"
}

extractPDFFile () {
    (clearWorkSpace "$1";
    local content="$(pdftotext -layout "$WorkSpacePath/$filename" "${WorkSpacePath}/complete.txt")";) \
        | dialog --clear --programbox "$(gettext "Text extraction in progress...")" 0 0
}

OCRFile () {
    (clearWorkSpace "$1";
    convert -density 600 "$WorkSpacePath$filename" "${WorkSpacePath}/Seite.png";
    rm "${WorkSpacePath}/${filename}";
    for i in "$(ls -v "$WorkSpacePath" | grep .png)" ;
    do
        echo "OCRed $i"
        tesseract "$WorkSpacePath$i" "$WorkSpacePath"output -l deu+eng --oem 0 &> /dev/null
        cat "$WorkSpacePath"output.txt >> "$WorkSpacePath"complete.txt
        rm "$WorkSpacePath"output.txt
    done) | dialog --clear --programbox "$(gettext "Text extraction in progress...")" 0 0
}

proceed () {
    checkRequirements
    initWorkSpace $1
    filesize=0
    if [ $(head -c 4 "$1") = "%PDF" ];
    then
        extractPDFFile $1
        awk '{gsub(/\x0c/,"");print}' "$WorkSpacePath"complete.txt > "$WorkSpacePath"len.txt
        filesize=$(stat -c%s "$WorkSpacePath"len.txt)
    fi
    
    if (( $filesize < $maxsize ));
    then
        OCRFile $1
    fi

    cleanupFile "$WorkSpacePath"complete.txt > $filename.txt

    cleanupWorkSpace

    echo "File saved: $filename.txt"
}

# Setup gettext
export TEXTDOMAIN=extractText.sh
export TEXTDOMAINDIR=/usr/share/locale
. gettext.sh

proceed $1

exit 0
