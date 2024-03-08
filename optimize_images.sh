#!/bin/bash

set -e

# ARGS:
base_image_dir="assets/images/"
image_dir="${1:-$base_image_dir}"
[[ "$image_dir" == "$base_image_dir"* ]] || exit 1 # exit if image_dir is not a child of base_image_dir

# Environments:
output_ext=""
if [ -n "$OUTPUT_FMT" ]; then
    output_ext=".$(echo $OUTPUT_FMT | tr '[:upper:]' '[:lower:]')"
fi

# Constants:
no_opt_size_kb=50
no_thumb_size_kb=100
thumbhash_file="_data/thumbhash.yml"

# Variables:
img=""
converted=0
img_size_kb=0
new_img_size_kb=0
yq_thumbhash="."

# get image metadata
fetch_metadata() {
    metadata=($(identify -ping -format "%w,%h,%Q,%[interlace],%m,%r" "$img" | tr ',' '\n'))
    width=${metadata[0]}
    height=${metadata[1]}
    quality=${metadata[2]}
    interlace=${metadata[3]}
    format=${metadata[4]}
    class=${metadata[5]}
    smallest_dimension=$((width < height ? width : height))
}

# replace original image if smaller than original
# delete if larger than original
post_converted() {
    local img_tmp=$1
    local force_convert=$2
    if ! [ -f "$img_tmp" ]; then
        return
    fi

    new_img_size_kb=$(du -k "$img_tmp" | cut -f1)
    if ((new_img_size_kb < img_size_kb)) || [ "$force_convert" == "1" ]; then
        mv "$img_tmp" "$img"
        converted=1
    else
        rm "$img_tmp"
    fi
}

calculate_thumbhash() {
    local hash=$(thumbhash encode "$img" | awk -F ': ' '{print $NF}' | xargs thumbhash decode - | awk -F ': ' '{print $NF}')
    local key=$(echo "$img" | sed "s|$base_image_dir||")

    yq_thumbhash="$yq_thumbhash | .\"$key\"=\"$hash\""
}

opt_main() {
    local is_img
    local args

    img_size_kb=$(du -k "$img" | cut -f1)
    if ((img_size_kb <= no_opt_size_kb)); then
        return
    fi

    # check is image
    is_img=$(file --mime-type "$img" | awk -F ': ' '{print $NF}' | grep 'image')
    if [ -z "$is_img" ]; then
        return
    fi

    fetch_metadata
    echo "$img: $width x $height, $quality, $interlace, $format, $class"

    local img_tmp="${img}.tmp$output_ext"
    local force_imagemagick=1

    # 1. pngquant. Optimize for PNG.
    if [ "$format" == "PNG" ] && [[ "$class" != "PseudoClass"* ]] && [[ -z "$output_ext" || "$output_ext" == ".png" ]]; then
        local args="--force --skip-if-larger --quality 80-90 --speed 1 --output $img_tmp -- $img"
        echo "pngquant $args"
        pngquant $args
        post_converted "$img_tmp" 0

        if ((new_img_size_kb > no_opt_size_kb)); then
            force_imagemagick=$converted
        fi
    fi

    # 2. Imagemagick. Resize and optimize the image to progressive image.
    args=''
    if ((smallest_dimension > 1920)); then
        args="$args -resize $(((1920 * 100) / smallest_dimension))%"
    fi
    if ((quality > 88)) && [ "$format" != "PNG" ]; then
        args='-quality 80'
    fi
    if [[ "$interlace" == "None" ]] && [[ -z "$output_ext" ]]; then
        force_imagemagick=1
    fi
    if [ -n "$args" ] || [ $force_imagemagick -eq 1 ]; then
        args="-strip -enhance -auto-level -auto-orient -interlace Plane $args"
        echo "convert $img $args $img_tmp"
        convert "$img" $args "$img_tmp"
        post_converted "$img_tmp" $force_imagemagick
    fi

    if [ $converted -eq 1 ] && (( new_img_size_kb > no_thumb_size_kb )); then
        calculate_thumbhash
        printf "\n"
    fi
}

main() {
    local all_images=("$image_dir")
    [ -d "$image_dir" ] && all_images=($(fd -tf "" $image_dir))

    for image in "${all_images[@]}"; do
        img=$image
        converted=0
        opt_main
    done

    if [ "$yq_thumbhash" != "." ]; then
        yml=$thumbhash_file

        echo "Updating thumbhash to $yml"
        yq "$yq_thumbhash" "$yml" >"$yml.tmp"
        mv "$yml.tmp" "$yml"
    fi
}

main
