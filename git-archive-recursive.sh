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
	export git_idx=$GIT_INDEX_FILE
	echo "INFO Add submodules to index" 1>&2
	
	do_or_die git submodule --quiet foreach '
		echo "DEBUG Subcommit for $path in $toplevel $sha1" 1>&2
		#
		# Make sure we have the right git index file selected, and the
		# object search path is manually set. This is needed because the
		# `git submodule foreach` loop resets these environment variables
		#
		export GIT_INDEX_FILE=$git_idx
		export GIT_ALTERNATE_OBJECT_DIRECTORIES=$GIT_ALTERNATE_OBJECT_DIRECTORIES:$(
			if [ -d "$toplevel/$path/.git" ]; then
				echo "$toplevel/$path/.git/objects"
			else
				DIR=`cat "$toplevel/$path/.git" | sed "s/gitdir:[[:space:]]*//"`
				if [ -d "$DIR/objects" ]; then
					echo $DIR
				else
					DIR="$toplevel/$path/$DIR/objects"
					DIR=`cd -P -- "$(dirname -- "$DIR")" && echo "$(pwd -P)/$(basename -- "$DIR")"`
					echo $DIR
				fi
			fi
		)
		
		#
		# Find out which subcommit we are on, remove the submodule from the temporary index
		# and export the files to the index
		#
		subcommit=$(git rev-parse :"$path")
		if [ "$subcommit" != "$sha1" ]; then
			echo "WARNING $subcommit != $sha1" 1>&2
		fi
		git rm --quiet --cached $path
		git read-tree -i --prefix="$path/" $subcommit
	'
}

#---------------- main code ----------------
revision="$1"
if [ "$revision" == "" ]; then
	revision="HEAD"
fi
out="$2"
if [ "$out" == "" ]; then
	out="Archive.zip"
fi

export out
export revision
export GIT_INDEX_FILE="$PWD/.git/tmpindex"
export up

echo "INFO Building tmp index for $revision" 1>&2

rm -f "$GIT_INDEX_FILE"

git read-tree $revision

echo "INFO Recursing through submodules"
while git ls-files -s | grep -q ^160000; do
	echo "DEBUG Read next level" 1>&2
	read_one_level
done

echo "INFO Done, archiving to zip"
git archive --output=$out --format=zip $(git write-tree)

rm -f "$GIT_INDEX_FILE"