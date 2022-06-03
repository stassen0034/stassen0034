#!/bin/bash
crtname=$1

openssl x509 -noout -text -in ${crtname} | grep "Not Before"
openssl x509 -noout -text -in ${crtname} | grep "Not After"
openssl x509 -noout -text -in ${crtname} | grep "DNS"
