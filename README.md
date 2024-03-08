# My blog

## Prerequisites

```bash
make init
```

## Build

1. Install dependencies

    ```bash
    make install
    ```

2. Run

    ```bash
    npm run build:js # if you modified the `assets/js/_main.js`

    make run
    ```

3. Publish

    ```bash
    # update search index, `$ALGOLIA_API_KEY` should be in `~/.zshrc`
    make index

    # optimize images
    make optimize_images
    ```

    Then just push the changes to GitHub.
