#!/system/bin/

tab='	'
nl='
'
IFS=" $tab$nl"

version='gzexe (gzip) 1.12
Copyright (C) 2007, 2011-2018 Free Software Foundation, Inc.
This is free software.  You may redistribute copies of it under the terms of
the GNU General Public License <https://www.gnu.org/licenses/gpl.html>.
There is NO WARRANTY, to the extent permitted by law.

Written by Jean-loup Gailly.'

usage="Usage: $0 [OPTION] FILE...
Replace each executable FILE with a compressed version of itself.
Make a backup FILE~ of the old version of FILE.

  -d             Decompress each FILE instead of compressing it.
      --help     display this help and exit
      --version  output version information and exit

Report bugs to <bug-gzip@gnu.org>."

decomp=0
res=0
while :; do
  case $1 in
  -d) decomp=1; shift;;
  --h*) printf '%s\n' "$usage"   || exit 1; exit;;
  --v*) printf '%s\n' "$version" || exit 1; exit;;
  --) shift; break;;
  *) break;;
  esac
done

if test $# -eq 0; then
  printf >&2 '%s\n' "$0: missing operand
Try \`$0 --help' for more information."
  exit 1
fi

tmp=
trap 'res=$?
  test -n "$tmp" && rm -f "$tmp"
  (exit $res); exit $res
' 0 1 2 3 5 10 13 15

mktemp_status=

for i do
  case $i in
  -*) file=./$i;;
  *)  file=$i;;
  esac
  if test ! -f "$file" || test ! -r "$file"; then
    res=$?
    printf >&2 '%s\n' "$0: $i is not a readable regular file"
    continue
  fi
  if test $decomp -eq 0; then
    case `LC_ALL=C sed -n -e 1d -e '/^skip=[0-9][0-9]*$/p' -e 2q "$file"` in
    skip=[0-9] | skip=[0-9][0-9] | skip=[0-9][0-9][0-9])
      printf >&2 '%s\n' "$0: $i is already gzexe'd"
      continue;;
    esac
  fi
  if test -u "$file"; then
    printf >&2 '%s\n' "$0: $i has setuid permission, unchanged"
    continue
  fi
  if test -g "$file"; then
    printf >&2 '%s\n' "$0: $i has setgid permission, unchanged"
    continue
  fi
  case /$file in
  */basename | */bash | */cat | */chmod | */cp | \
  */dirname | */expr | */gzip | \
  */ln | */mkdir | */mktemp | */mv | */printf | */rm | \
  */sed | */sh | */sleep | */test | */tail)
    printf >&2 '%s\n' "$0: $i might depend on itself"; continue;;
  esac

  dir=`dirname "$file"` || dir=$TMPDIR
  test -d "$dir" && test -w "$dir" && test -x "$dir" || dir=/data/local/tmp/
  test -n "$tmp" && rm -f "$tmp"
  if test -z "$mktemp_status"; then
    type mktemp >/dev/null 2>&1
    mktemp_status=$?
  fi
  case $dir in
    */) ;;
    *) dir=$dir/;;
  esac
  if test $mktemp_status -eq 0; then
    tmp=`mktemp "${dir}gzexeXXXXXXXXX"`
  else
    tmp=${dir}gzexe$$
  fi && { cp -p "$file" "$tmp" 2>/dev/null || cp "$file" "$tmp"; } || {
    res=$?
    printf >&2 '%s\n' "$0: cannot copy $file"
    continue
  }
  if test -w "$tmp"; then
    writable=1
  else
    writable=0
    chmod u+w "$tmp" || {
      res=$?
      printf >&2 '%s\n' "$0: cannot chmod $tmp"
      continue
    }
  fi
  if test $decomp -eq 0; then
    (cat <<'EOF' &&
#!/system/bin/
skip=50
set -e

tab='	'
nl='
'
IFS=" $tab$nl"

umask=`umask`
umask 77

gztmpdir=
trap 'res=$?
  test -n "$gztmpdir" && rm -fr "$gztmpdir"
  (exit $res); exit $res
' 0 1 2 3 5 10 13 15

case $TMPDIR in
  / | /*/) ;;
  /*) TMPDIR=$TMPDIR/;;
  *) TMPDIR=/data/local/tmp/;;
esac
if type mktemp >/dev/null 2>&1; then
  gztmpdir=`mktemp -d "${TMPDIR}gztmpXXXXXXXXX"`
else
  gztmpdir=${TMPDIR}gztmp$$; mkdir $gztmpdir
fi || { (exit 127); exit 127; }

gztmp=$gztmpdir/$0
case $0 in
-* | */*'
') mkdir -p "$gztmp" && rm -r "$gztmp";;
*/*) gztmp=$gztmpdir/`basename "$0"`;;
esac || { (exit 127); exit 127; }

case `printf 'X\n' | tail -n +1 2>/dev/null` in
X) tail_n=-n;;
*) tail_n=;;
esac
if tail $tail_n +$skip <"$0" | gzip -cd > "$gztmp"; then
  umask $umask
  chmod 777 "$gztmp"
  (sleep 5; rm -fr "$gztmpdir") 2>/dev/null &
  "$gztmp" ${1+"$@"}; res=$?
else
  printf >&2 '%s\n' "Cannot decompress $0"
  (exit 127); res=127
fi; exit $res
EOF
    gzip -cv9 "$file") > "$tmp" || {
      res=$?
      printf >&2 '%s\n' "$0: compression not possible for $i, file unchanged."
      continue
    }

  else
    # decompression
    skip=50
    skip_line=`LC_ALL=C sed -e 1d -e 2q "$file"`
    case $skip_line in
    skip=[0-9] | skip=[0-9][0-9] | skip=[0-9][0-9][0-9])
      eval "$skip_line";;
    esac
    case `printf 'X\n' | tail -n +1 2>/dev/null` in
    X) tail_n=-n;;
    *) tail_n=;;
    esac
    tail $tail_n +$skip "$file" | gzip -cd > "$tmp" || {
      res=$?
      printf >&2 '%s\n' "$0: $i probably not in gzexe format, file unchanged."
      continue
    }
  fi
  test $writable -eq 1 || chmod u-w "$tmp" || {
    res=$?
    printf >&2 '%s\n' "$0: $tmp: cannot chmod"
    continue
  }
  ln -f "$file" "$file~" 2>/dev/null || {
    # Hard links may not work.  Fall back on rm+cp so that $file always exists.
    rm -f "$file~" && cp -p "$file" "$file~"
  } || {
    res=$?
    printf >&2 '%s\n' "$0: cannot backup $i as $i~"
    continue
  }
  mv -f "$tmp" "$file" || {
    res=$?
    printf >&2 '%s\n' "$0: cannot rename $tmp to $i"
    continue
  }
  tmp=
done
(exit $res); exit $res
