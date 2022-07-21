#!/usr/bin/env bash

# Thanks to: https://gist.github.com/oneohthree/f528c7ae1e701ad990e6
slugify() {
    echo "$1" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr A-Z a-z
}

read -p 'Post title: ' title
titleslug="$(slugify "${title}")"

# Get date in specific format, always use UTC here
datetime="$(TZ=UTC date "+%F %T") +0000"
date="$(TZ=UTC date +%F)"

filename="_posts/${date}-${titleslug}.md"
echo "Filename: ${filename}"
echo "Slug: ${titleslug}"
echo "Title: ${title}"

# Create file:
touch "${filename}"

echo "---" >> ${filename}
echo "title: ${title}" >> ${filename}
echo "date: ${datetime}" >> ${filename}
echo "categories: [a, b]" >> ${filename}
echo "tags: []" >> ${filename}
echo "---" >> ${filename}

echo "Done!"
