#!/bin/bash

#To be executed from wrekavoc root path

OUTPUTFILE="doc/netapi/index.html"
INPUTFILE="doc/netapi/documentation.html"
CSSFILE="../../files/stylesheets/netapi/layout.css"

rake doc_netapi
cat <<EOF > $OUTPUTFILE
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <link href="${CSSFILE}" rel="stylesheet" type="text/css">
  </head>
  <body>
EOF
cat $INPUTFILE >> $OUTPUTFILE
echo "</body></html>" >> $OUTPUTFILE
