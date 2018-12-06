sources = ${wildcard *.php}
headers = ${wildcard common/*.php}
targets = $(sources:.php=.php.html)
post_script = common/_post.php

all: ${targets}

${targets} : %.php.html : %.php ${headers}
	echo generating $@
	php -c . ${post_script} "$<" > "$@"

clean:
	rm -f *.html

.PHONY: all clean
.DELETE_ON_ERROR:
