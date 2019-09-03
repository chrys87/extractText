#!/bin/sh
echo "Bereite Arbeitsverzeichnis in Unterordner tempOcrText vor"
rm -r tempOcrText &> /dev/null
mkdir tempOcrText
cp $1 ./tempOcrText/ 
cd tempOcrText
echo "Zerlege PDF in ein Bild Pro Seite"
convert -density 300 $1 Seite.png
echo "OCR Vorgang Läuft"
for i in `ls -v | grep .png`;
do
        echo "OCR $i"
	tesseract $i output -l deu+eng --oem 0 &> /dev/null
        cat output.txt >> fertig2.txt
	rm output.txt
done
echo "Bereinige Zieldatei"
awk '!NF {if (++n <= 2) print; next}; {n=0;print}' fertig2.txt > ../$1.txt
echo "Räume auf"
cd ..
rm -r tempOcrText
echo "Fertig: gespeichert in $1.txt"
