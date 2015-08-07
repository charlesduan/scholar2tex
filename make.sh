#!/bin/sh

./scholar2tex.rb "$@" > texput.tex
xelatex texput
booklet.rb -p half texput.pdf
