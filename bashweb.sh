#!/bin/bash
# bashweb server by jomo


source bashweb.conf                                                                   # config file

response=/tmp/bashweb                                                                 # temp file (fifo)

if ! [ -p $response ]; then
  mkfifo $response
fi

cd "$web_root"

echo "Starting bashweb server on ${hostname}:${port}${web_root}"
echo "press CTRL-C to exit"
while true ; do

  cat "$response" | nc -l "$hostname" "$port" | (                                     # sends response to netcat after stuff was sent

    request=`while read line && [ "$line" ">" " " ]; do                               # stops reading when the line is empty or invalid
      echo "$line" | grep GET
    done`

    orig_file="$(echo "$request" | cut -d " " -f 2)"                                       # cut out path
    file="${orig_file//\\/\\\\\\/}"                                                          # replace \ with \\
    file="${file//\%2F/\\/}"                                                          # replace urlencoded / with \/
    file="${file//\%/\\x}"                                                            # handle URL encoding. %20 = \x20
    file="${web_root}/${file}"                                                        # prepend web root
    file="$(echo -e "$file")"
    file="$(readlink -f "$file")"

    if [ -f "$file" ]; then
      if $(echo "$file" | egrep -q "^$web_root"); then
        status="200 OK"
        body="$(<"$file")"
      else
        status="403 Forbidden"
        body="$(<"403.html")"
      fi
    else
      status="404 Not found"
      body="$(<"404.html")"
    fi

    size="${#body}"
    out="HTTP/1.1 $status"
    out+=$'\n'"Server: $server_name"
    out+=$'\n'"Content-Length: $size"
    out+=$'\n\n'"$body"

    log="[BASHWEB] $(date "+%Y-%m-%d %H:%M:%S")\t'$orig_file'\t'$file'\t${size}B\t'$status'"
    echo -e "$log" >> "$log_file"
    echo -e "$log"

    echo "$out" | cat > $response
  )
done
