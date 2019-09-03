#!/bin/bash

# variables
WorkSpacePath=$(mktemp -d)/
currentDir=$(pwd)
filename=$(basename -- "$1")
maxsize=5

# dont continue on error
set -e

checkRequirements() {
    # tesseract
    if ! reqiredCommand="$(type -p "tesseract")" || [[ -z $reqiredCommand ]];
    then
        echo 'Error: tesseract is not installed.' >&2
        exit 1
    fi
    # pdftotext
    if ! reqiredCommand="$(type -p "pdftotext")" || [[ -z $reqiredCommand ]];
    then
        echo 'Error: pdftotext is not installed.' >&2
        exit 1
    fi
    if ! reqiredCommand="$(type -p "convert")" || [[ -z $reqiredCommand ]];
    then
        echo 'Error: ImageMagick (convert) is not installed.' >&2
        exit 1
    fi
    if ! reqiredCommand="$(type -p "awk")" || [[ -z $reqiredCommand ]];
    then
        echo 'Error: awk is not installed.' >&2
        exit 1
    fi
}

initWorkSpace () {
    echo "Bereite Arbeitsverzeichnis in $WorkSpacePath vor"
    cleanupWorkSpace
    mkdir $WorkSpacePath
    cp $1 $WorkSpacePath
}
cleanupWorkSpace () {
    if [ -d "$WorkSpacePath" ];
    then
        echo "Räume auf"
        rm -r $WorkSpacePath
    fi
}

cleanupFile() {
    local ret=$(awk '!NF {if (++n <= 2) print; next}; {n=0;print}' $1)
    echo $ret
}

extractFile () {
    echo "extract Prozess"
    initWorkSpace $1
    local content=$(pdftotext -layout "$WorkSpacePath$filename" "$WorkSpacePath"output.txt)
    awk '{gsub(/\x0c/,"");print}' "$WorkSpacePath"output.txt > "$WorkSpacePath"complete.txt
}

OCRFile () {
    echo "OCR Prozess"
    initWorkSpace $1
    echo "Zerlege PDF in ein Bild Pro Seite"
    convert -density 300 "$WorkSpacePath$filename" "$WorkSpacePath"Seite.png
    rm "$WorkSpacePath$filename"
    echo "OCR Vorgang Läuft"
    for i in `ls -v $WorkSpacePath | grep .png`;
    do
        echo "OCR $i"
        tesseract "$WorkSpacePath$i" "$WorkSpacePath"output -l deu+eng --oem 0 &> /dev/null
        cat "$WorkSpacePath"output.txt >> "$WorkSpacePath"complete.txt
        rm "$WorkSpacePath"output.txt
    done
}

checkRequirements
extractFile $1

filesize=$(stat -c%s "$WorkSpacePath"complete.txt)
if (( $filesize < $maxsize ));
then
    echo "inhalt nicht extrahierbar"
    OCRFile $1
fi

cleanupFile "$WorkSpacePath"complete.txt > $filename.txt

cleanupWorkSpace

echo "Fertig: gespeichert in $filename.txt"
