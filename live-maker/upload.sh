#! /bin/bash
echo " Remenber install and login

curl -LsSf https://hf.co/cli/install.sh | bash


hf auth login
"
dir="upload"
sv="arepaconcafe/neko-base"
mkdir -p $dir &&
mv *.iso $dir &&
mv *.txt $dir &&
cd $dir &&
hf upload $sv .

