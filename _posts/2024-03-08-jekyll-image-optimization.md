---
layout: posts
categories: 技术
title: Image loading optimization for Jekyll and GitHub Page 
excerpt: 常听前端同学自嘲切图仔，这次我也当一回
header:
  overlay_image: /assets/images/image-optimization/Lenna.png
  caption: "图 \\| [Lenna](https://en.wikipedia.org/wiki/Lenna)"
---

[Jekyll](https://jekyllrb.com) 是一个经典的博客框架，[GitHub Page](https://pages.github.com) 是它的其中一个使用场景。
Jekyll 生成的静态网页能免费地在 GitHub Page 上部署，但图片加载（速度）却不尽如人意，尤其是在国内访问。
本文将介绍如何优化图片加载。

## 思路

1. [转换格式](#转换格式)
    1. [WebP](#webp)
    2. [JPEG 或 PNG](#jpeg-或-png)（渐进式）
2. [缩小尺寸和质量](#缩小尺寸和质量) 和 [PNG 有损压缩](#png-有损压缩)
3. [图片懒加载](#图片懒加载)
4. [先展示 Base64 缩略图](#先展示-base64-缩略图)
5. [渐进式加载](#渐进式加载)
6. [其他优化](#其他优化)
7. [查看效果](#查看效果) 和 [Lighthouse](#lighthouse)

本文的逻辑我写成了 Bash 脚本，你可以在[这里](https://github.com/Thearas/thearas.github.io/blob/f3271cb30be84b3a54730793bb6708739316e852/optimize_images.sh#L65)找到。

### 开始前

我们需要安装点儿下文用到的图片处理工具：

```bash
pip3 install git+https:////github.com/Thearas/thumbhash-python.git
brew install imagemagick pngquant # for macOS
```

### 转换格式

我更推荐使用 WebP，JPEG 或 PNG 相比 WebP 唯二的好处是**更通用和支持渐进式加载**。但通常这两点不重要，因为现代浏览器都支持 WebP，而且大多场景下 WebP 的小体积带来的优化完全可以盖过渐进式加载带来的。

#### WebP

相比之下，WebP 好处很多：支持透明度、支持有损压缩、相比 JPEG/PNG 更小的文件体积和支持动图等，而且据我观察很可能是**主流**格式里唯一一个支持有损压缩透明图的。转成 WebP 很简单，用 imagemagick 的 convert 命令，在输出图片上加个 `.webp` 后缀即可：

```bash
convert '<orig-img>' '<dest-img>.webp' # add .webp suffix
```

#### JPEG 或 PNG

次选 JPEG 或 PNG，不透明的选 JPEG，透明的选 PNG。你可以在我的上一篇文章中体验到：[白色武功山](https://thearas.github.io/%E6%97%85%E8%A1%8C/white-wugongshan) 有 15 张相机拍的图。转成渐进式也很简单：

```bash
# identify 也是 imagemagick 提供的命令之一，'-ping' 代表只会读取图片的头部信息，提升效率
interlace=$(identify -ping -format "%[interlace]" '<orig-img>') 

# 只在原图不是渐进式时才转
if [[ "$interlace" == "None" ]]; then
    convert -interlace Plane '<orig-img>' '<dest-img>.jpg/png' # use '-interlace Plane' to make jpg/png progressive
fi
```

<br/>

### 缩小尺寸和质量

按自己的使用场景缩，我的场景是相机出图（6000x3000），所以为了保留一定的清晰度，我会等比例将最小边缩到 1920px、质量缩到 80。

```bash
# 获取原图宽、高和质量
meta=($(identify -ping -format "%w,%h,%Q" '<orig-img>' | tr ',' '\n'))
width=${metadata[0]}
height=${metadata[1]}
quality=${metadata[2]}

smallest_dimension=$((width < height ? width : height))
args=''

# 缩小尺寸，最小边大于 1920 才缩
if ((smallest_dimension > 1920)); then
    args="$args -resize $(((1920 * 100) / smallest_dimension))%"
fi

# 缩小质量，大于 88 且图片支持有损压缩（比如非 PNG）才压缩质量
if ((quality > 88)) && [ "$format" != "PNG" ]; then
    args='-quality 80'
fi

# 防止重复压缩
if [ -n "$args" ]； then
    convert $args '<orig-img>' '<dest-img>.webp/jpg/png'
fi
```

#### PNG 有损压缩

PNG 有损压缩是把 PNG 图片转成 Palette PNG。我用的是 [pngquant](https://pngquant.org)，摘抄简介：

> Imagequant library converts RGBA images to palette-based 8-bit indexed images, including alpha component. It's ideal for generating tiny PNG images and nice-looking GIFs.

[pngquant](https://pngquant.org) 本身就是命令行工具，可以这么用：

```bash
class=$(identify -ping -format "%m,%r" '<orig-img>' | tr ',' '\n')
format=${metadata[0]}
class=${metadata[1]}

# 如果是 PNG 且不是 PseudoClass（colormapped）就压缩
if [ "$format" == "PNG" ] && [[ "$class" != "PseudoClass"* ]]; then
    # 把质量压缩到 '80-90'
    pngquant --force --skip-if-larger --quality 80-90 --speed 1 --output '<dest-img>' -- '<orig-img>'
fi
```

<br/>

### 图片懒加载

就是等用户快划到图片的时候再加载图片，这样可以减少首屏加载时间。我用的是 [lazysizes](https://github.com/aFarkas/lazysizes)， 引入它只需要两步：

1. 在 _layouts/default.html 中 `<body>` 标签的最后加上 lazysizes.min.js 链接

    ```html
    <body>
    ...

    <script src="<url to lazysizes.min.js>"></script>
    </body>
    ```

2. 在需要懒加载的图片上加上 `data-src` 和 `class="lazyload"` 属性

    ```html
    <img data-src="<url to image>" class="lazyload" />
    ```

在 Jekyll 中，为了方便，你可以用 [Liquid](https://jekyllrb.com/docs/liquid/) 语言来实现，首先创建一个 `_include/img.html` 文件：

```liquid
{% raw  %}{% if include.src %}
  {% capture img_src %}/assets/images/{{ include.src }}{% endcapture %}
  <img data-src="{{img_src | relative_url}}" class="lazyload" alt="{{include.alt | default: ''}}" />
{% endif %}{% endraw %}
```

然后在博客 Markdown 文件中这样引用：

```liquid
{% raw  %}{% include img.html src="image-optimization/IMG_2354.JPG" alt="我的图片" %}{% endraw %}
```

<br/>

### 先展示 Base64 缩略图

网络不好时即便用上了压缩后的图片也还是慢，这时可以先展示缩略图占个坑位，体验好点儿。

看过 [白色武功山](https://thearas.github.io/%E6%97%85%E8%A1%8C/white-wugongshan) 的朋友可能注意到：先看到的是非常模糊的图片，等一会儿真正的图片才开始刷新。这是因为我用 [thumbhash-python](https://github.com/Thearas/thumbhash-python) 生成了 PNG 缩略图的 Base64，并直接嵌入进 HTML 里，所以缩略图是不需要额外请求、瞬间就能看到的。

效果如图：

{%- include img.html src="image-optimization/pg_0.png" alt="缩略图效果" width="300px" -%}

要实现这点分两步：

1. 生成缩略图的 Base64，并保存在 `_data/thumbhash.yml` 文件中

    ```bash
    hash=$(thumbhash encode "$img" | awk -F ': ' '{print $NF}' | xargs thumbhash decode - | awk -F ': ' '{print $NF}')
    echo "$img: $hash" >> _data/thumbhash.yml
    ```

2. 在 HTML 中自动引入，改改我们上面创建的 `_include/img.html` 文件，Jekyll 会自动把 `_data/xxx.yml` 的数据存在 `site.data.xxx` 变量中，我们直接用 `site.data.thumbhash[include.src]` 即可找到对应图片的缩略图 Base64，然后设置在 `<img>` 标签的 src 属性中

    ```liquid
    {% raw  %}{% if include.src %}
        {% capture img_src %}/assets/images/{{ include.src }}{% endcapture %}
        <img data-src="{{img_src | relative_url}}" class="lazyload" alt="{{include.alt | default: ''}}"
            <!-- 加在这里 -->
            {% if site.data.thumbhash[include.src] %}
                src="data:image/png;base64,{{site.data.thumbhash[include.src]}}"
            {% endif %}
        />
    {% endif %}{% endraw %}
    ```

<br/>

### 渐进式加载

渐进式加载是指图片一点一点地从模糊到清晰。这样用户就能看到图片的大概样子，而不是一片空白。上面说到过，这个特性在 JPEG 和 PNG 中都有，但在 WebP 中没有。

不过仍然有可以优化的，那就是「Base64 缩略图」和「原图」间的渐进式过渡。我在 [白色武功山](https://thearas.github.io/%E6%97%85%E8%A1%8C/white-wugongshan) 中的图片就是这样做的，先展示 Base64 缩略图作为背景，等真正图片加载时一点点替换。

大致效果如下：

<table>
    <thead>
        <th>先展示缩略图</th>
        <th>原图逐渐替换缩略图</th>
        <th>原图逐渐清晰</th>
        <th>原图加载完毕</th>
    </thead>
    <tbody>
        <tr>
            <td>{%- include img.html src="image-optimization/pg_0.png" alt="刚开始" width="200px" -%}</td>
            <td>{%- include img.html src="image-optimization/pg_1.jpg" alt="一阶段" width="200px" -%}</td>
            <td>{%- include img.html src="image-optimization/pg_2.jpg" alt="二阶段" width="200px" -%}</td>
            <td>{%- include img.html src="image-optimization/pg_3.jpg" alt="三阶段" width="200px" -%}</td>
        </tr>
    </tbody>
</table>

加[一小段 js 代码](https://github.com/aFarkas/lazysizes/blob/master/plugins/progressive)即可实现。

<br/>

### 其他优化

我在文章开头的脚本中还[做了一些其他优化](https://github.com/Thearas/thearas.github.io/blob/f3271cb30be84b3a54730793bb6708739316e852/optimize_images.sh#L110)，比如去掉图片的 Exif 信息等，这些都通过给 `convert` 命令加参数实现。

我简单介绍下，具体看文档：

- `-strip` 和 `-auto-orient`: 一定要同时使用，前者去掉图片的 Exif 信息，后者根据图片的 Exif 信息自动旋转图片，不加 `-auto-orient` 会导致图片角度错误，比如相机竖排的图可能会转个 90°
- `-enhance`: Apply a digital filter to enhance a noisy image
- `-auto-level`: Automagically adjust color levels of image

<br/>

### 查看效果

用 Chrome 模拟手机 3G 网，看图片优化是否生效。

1. 选择屏幕大小，切换到手机屏
2. 选择 「Network」，之后看加载效果
3. 在网络中选择「Disable cache」
4. 在网络中选择「Fast 3G」

{%- include img.html src="image-optimization/chrome_debug.png" alt="用 Chrome 查看效果" width="500px" -%}

#### Lighthouse

这是 Chrome 自带的本地版 [PageSpeed](https://pagespeed.web.dev)。在上图 2 「Network」 的同一栏，点击「Lighthouse」，然后点击「Analyze page load」，等待一会儿，就能看到你的网站的整体性能报告了。

以下是本文在手机「Fast 3G」下的报告，其中有各项得分和有哪些优化点：

{% include img.html src="image-optimization/report.png" alt="得分报告" width="300px" shape="narrow" %}

注意，默认是不会应用上一节配置的手机「Fast 3G」，你需要打开 「Lighthouse」的 「DevTools throttling (advanced)」配置。我这篇文章如果不打开，那么性能得分会显示红色感叹号，估计是太快了（笑）。

<br/>

## 末

- 图片加载优化是一个很大的话题，本文只是一个入门级的介绍
- CSS 太难了😭

    {% include img.html src="image-optimization/IMG_2354.JPG" alt="CSS 太难了😭" width="500px" %}
