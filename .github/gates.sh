#!/bin/sh
# The job of one gate kind of docs/gates.tsv (.github/workflows/gates.yml):
#   sh .github/gates.sh KIND
# with GATE_BASE and GATE_HEAD, the base and the head commits of the pull
# request, in the environment, on a checkout of the head. It gives the result
# of the kind by the rules of the manifest, as `layup gate` gives it from
# outside, and starts no program but sh, awk, tail, iconv, tr, mktemp, rm, git
# and the kind's own tool. It prints the kind, the result and the reason, and
# exits 0 for pass or clear, 1 otherwise. A manifest that `layup gate` refuses
# fails the job.
set -u
set -f
kind=${1:-}
manifest=docs/gates.tsv

# result prints the row of the kind, removes the temporary files, and exits.
result() {
	printf '%s\t%s\t%s\n' "$kind" "$1" "$(printf '%s' "$2" | tr '\t' ' ')"
	rm -f ${tmp:+"$tmp"} ${lines:+"$lines"}
	case $1 in pass | clear) exit 0 ;; esac
	exit 1
}

# The rules of a path and of a scope pattern (gate.md, A scope pattern), in
# awk: valid(s) is a path with no empty, . or .. part; a pattern P/*.E matches
# a file under P (any depth; ./*.E anywhere) whose name ends with .E; a
# pattern with no * matches that path and each path under it.
awklib='
function valid(s,   n, i, part) {
	if (s == "") return 0
	n = split(s, part, "/")
	for (i = 1; i <= n; i++) if (part[i] == "" || part[i] == "." || part[i] == "..") return 0
	return 1
}
function form(p,   t, c, j, dir, ext) {
	t = p
	c = gsub(/\*/, "", t)
	if (c == 0) return valid(p)
	j = index(p, "/*.")
	if (c != 1 || j == 0) return 0
	dir = substr(p, 1, j - 1); ext = substr(p, j + 3)
	if (ext == "" || index(ext, "/") || index(ext, "*")) return 0
	return dir == "." || valid(dir)
}
function match_one(path, p,   j, dir, ext, name) {
	if (index(p, "*") == 0) return path == p || index(path, p "/") == 1
	j = index(p, "/*."); dir = substr(p, 1, j - 1); ext = substr(p, j + 2)
	if (dir != "." && index(path, dir "/") != 1) return 0
	name = path; sub(/.*\//, "", name)
	return length(name) > length(ext) && substr(name, length(name) - length(ext) + 1) == ext
}
'

[ -n "$kind" ] || result fail "usage: sh .github/gates.sh KIND"

# The base and the head are commits, and the checkout is the head: the job
# judges the files of the checkout.
[ -n "${GATE_BASE:-}" ] && [ -n "${GATE_HEAD:-}" ] || result fail "GATE_BASE and GATE_HEAD name no commit"
for rev in "$GATE_BASE" "$GATE_HEAD"; do
	git rev-parse --verify --quiet "$rev^{commit}" > /dev/null || result fail "the revision $rev is not a commit"
done
[ "$(git rev-parse --verify --quiet HEAD)" = "$(git rev-parse --verify --quiet "$GATE_HEAD^{commit}")" ] ||
	result fail "the checkout is not the head commit $GATE_HEAD"

# The form of the manifest, as the reader of layup gate reads it: UTF-8 with a
# line feed after the last line; a header row; in each row six fields, none
# empty and no carriage return; a kind of lowercase letters and -, once each;
# a state; a scope of one or more patterns of the form of gate.md, one space
# between two; and config paths, none in .git (— is the empty value).
[ -f "$manifest" ] || result fail "no manifest: $manifest"
[ -s "$manifest" ] || result fail "the manifest: no header row"
[ "$(tail -c 1 "$manifest" | tr '\n' L)" = L ] || result fail "the manifest: no line feed after the last line"
iconv -f UTF-8 -t UTF-8 "$manifest" > /dev/null 2>&1 || result fail "the manifest: a byte that is not UTF-8"
problem=$(LC_ALL=C awk -F '\t' "$awklib"'
NR == 1 {
	if ($0 != "kind\tstate\ttool\tcommand\tscope\tconfig") { print "line 1 is not the header row"; bad = 1; exit }
	next
}
{
	if (index($0, "\r")) { print "line " NR " has a carriage return"; bad = 1; exit }
	if ($0 == "") { print "line " NR " is an empty line"; bad = 1; exit }
	if (NF != 6) { print "line " NR " has " NF " fields, not 6"; bad = 1; exit }
	for (i = 1; i <= 6; i++) if ($i == "") { print "line " NR " has an empty field; write \342\200\224 for an empty value"; bad = 1; exit }
	if ($1 !~ /^[a-z-]+$/) { print "line " NR ": the kind " $1 " is not a word"; bad = 1; exit }
	if ($1 in seen) { print "line " NR ": the kind " $1 " is there twice"; bad = 1; exit }
	seen[$1] = 1
	if ($2 != "active" && $2 != "pending") { print "line " NR ": the state " $2; bad = 1; exit }
	if ($5 == "\342\200\224") { print "line " NR ": the kind " $1 " has no scope pattern"; bad = 1; exit }
	n = split($5, pat, "[ ]")
	for (i = 1; i <= n; i++) {
		if (pat[i] == "") { print "line " NR ": the scope " $5 " holds an empty pattern"; bad = 1; exit }
		if (!form(pat[i])) { print "line " NR ": the scope pattern " pat[i] " is not of the form of the manifest"; bad = 1; exit }
	}
	if ($6 != "\342\200\224") {
		n = split($6, cfg, "[ ]")
		for (i = 1; i <= n; i++) {
			if (!valid(cfg[i])) { print "line " NR ": the config path " cfg[i] " is not a path"; bad = 1; exit }
			first = cfg[i]; sub(/\/.*/, "", first)
			if (tolower(first) == ".git") { print "line " NR ": the config path " cfg[i] " is in .git"; bad = 1; exit }
		}
	}
}
END { if (!bad && NR < 2) print "the manifest has no row" }
' "$manifest") || result not-active "awk failed"
[ -z "$problem" ] || result fail "the manifest: $problem"

field() {
	GATE_KIND=$kind LC_ALL=C awk -F '\t' -v i="$1" '
NR > 1 && $1 == ENVIRON["GATE_KIND"] { v = $i; if (v == "\342\200\224") v = ""; print v; found = 1; exit }
END { if (!found) exit 1 }' "$manifest"
}
# Each read checks its status: a failed read is never a value (with bash 5.3 on
# macOS, a subshell of the script crashed in about 5 runs of 100, round 1 of
# #91), and a failed check is never a pass.
state=$(field 2) || result fail "no row for the kind $kind in $manifest"
tool=$(field 3) || result not-active "the manifest could not be read"
command=$(field 4) || result not-active "the manifest could not be read"
scope=$(field 5) || result not-active "the manifest could not be read"

tmp=$(mktemp) || result not-active "mktemp failed"
lines=$(mktemp) || result not-active "mktemp failed"

# scan reads the list of paths that git wrote with -z into $tmp, and gives the
# first path that the scope matches as "path <path>", or "none". A failure of
# tr or awk, or an answer of another form, is not-active: never a pass.
scan() {
	tr '\0' '\n' < "$tmp" > "$lines" || result not-active "the scope check failed"
	answer=$(GATE_SCOPE=$scope LC_ALL=C awk "$awklib"'
BEGIN { n = split(ENVIRON["GATE_SCOPE"], pat, "[ ]") }
{ for (i = 1; i <= n; i++) if (match_one($0, pat[i])) { print "path " $0; found = 1; exit } }
END { if (!found) print "none" }' "$lines") || result not-active "the scope check failed"
	case $answer in
	none | "path "?*) ;;
	*) result not-active "the scope check failed" ;;
	esac
}

if [ "$state" = pending ]; then
	git diff --name-only --no-renames -z "$GATE_BASE" "$GATE_HEAD" > "$tmp" || result not-active "diff failed"
	scan
	[ "$answer" = none ] || result fail "pending: product path changed: ${answer#path }"
	result clear "pending: no product path"
fi

# found reports whether the tool is a program, as exec.LookPath finds it: a
# name with / is that file; another name is a file of a directory of PATH
# that is absolute (exec.LookPath refuses one in the current directory), not
# a builtin of sh.
found() {
	case $1 in
	'') return 1 ;;
	*/*) [ -f "$1" ] && [ -x "$1" ]; return ;;
	esac
	save=$IFS
	IFS=:
	for d in $PATH; do
		case $d in /*) ;; *) continue ;; esac
		if [ -f "$d/$1" ] && [ -x "$d/$1" ]; then
			IFS=$save
			return 0
		fi
	done
	IFS=$save
	return 1
}
found "$tool" || result not-active "tool not found: $tool"
git ls-files -z > "$tmp" || result not-active "git ls-files failed"
scan
[ "$answer" != none ] || result clear "no product path"
sh -c "$command"
code=$?
[ "$code" -eq 0 ] && result pass "—"
result fail "exit $code"
