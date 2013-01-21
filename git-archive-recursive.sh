#!/bin/bash
#---------------- functions ----------------
function do_or_die {
	"$@"
	status=$?
	if [ $status -ne 0 ]; then
		echo "Error executing $1" 1>&2
		exit $?
	fi
	return $status
}

function read_one_level () {
	export GIT_ALTERNATE_OBJECT_DIRECTORIES="$GIT_ALTERNATE_OBJECT_DIRECTORIES":$(
		git submodule foreach '
			if [ -d "$up/$path/.git" ]; then
				echo "$up/$path/.git/objects"
			else
				DIR=`cat "$up/$path/.git" | sed "s/gitdir:[[:space:]]*//"`
				DIR="$up/$path/$DIR/objects"
				DIR=`cd -P -- "$(dirname -- "$DIR")" && echo "$(pwd -P)/$(basename -- "$DIR")"`
				echo $DIR
			fi
		' |
		grep -E -v '^(Entering|No submodule mapping found)' |
		tr '\n' : |
		sed 's/:$//'
	)
	echo "DEBUG $GIT_ALTERNATE_OBJECT_DIRECTORIES" 1>&2
	
	do_or_die git submodule --quiet foreach '
		cd "$toplevel"
		subcommit=$(git rev-parse :"$path")
		echo "DEBUG Subcommit for $path in $toplevel: $subcommit" 1>&2
		git read-tree -i --prefix="$path/" $subcommit
		if [ $? -eq 0 ]; then
			echo "git rm --cached $path"
		else
			echo "ERROR Failed to export tree" 1>&2
		fi
	'
}

#---------------- main code ----------------
revision="$1"
if [ "$revision" == "" ]; then
	revision="HEAD"
fi
up="$2"
if [ "$up" == "" ]; then
	up="$(pwd)"
fi

export revision
export GIT_INDEX_FILE=".git/tmpindex"
export up

echo "INFO revision: $revision directory: $up" 1>&2

rm -f "$GIT_INDEX_FILE"

git read-tree $revision

while git ls-files -s | grep -q ^160000; do
	echo "INFO Read level: $up" 1>&2
	read_one_level
done

git archive --format=zip $(git write-tree)

rm -f "$GIT_INDEX_FILE"