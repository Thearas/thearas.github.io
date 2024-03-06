#!/bin/bash

no_responsive_size_kb=512 # 512KB
img=$1

img_size_kb=$(du -k "$img" | cut -f1)
if ((img_size_kb <= no_responsive_size_kb)); then
    exit 0
fi

# check is image
is_img=$(file --mime-type "$img" | awk -F ': ' '{print $NF}' | grep 'image')
if [ -z "$is_img" ]; then
    exit 0
fi

# get image metadata
fetch_metadata(){
    metadata=($(identify -ping -format "%w,%h,%Q,%[interlace],%m,%r" "$img" | tr ',' '\n'))
    width=${metadata[0]}
    height=${metadata[1]}
    quality=${metadata[2]}
    interlace=${metadata[3]}
    format=${metadata[4]}
    class=${metadata[5]}
    smallest_dimension=$((width < height ? width : height))
}

delete_if_larger(){
    local img_tmp=$1
    local force_convert=$2
    if ! [ -f "$img_tmp" ]; then
        exit 0
    fi

    local new_img_size_kb=$(du -k "$img_tmp" | cut -f1)
    if ((new_img_size_kb < img_size_kb)) || [ "$force_convert" == "1" ]; then
        mv "$img_tmp" "$img"
    else
        rm "$img_tmp"
    fi
}

main(){
    fetch_metadata
    echo "$img: $width x $height, $quality, $interlace, $format, $class"

    img_tmp="${img}.new"
    png_interlace=0

    # 1. pngquant. Optimize for PNG.
    if [ "$format" == "PNG" ] && [[ "$class" != "PseudoClass"* ]]; then
        echo "pngquant --force --skip-if-larger --quality '80-90' --speed 1 --output $img_tmp -- $img"
        pngquant --force --skip-if-larger --quality '80-90' --speed 1 --output "$img_tmp" -- "$img"
        delete_if_larger "$img_tmp" 0
        png_interlace=1
    fi

    # 2. Imagemagick. Resize and optimize the image to progressive image.
    args=''
    force_convert=0
    if ((smallest_dimension > 1920)); then
        args="$args -resize $(((1920 * 100) / smallest_dimension))%"
    fi
    if ((quality > 94)) && [ "$format" != "png" ]; then
        args='-quality 85'
    fi
    if [[ "$interlace" == "None" || "$png_interlace" == "1" ]]; then
        args="$args -interlace Plane"
        force_convert=1
    fi

    if [ -n "$args" ]; then
        echo "convert $img -strip -auto-level -auto-orient $args $img_tmp"
        convert "$img" -strip -auto-level -auto-orient $args "$img_tmp"
        delete_if_larger "$img_tmp" $force_convert
        printf "\n"
    fi
}

main