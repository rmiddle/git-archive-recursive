#!/bin/sh

export revision="$1"

export GIT_INDEX_FILE=".git/tmpindex"
rm -f "$GIT_INDEX_FILE"

git read-tree $revision

export up="$(pwd)"

read_one_level () {
	export GIT_ALTERNATE_OBJECT_DIRECTORIES="$GIT_ALTERNATE_OBJECT_DIRECTORIES":$(
	    git submodule foreach 'echo "$up/$path/.git/objects"' |
	    grep -E -v '^(Entering|No submodule mapping found)' |
	    tr '\n' : |
	    sed 's/:$//'
	)

	git submodule foreach '
		cd "$up"
		subcommit=$(git rev-parse :"$path")
		git rm --cached "$path"
		git read-tree -i --prefix="$path/" $subcommit
	' >/dev/null
}

while git ls-files -s | grep -q ^160000; do
    read_one_level
done

git archive --format=tar $(git write-tree)

rm -f "$GIT_INDEX_FILE"
