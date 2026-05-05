JUST_VARS=$(eval just --evaluate | awk '{print "export "$1"="$3}')

for var in ${JUST_VARS}; do
	echo ${var}
	eval ${var}
done
