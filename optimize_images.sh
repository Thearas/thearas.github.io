#!/bin/bash

all_images=($(fd -tf "" assets/images))
for img in "${all_images[@]}"; do
    ./progressive_img.sh "$img"
done
