_template () {
  file=$1
  shift
  eval "`printf 'local %s\n' $@`
cat <<EOF
`cat $file`
EOF"
}

