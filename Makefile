
URL := $(shell pbpaste)
OLD_URL := $(strip $(shell cat url.txt))

ifneq "$(URL)" "$(OLD_URL)"
    var := $(shell pbpaste > url.txt)
endif


out.pdf: texput.pdf
	booklet.rb -p half texput.pdf

texput.pdf: texput.tex
	xelatex texput

texput.tex: url.txt
	./scholar2tex.rb "`cat url.txt`" > texput.tex


