#!/bin/bash
#
# Usage: git archive-recursive [ git archive options ] tree-ish
#
#
set -e

function read_one_level () {
	export git_idx=$GIT_INDEX_FILE
	export GIT_ALTERNATE_OBJECT_DIRECTORIES
	echo "INFO Add submodules to index" 1>&2
	
	for gitpath in $(git submodule --quiet foreach 'git rev-parse --git-dir'); do
		GIT_ALTERNATE_OBJECT_DIRECTORIES=$GIT_ALTERNATE_OBJECT_DIRECTORIES:$gitpath/objects
	done


	git submodule --quiet foreach '
		set -e
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

# pop the last param
revision=${@: -1}
archive_params=${@:1:${#@}-1}

export revision
export GIT_INDEX_FILE="$PWD/.git/tmpindex"
export up

git read-tree $(git rev-parse $revision)

echo "INFO Looping through submodules"
while git ls-files -s | grep -q ^160000; do
	read_one_level
done

git_tree_hash=$(git write-tree)
git archive ${archive_params} $git_tree_hash

rm -f "$GIT_INDEX_FILE"
